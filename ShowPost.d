module ShowPost;

import std.stdio;

import Forum;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	writefln("Author: %s\nIP: %s\nTitle: %s\nMessage: %s\nCached: %s\n", post.author, post.IP, post.title, post.text, post.cached);
}
