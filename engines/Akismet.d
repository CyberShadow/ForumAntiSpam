module engines.Akismet;

import std.file;
import std.string;
import std.exception;

import ae.net.http.common;
import ae.sys.cmd;

import SpamCommon;

private:

struct Service
{
	string name, server, configFile;
}

struct Akismet(string SERVER, string CONFIGFILE)
{
	static string request(Post post, string request)
	{
		auto config = splitLines(readText("data/"~CONFIGFILE~".txt"));
		string key = config[0];
		string blog = config[1];

		string[string] params = [
			"blog"[] : blog,
			"comment_author" : post.user,
			"user_ip" : post.ip,
			"comment_content" : post.text
		];

		return .post("http://" ~ key ~ "."~SERVER~"/1.1/" ~ request, encodeUrlParameters(params));
	}

	static CheckResult check(Post post)
	{
		auto result = request(post, "comment-check");

		enforce(result == "true" || result == "false", result);
		return CheckResult(result == "true");
	}

	static void sendSpam(Post post, CheckResult checkResult)
	{
		auto result = request(post, "submit-spam");
		enforce(result == "Thanks for making the web a better place.", result);
	}

	static void sendHam(Post post, CheckResult checkResult)
	{
		auto result = request(post, "submit-ham");
		enforce(result == "Thanks for making the web a better place.", result);
	}

	static SpamEngine makeEngine(string name) { return SpamEngine(name, &check, &sendSpam, &sendHam); }
}

static this()
{
	spamEngines ~= Akismet!("rest.akismet.com", "akismet").makeEngine("Akismet");
	spamEngines ~= Akismet!("api.antispam.typepad.com", "typepadantispam").makeEngine("TypePadAntiSpam");
}
