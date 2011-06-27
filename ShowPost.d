module ShowPost;

import std.stdio;

import Forum;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	printf("Author: %.*s\nIP: %.*s\nTitle: %.*s\nMessage: %.*s\n", post.tupleof); // Utf-8 hack
}
