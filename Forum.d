module Forum;

import std.string;
import std.conv;
import std.array;
import std.stream;
import std.file;
import std.exception;
import std.datetime;

import ae.net.http.common;
import ae.sys.cmd;
import ae.utils.xml;
import ae.utils.text;

import Common;
static import DB;

string baseUrl, username, password, publicBaseUrl;

static this()
{
	auto lines = splitLines(readText("data/forum.txt"));
	baseUrl = lines[0];
	username = lines[1];
	password = lines[2];
	publicBaseUrl = lines.length>3 ? lines[3] : baseUrl;
}

bool loggedIn;

void loginCheck()
{
	if (loggedIn)
		return;
	if (exists(cookieFile)) remove(cookieFile);
	enableCookies();
	auto result = post(baseUrl ~ "login.php", encodeUrlParameters([
		"vb_login_username"[] : username,
		"vb_login_password"   : password,
		"cookieuser"          : "1",
		"do"                  : "login"
	]));
	scope(failure) write("error.html", result);
	enforce(result.contains("Thank you for logging in"), "Login failed");
	loggedIn = true;
}

string securityToken;

void saveSecurityToken(XmlNode form)
{
	foreach (input; form.findChildren("input"))
		if (input.attributes["type"]=="hidden" && input.attributes["name"]=="securitytoken")
			securityToken = input.attributes["value"];
}

alias getThreadsToModerate getSecurityToken;

string[] getPostsToModerate()
{
	loginCheck();
	auto html = fixHtml(download(baseUrl ~ "moderation.php?do=viewposts&type=moderated"));
	if (html.contains("<strong>No posts found.</strong>"))
		return null;
	auto doc = new XmlDocument(new MemoryStream(cast(char[])html));
	auto form = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr"]["td", 2]["form"];
	saveSecurityToken(form);
	auto posts = form.findChildren("table")[1..$-1];
	string[] ids;
	foreach (post; posts)
		ids ~= post.attributes["id"][4..$];
	return ids;
}

string[] getThreadsToModerate()
{
	loginCheck();
	auto html = fixHtml(download(baseUrl ~ "moderation.php?do=viewthreads&type=moderated"));
	auto doc = new XmlDocument(new MemoryStream(cast(char[])html));
	auto form = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr"]["td", 2]["form"];
	saveSecurityToken(form);
	auto threads = form["table"].findChildren("tr")[2..$];
	string[] ids;
	foreach (thread; threads)
		ids ~= thread["td", 3]["div"]["a", 1].attributes["href"].split("#")[1][4..$];
	return ids;
}

Post getPost(string id)
{
	Post post;
	DB.findPost.bindAll(id);
	if (DB.findPost.step())
	{
		DB.findPost.columns(post.dbPost.tupleof);
		DB.findPost.reset();
		post.cached = true;
		return post;
	}

	post.id = to!int(id);

	loginCheck();
	auto html = fixHtml(download(baseUrl ~ "showpost.php?p=" ~ id));
	auto doc = new XmlDocument(new MemoryStream(cast(char[])html));
	post.user = doc["html"]["body"]["form"]["table", 1]["tr", 1]["td"]["div"]["a"].text().forceValidUTF8();
	post.userid = to!int(doc["html"]["body"]["form"]["table", 1]["tr", 1]["td"]["div"]["a"].attributes["href"].split("?")[1].decodeUrlParameters()["u"]);
	auto actionButtons = doc["html"]["body"]["form"]["table", 1]["tr", 2]["td"].findChildren("a");
	post.ip = actionButtons[$-1]["img"].attributes["title"];
	enforce(post.ip.split(".").length == 4);

	html = fixHtml(download(baseUrl ~ "editpost.php?do=editpost&p=" ~ id));
	enforce(!isInvalidPost(html), "Can't get post vbCode");
	doc = new XmlDocument(new MemoryStream(cast(char[])html));
	post.title = doc["html"]["body"]["div"]["div"]["div"]["form", 1]["table"]["tr", 1]["td"]["div"]["div"]["table"]["tr", 1]["td"]["input"].attributes["value"].forceValidUTF8();
	post.text  = doc["html"]["body"]["div"]["div"]["div"]["form", 1]["table"]["tr", 1]["td"]["div"]["div"]["table", 1]["tr"]["td"]["table"]["tr"]["td"]["textarea"].text().forceValidUTF8();

	post.time = Clock.currTime().stdTime;
	post.moderated = false;
	post.cached = false;
	DB.newPost.exec(post.dbPost.tupleof);

	return post;
}

/// Present in DB and not soft-deleted
bool postExists(string id)
{
	loginCheck();
	auto html = fixHtml(download(baseUrl ~ "editpost.php?do=editpost&p=" ~ id));
	return !isInvalidPost(html);
}

void modAction(string action, string[string] modParameters)
{
	loginCheck();
	auto html = fixHtml(post(baseUrl ~ action, encodeUrlParameters(modParameters)));

	if (html.contains("Please login again to verify the legitimacy of this request"))
	{
		auto doc = new XmlDocument(new MemoryStream(cast(char[])html));
		auto form = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr", 1]["td"]["div"]["div"]["div"]["form"];
		string[string] parameters;
		foreach (input; form.findChildren("input"))
			parameters[input.attributes["name"]] = input.attributes["value"];
		parameters["vb_login_password"] = password;

		html = post(baseUrl ~ "login.php?do=login", encodeUrlParameters(parameters));
		enforce(html.contains("Thank you for logging in"), "Login failed");

		html = post(baseUrl ~ action, encodeUrlParameters(modParameters));
		enforce(!html.contains("Please login again to verify the legitimacy of this request"), "Authorization loop");
	}
	std.file.write("modaction.html", html);
}

void deletePost(string id, string reason)
{
	modAction("inlinemod.php", [
		"securitytoken"[]   : securityToken,
		"postids"           : id,
		"do"                : "dodeleteposts",
		"deletetype"        : "1",
		"deletereason"      : reason
	]);
}

void infract(Post post, int points, string adminnote)
{
	enforce(post.userid, "User ID not known for this post");
	if (securityToken=="")
		getSecurityToken();
	auto modParameters = [
		"securitytoken"[]   : securityToken,
		"infractionlevelid" : "0", // custom infraction
		"points"            : to!string(points),
		"p"                 : to!string(post.id),
		"u"                 : to!string(post.userid),
		"do"                : "update",
	//	"url"               : baseUrl ~ "showpost.php?p=" ~ to!string(post.userid),
		"sbutton"           : "Give Infraction",
		"note"              : adminnote,
	];
	foreach (line; splitLines(readText("data/infraction.txt")))
	{
		auto keyValue = split(line, "\t");
		if (keyValue.length==2)
			modParameters[keyValue[0]] = keyValue[1];
	}
	foreach (requiredParameter; ["customreason", "expires", "period", "message"])
		enforce(requiredParameter in modParameters, "Required parameter " ~ requiredParameter ~ " not specified in infraction.txt");
	modAction("infraction.php", modParameters);
}

string fixHtml(string html)
{
	return html
		.replace(`50"></a>`, `50"/></a>`)
		.replace(`<br>`, `<br/>`)
		.replace(`<hr size="1" noshade>`, `<hr/>`)
		.replace(`this.value='Show'; }" type="button">`, `this.value='Show'; }" type="button" />`)
	;
}

bool isInvalidPost(string html)
{
	return html.contains("Invalid Thread specified") || html.contains("Invalid Post specified");
}
