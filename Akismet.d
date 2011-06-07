module Akismet;

import std.file;
import std.string;

import Team15.Utils;
import Team15.Http.Common;

import SpamEngines;

private:

string request(Message message, string request)
{
	auto config = splitlines(cast(string)read("data/akismet.txt"));
	string key = config[0];
	string blog = config[1];

	string[string] params = [
		"blog"[] : blog,
		"comment_author" : message.author,
		"user_ip" : message.IP,
		"comment_content" : message.text
	];

	return post("http://" ~ key ~ ".rest.akismet.com/1.1/" ~ request, encodeUrlParameters(params));
}

CheckResult check(Message message)
{
	auto result = request(message, "comment-check");

	enforce(result == "true" || result == "false", result);
	return CheckResult(result == "true");
}

void sendSpam(Message message)
{
	auto result = request(message, "submit-spam");
	enforce(result == "Thanks for making the web a better place.", result);
}

void sendHam(Message message)
{
	auto result = request(message, "submit-ham");
	enforce(result == "Thanks for making the web a better place.", result);
}

static this() { engines["Akismet"] = SpamEngine(&check, &sendSpam, &sendHam); }
