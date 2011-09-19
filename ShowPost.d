module ShowPost;

import std.stdio;

import Forum;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	writefln("Author: %s (%d)\nIP: %s\nTitle: %s\nMessage: %s\nCached: %s\n", post.user, post.userid, post.ip, post.title, post.text, post.cached);
}
