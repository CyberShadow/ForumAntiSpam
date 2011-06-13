module AntiSpam;

import std.c.time;
import std.stdio;
import std.string;

import Team15.Logging;
import Team15.CommandLine;

import Forum;
import SpamEngines;

const TOTAL_POSITIVE_THRESHOLD = 2; // at least this many spam checkers must return a positive to delete this post

void main(string[] args)
{
	parseCommandLine(args);
	logFormatVersion = 1;
	auto log = createLogger("AntiSpam");

	login();

	bool[string] knownIDs;
	while (true)
	{
		string[] IDs = getPostsToModerate() ~ getThreadsToModerate();
		foreach (ID; IDs)
			if (!(ID in knownIDs))
			{
				log("Checking post " ~ ID);
				auto post = getPost(ID);
				log("Author: " ~ post.author);
				log("IP: " ~ post.IP);
				log("Title: " ~ post.title);
				log("Content:");
				foreach (line; splitlines(post.text))
					log("> " ~ line);

				string[] positiveEngines;
				foreach (name, engine; engines)
					with (engine.check(post))
					{
						log(format("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : ""));
						if (isSpam)
							positiveEngines ~= name;
					}

				if (positiveEngines.length >= TOTAL_POSITIVE_THRESHOLD)
				{
					log("Verdict: SPAM, deleting.");
					string reason;
					if (positiveEngines.length == engines.length)
						reason = "Definitely spam";
					else
						reason = "Spam (" ~ positiveEngines.join(", ") ~ ")";
					deletePost(ID, reason);
				}
				else
					log("Verdict: not spam.");

				log("###########################################################################################");
				knownIDs[ID] = true;
			}

		sleep(30);
	}
}
