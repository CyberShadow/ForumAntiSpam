module Akismet;

import std.file;
import std.string;

import Team15.Utils;
import Team15.Http.Common;

import SpamEngines;

private:

CheckResult check(Message message)
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

	auto result = post("http://" ~ key ~ ".rest.akismet.com/1.1/comment-check", encodeUrlParameters(params));

	if (result == "true")
		return CheckResult(true);
	else
	if (result == "false")
		return CheckResult(false);
	else
		throw new Exception(result);
}

static this() { engines["Akismet"] = SpamEngine(&check); }
