module Forum;

import std.string;
import std.stream;
import std.file;

import Team15.Utils;
import Team15.Http.Common;
import Team15.LiteXML;

import Common;

string baseUrl, username, password;

static this()
{
	auto lines = splitlines(cast(string)read("data/forum.txt"));
	baseUrl = lines[0];
	username = lines[1];
	password = lines[2];
}

void login()
{
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
}

string securityToken;

void saveSecurityToken(XmlNode form)
{
	foreach (input; form.findChildren("input"))
		if (input.attributes["type"]=="hidden" && input.attributes["name"]=="securitytoken")
			securityToken = input.attributes["value"];
}

alias getPostsToModerate getSecurityToken;

string[] getPostsToModerate()
{
	auto html = fixHtml(download(baseUrl ~ "moderation.php?do=viewposts&type=moderated"));
	if (html.contains("<strong>No posts found.</strong>"))
		return null;
	auto doc = new XmlDocument(new MemoryStream(html));
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
	auto html = fixHtml(download(baseUrl ~ "moderation.php?do=viewthreads&type=moderated"));
	auto doc = new XmlDocument(new MemoryStream(html));
	auto form = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr"]["td", 2]["form"];
	saveSecurityToken(form);
	auto threads = form["table"].findChildren("tr")[2..$];
	string[] ids;
	foreach (thread; threads)
		ids ~= thread["td", 3]["div"]["a", 1].attributes["href"].split("#")[1][4..$];
	return ids;
}

Message getPost(string id)
{
	Message post;

	auto html = fixHtml(download(baseUrl ~ "showpost.php?p=" ~ id));
	auto doc = new XmlDocument(new MemoryStream(html));
	post.author = doc["html"]["body"]["form"]["table", 1]["tr", 1]["td"]["div"]["a"].text;
	post.IP = doc["html"]["body"]["form"]["table", 1]["tr", 2]["td"]["a", 2]["img"].attributes["title"];
	enforce(post.IP.split(".").length == 4);

	html = fixHtml(download(baseUrl ~ "editpost.php?do=editpost&p=" ~ id));
	enforce(!html.contains("Invalid Thread specified"), "Can't get post vbCode");
	doc = new XmlDocument(new MemoryStream(html));
	post.title = doc["html"]["body"]["div"]["div"]["div"]["form", 1]["table"]["tr", 1]["td"]["div"]["div"]["table"]["tr", 1]["td"]["input"].attributes["value"];
	post.text  = doc["html"]["body"]["div"]["div"]["div"]["form", 1]["table"]["tr", 1]["td"]["div"]["div"]["table", 1]["tr"]["td"]["table"]["tr"]["td"]["textarea"].text;

	return post;
}

void deletePost(string id, string reason)
{
	auto modParameters = [
		"securitytoken"[] : securityToken,
		"postids"         : id,
		"do"              : "dodeleteposts",
		"deletetype"      : "1",
		"deletereason"    : reason
	];
	auto html = fixHtml(post(baseUrl ~ "inlinemod.php", encodeUrlParameters(modParameters)));

	if (html.contains("Please login again to verify the legitimacy of this request"))
	{
		auto doc = new XmlDocument(new MemoryStream(html));
		auto form = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr", 1]["td"]["div"]["div"]["div"]["form"];
		string[string] parameters;
		foreach (input; form.findChildren("input"))
			parameters[input.attributes["name"]] = input.attributes["value"];
		parameters["vb_login_password"] = password;

		html = post(baseUrl ~ "login.php?do=login", encodeUrlParameters(parameters));
		enforce(html.contains("Thank you for logging in"), "Login failed");

		html = post(baseUrl ~ "inlinemod.php", encodeUrlParameters(modParameters));
		enforce(!html.contains("Please login again to verify the legitimacy of this request"), "Authorization loop");
	}
}

string fixHtml(string html)
{
	return html
		.replace(`50"></a>`, `50"/></a>`)
		.replace(`<br>`, `<br/>`)
		.replace(`<hr size="1" noshade>`, `<hr/>`)
	;
}
