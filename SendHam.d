module SendHam;

import std.stdio;

import Forum;
import SpamCommon;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (engine; engines)
		if (engine.acceptsFeedback(false))
		{
			writef("%s... ", engine.name);
			engine.sendFeedback(post, false);
			writefln("Sent.");
		}
}
