module CheckPost;

import std.stdio;

import Forum;
import SpamCommon;
import engines.All;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (engine; spamEngines)
	{
		auto result = engine.check(post);
		with (result)
			writefln("%-20s: %s%s%s", engine.name, result.cached ? "[cached] " : "", isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : "");
	}
}
