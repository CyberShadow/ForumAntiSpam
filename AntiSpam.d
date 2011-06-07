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
				foreach (name, checker; engines)
					with (checker(post.tupleof))
						writefln("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : "");

				knownIDs[ID] = true;
			}

		sleep(30);
	}
}
