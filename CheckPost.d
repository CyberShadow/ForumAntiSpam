import std.stdio;

import Forum;
import SpamEngines;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	printf("Author: %.*s\nIP: %.*s\nMessage: %.*s\n", post.tupleof); // Utf-8 hack
	foreach (name, checker; engines)
		with (checker(post.tupleof))
			writefln("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : "");
}
