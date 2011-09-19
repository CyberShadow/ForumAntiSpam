module SendSpam;

import std.stdio;

import Forum;
import SpamCommon;
import engines.All;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (engine; spamEngines)
		if (engine.acceptsFeedback(true))
		{
			writef("%s... ", engine.name);
			engine.sendFeedback(post, true);
			writefln("Sent.");
		}
}
