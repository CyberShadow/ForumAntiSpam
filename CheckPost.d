module CheckPost;

import std.stdio;

import Forum;
import SpamEngines;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (name, engine; engines)
	{
		auto result = engine.check(post);
		with (result)
			writefln("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : "");
	}
}
