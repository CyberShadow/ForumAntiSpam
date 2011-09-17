module SendSpam;

import std.stdio;

import Forum;
import SpamEngines;
import EnabledSpamEngines;

void main(string[] args)
{
	login();
	auto id = args[1];
	auto post = getPost(id);
	foreach (name, engine; engines)
		if (engine.sendSpam)
		{
			writef("%s... ", name);
			engine.sendSpam(post);
			writefln("Sent.");
		}
}
