module Defensio;

import Team15.Utils;
import Team15.Http.Common;
import Team15.LiteXML;

import std.file;
import std.string;
import std.stream;

CheckResult check(string author, string authorIP, string title, string content)
{
	auto config = splitlines(cast(string)read("data/defensio.txt"));
	string key = config[0];
	string client = config[1];

	string[string] params = [
		"client"[] : client,
		"content" : content,
		"platform" : "forum_bot",
		"type" : "forum",
		"author-ip" : authorIP,
		"author-logged-in" : "true",
		"title" : title
	];
	string url = "http://api.defensio.com/2.0/users/" ~ key ~ "/documents.xml";

	auto xml = new XmlDocument(new MemoryStream(post(url, encodeUrlParameters(params))));
	auto result = xml["defensio-result"];
	auto message = result.findChild("message");
	enforce(result["status"].text == "success", "Defensio API failure" ~ (message ? ": " ~ message.text : ""));
	return CheckResult(
		result["allow"].text == "false",
		format("spaminess: %s, classification: %s, profanity-match: %s",
			result["spaminess"].text,
			result["classification"].text,
			result["profanity-match"].text
		)
	);
}

import SpamEngines;

static this() { engines["Defensio"] = &check; }
