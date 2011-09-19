module engines.Defensio;

import std.file;
import std.string;
import std.stream;
import std.exception;

import ae.net.http.common;
import ae.utils.xml;
import ae.utils.cmd;

import SpamCommon;

private:

CheckResult check(Message message)
{
	auto result = postDocument(message);
	return CheckResult(
		result["allow"].text == "false" && result["spaminess"].text == "0.99",
		format("allow: %s, spaminess: %s, classification: %s, profanity-match: %s, signature: %s",
			result["allow"].text,
			result["spaminess"].text,
			result["classification"].text,
			result["profanity-match"].text,
			result["signature"].text
		)
	);
}

XmlNode postDocument(Message message)
{
	auto config = splitLines(cast(string)read("data/defensio.txt"));
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

	auto xml = new XmlDocument(new MemoryStream(cast(char[])post(url, encodeUrlParameters(params))));
	auto result = xml["defensio-result"];
	auto messageNode = result.findChild("message");
	enforce(result["status"].text == "success", "Defensio API failure" ~ (messageNode ? ": " ~ messageNode.text : ""));

	return result;
}

public void postFeedback(string signature, bool isSpam)
{
	auto config = splitLines(cast(string)read("data/defensio.txt"));
	string key = config[0];

	string[string] params = [
		"allow"[] : isSpam ? "false" : "true"
	];
	string url = "http://api.defensio.com/2.0/users/" ~ key ~ "/documents/" ~ signature ~ ".xml";

	auto xml = new XmlDocument(new MemoryStream(cast(char[])put(url, encodeUrlParameters(params))));
	scope(failure) write("defensio-feedback-result.xml", xml.toString());
	auto result = xml["defensio-result"];
	auto messageNode = result.findChild("message");
	enforce(result["status"].text == "success", "Defensio API failure" ~ (messageNode ? ": " ~ messageNode.text : ""));
}

void sendSpam(Message message, CheckResult checkResult) { postFeedback(checkResult.session, true ); }
void sendHam (Message message, CheckResult checkResult) { postFeedback(checkResult.session, false); }

static this() { engines ~= SpamEngine("Defensio", &check, &sendSpam, &sendHam); }
