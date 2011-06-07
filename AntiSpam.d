import std.c.time;
import std.stdio;

import Forum;
import Akismet;

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
				auto result = check(post.tupleof);
				writefln("Post %s is %s", ID, result ? "SPAM" : "not spam");

				knownIDs[ID] = true;
			}

		sleep(30);
	}
}
