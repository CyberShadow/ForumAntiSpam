module AntiSpam;

import std.stdio;
import std.string;
import std.getopt;
import core.thread;

import ae.utils.log;

import Forum;
import SpamEngines;

const TOTAL_POSITIVE_THRESHOLD = 2; // at least this many spam checkers must return a positive to delete this post

void main(string[] args)
{
	bool quiet = false;
	getopt(args, std.getopt.config.bundling,
		"q|quiet", &quiet);
	auto log = quiet ? new FileLogger("AntiSpam") : new FileAndConsoleLogger("AntiSpam");

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
				foreach (line; splitLines(post.text))
					log("> " ~ line);

				string[] positiveEngines;
				foreach (name, engine; engines)
				{
					auto result = engine.check(post);
					with (result)
					{
						log(format("%-20s: %s%s", name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : ""));
						if (isSpam)
							positiveEngines ~= name;
					}
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

		Thread.sleep(dur!"seconds"(30));
	}
}
