module engines.Akismet;

import std.file;
import std.string;
import std.exception;

import ae.net.http.common;
import ae.utils.cmd;

import SpamCommon;

private:

string request(Post post, string request)
{
	auto config = splitLines(cast(string)read("data/akismet.txt"));
	string key = config[0];
	string blog = config[1];

	string[string] params = [
		"blog"[] : blog,
		"comment_author" : post.user,
		"user_ip" : post.ip,
		"comment_content" : post.text
	];

	return .post("http://" ~ key ~ ".rest.akismet.com/1.1/" ~ request, encodeUrlParameters(params));
}

CheckResult check(Post post)
{
	auto result = request(post, "comment-check");

	enforce(result == "true" || result == "false", result);
	return CheckResult(result == "true");
}

void sendSpam(Post post, CheckResult checkResult)
{
	auto result = request(post, "submit-spam");
	enforce(result == "Thanks for making the web a better place.", result);
}

void sendHam(Post post, CheckResult checkResult)
{
	auto result = request(post, "submit-ham");
	enforce(result == "Thanks for making the web a better place.", result);
}

static this() { spamEngines ~= SpamEngine("Akismet", &check, &sendSpam, &sendHam); }
