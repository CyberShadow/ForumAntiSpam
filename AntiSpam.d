module AntiSpam;

import std.stdio;
import std.string;
import std.getopt;

import ae.utils.log;
import ae.sys.timing;
import ae.net.asockets;
import ae.net.http.server;

import Forum;
import SpamCommon;
import SpamEngines;

Logger log;

class AntiSpamFrontend
{
	enum HTTP_PORT = 58904;

	HttpServer http;

	this()
	{
		http = new HttpServer();
		http.handleRequest = &onRequest;
		http.listen(HTTP_PORT, "localhost");
	}

	HttpResponse onRequest(HttpRequest request, ClientSocket conn)
	{
		return null;
	}
}

const TOTAL_POSITIVE_THRESHOLD = 2; // at least this many spam checkers must return a positive to delete this post

void main(string[] args)
{
	bool quiet = false;
	getopt(args, std.getopt.config.bundling,
		"q|quiet", &quiet);
	log = quiet ? new FileLogger("AntiSpam") : new FileAndConsoleLogger("AntiSpam");

	login();

	bool[string] knownIDs;

	setInterval({
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
				foreach (engine; engines)
				{
					auto result = engine.check(post);
					with (result)
					{
						log(format("%-20s: %s%s", engine.name, isSpam ? "SPAM" : "not spam", details ? " (" ~ details ~ ")" : ""));
						if (isSpam)
							positiveEngines ~= engine.name;
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
	}, TickDuration.from!"seconds"(30));

	new AntiSpamFrontend();
	socketManager.loop();
}
