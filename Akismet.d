module Akismet;

import Team15.Utils;
import Team15.Http.Common;

import std.file;
import std.string;

CheckResult check(string commentAuthor, string userIP, string commentTitle, string commentContent)
{
	auto config = splitlines(cast(string)read("data/akismet.txt"));
	string key = config[0];
	string blog = config[1];

	string[string] params = [
		"blog"[] : blog,
		"comment_author" : commentAuthor,
		"user_ip" : userIP,
		"comment_content" : commentContent
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

import SpamEngines;

static this() { engines["Akismet"] = &check; }
