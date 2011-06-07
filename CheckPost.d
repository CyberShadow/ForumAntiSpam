import std.stdio;

import Forum;
import SpamEngines;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	printf("Author: %.*s\nIP: %.*s\nMessage: %.*s\n", post.tupleof); // Utf-8 hack
	foreach (engine, result; checkAll(post.tupleof))
		writefln("%-30s: %s", engine, result ? "SPAM" : "not spam");
}
