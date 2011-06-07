import std.c.time;
import std.stdio;

import Forum;
import SpamEngines;

void main()
{
	login();

	bool[string] knownIDs;
	while (true)
	{
		string[] IDs = getPostsToModerate() ~ getThreadsToModerate();
		foreach (ID; IDs)
			if (!(ID in knownIDs))
			{
				writefln("Checking post %s", ID);
				auto post = getPost(ID);
				foreach (engine, result; checkAll(post.tupleof))
					writefln("%s:\t %s", engine, result ? "SPAM" : "not spam");

				knownIDs[ID] = true;
			}

		sleep(30);
	}
}
