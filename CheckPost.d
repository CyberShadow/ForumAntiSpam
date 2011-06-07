import std.stdio;

import Forum;
import Akismet;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	printf("Author: %.*s\nIP: %.*s\nMessage: %.*s\n", post.tupleof); // HACK
	writefln("Post %s is %s", id, check(post.tupleof) ? "SPAM" : "not spam");
}
