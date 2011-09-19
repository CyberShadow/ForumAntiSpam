module SendHam;

import std.stdio;

import Forum;
import SpamCommon;
import engines.All;

void main(string[] args)
{
	auto id = args[1];
	auto post = getPost(id);
	foreach (engine; spamEngines)
		if (engine.acceptsFeedback(false))
		{
			writef("%s... ", engine.name);
			engine.sendFeedback(post, false);
			writefln("Sent.");
		}
}
