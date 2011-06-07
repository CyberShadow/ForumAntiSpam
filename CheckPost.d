import std.stdio;

import Forum;
import SpamEngines;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	printf("Author: %.*s\nIP: %.*s\nTitle: %.*s\nMessage: %.*s\n", post.tupleof); // Utf-8 hack
	foreach (name, engine; engines)
		with (engine.check(post))
			writefln("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : "");
}
