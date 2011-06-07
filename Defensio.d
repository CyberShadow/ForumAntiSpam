module Defensio;

import std.file;
import std.string;
import std.stream;

import Team15.Utils;
import Team15.Http.Common;
import Team15.LiteXML;

import SpamEngines;

private:

CheckResult check(Message message)
{
	auto xml = postDocument(message);
	auto result = xml["defensio-result"];
	auto messageNode = result.findChild("message");
	enforce(result["status"].text == "success", "Defensio API failure" ~ (messageNode ? ": " ~ messageNode.text : ""));
	return CheckResult(
		result["allow"].text == "false",
		format("spaminess: %s, classification: %s, profanity-match: %s",
			result["spaminess"].text,
			result["classification"].text,
			result["profanity-match"].text
		)
	);
}

XmlDocument postDocument(Message message)
{
	auto config = splitlines(cast(string)read("data/defensio.txt"));
	string key = config[0];
	string client = config[1];

	string[string] params = [
		"client"[] : client,
		"content" : message.text,
		"platform" : "forum_bot",
		"type" : "forum",
		"author-ip" : message.IP,
		"author-logged-in" : "true",
		"title" : message.title
	];
	string url = "http://api.defensio.com/2.0/users/" ~ key ~ "/documents.xml";

	return new XmlDocument(new MemoryStream(post(url, encodeUrlParameters(params))));
}

static this() { engines["Defensio"] = SpamEngine(&check); }
