module SendHam;

import std.stdio;

import Forum;
import SpamCommon;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (name, engine; engines)
		if (engine.sendHam)
		{
			writef("%s... ", name);
			engine.sendHam(post);
			writefln("Sent.");
		}
}
