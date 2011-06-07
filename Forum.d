module Forum;

import Team15.Utils;
import Team15.Http.Common;
import Team15.LiteXML;

import std.string;
import std.stream;
import std.file;

string baseUrl, username, password;

static this()
{
	auto lines = splitlines(cast(string)read("data/forum.txt"));
	baseUrl = lines[0];
	username = lines[1];
	password = lines[2];
}

struct Post
{
	string author, IP, message;
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

string[] getPostsToModerate()
{
	auto html = download(baseUrl ~ "moderation.php?do=viewposts&type=moderated");
	html = html.replace(`50"></a>`, `50"/></a>`);
	auto doc = new XmlDocument(new MemoryStream(html));
	auto posts = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr"]["td", 2]["form"].findChildren("table")[1..$-1];
	string[] ids;
	foreach (post; posts)
		ids ~= post.attributes["id"][4..$];
	return ids;
}

string[] getThreadsToModerate()
{
	auto html = download(baseUrl ~ "moderation.php?do=viewthreads&type=moderated");
	html = html.replace(`50"></a>`, `50"/></a>`);
	auto doc = new XmlDocument(new MemoryStream(html));
	auto threads = doc["html"]["body"]["div"]["div"]["div"]["table", 1]["tr"]["td", 2]["form"]["table"].findChildren("tr")[2..$];
	string[] ids;
	foreach (thread; threads)
		ids ~= thread["td", 3]["div"]["a", 1].attributes["href"].split("#")[1][4..$];
	return ids;
}

Post getPost(string id)
{
	auto html = download(baseUrl ~ "showpost.php?p=" ~ id);
	auto doc = new XmlDocument(new MemoryStream(html));
	Post post;
	post.author = doc["html"]["body"]["form"]["table", 1]["tr", 1]["td"]["div"]["a"].text;
	post.IP = doc["html"]["body"]["form"]["table", 1]["tr", 2]["td"]["a", 1]["img"].attributes["title"];
	/*
	auto postNodes = doc["html"]["body"]["form"]["table", 1]["tr", 1]["td", 1].findChildren("div");
	foreach (node; postNodes)
		if ("id" in node.attributes && node.attributes["id"].startsWith("post_message_"))
		{
			auto messageNodes = node.children;
			post.message = strip(html[cast(size_t)messageNodes[0].startPos .. cast(size_t)messageNodes[$-1].endPos]);
		}
	*/
	post.message = getPostMessage(id);
	return post;
}

string getPostMessage(string id)
{
	auto html = download(baseUrl ~ "editpost.php?do=editpost&p=" ~ id);
	enforce(!html.contains("Invalid Thread specified"), "Can't get post vbCode");
	html = html.replace(`50"></a>`, `50"/></a>`);
	auto doc = new XmlDocument(new MemoryStream(html));
	auto node = doc["html"]["body"]["div"]["div"]["div"]["form", 1]["table"]["tr", 1]["td"]["div"]["div"]["table", 1]["tr"]["td"]["table"]["tr"]["td"]["textarea"][0];
	return html[cast(size_t)node.startPos..cast(size_t)node.endPos];
}

