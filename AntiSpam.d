module AntiSpam;

import std.stdio;
import std.string;
import std.getopt;
import std.datetime : SysTime, Date, dur;
import std.exception;

import ae.utils.log;
import ae.utils.text;
import ae.sys.timing;
import ae.net.asockets;
import ae.net.http.server;
import ae.net.http.responseex;

import Forum;
import SpamCommon;
import SpamEngines;
static import DB;

bool quiet;

class AntiSpamFrontend
{
	enum HTTP_PORT = 58904;

	HttpServer http;
	Logger log;

	this()
	{
		http = new HttpServer();
		http.handleRequest = &onRequest;
		http.listen(HTTP_PORT, "localhost");
		log = quiet ? new FileLogger("HTTP") : new FileAndConsoleLogger("HTTP");
	}

	HttpResponse onRequest(HttpRequest request, ClientSocket conn)
	{
		auto resp = new HttpResponseEx();
		try
		{
			auto resource = request.resource;
			//log(request.resource);
			string[string] args;
			{
				int pos;
				if ((pos=resource.indexOf('?'))>=0)
				{
					args = decodeUrlParameters(resource[pos+1..$]);
					resource = resource[0..pos];
				}
			}

			if (resource == "/data/info")
			{
				struct JSONInfo
				{
					string baseUrl;
				}
				JSONInfo info;
				info.baseUrl = baseUrl;
				return resp.serveJson(info);
			}
			else
			if (resource == "/data/dates")
			{
				string[] dates;
				while (DB.getDates.step())
					dates ~= (cast(Date)SysTime(DB.getDates.column!long(0))).toSimpleString();
				return resp.serveJson(dates);
			}
			else
			if (resource == "/data/posts")
			{
				struct JSONPost
				{
					int id;
					string time, author, IP, title, text;
					bool verdict;
				}

				auto date = Date.fromSimpleString(args["date"]);
				DB.getPosts.bindAll(SysTime(date).stdTime, SysTime(date + dur!"days"(1)).stdTime);
				JSONPost[] posts;
				while (DB.getPosts.step())
				{
					struct DBPost
					{
						int id;
						long time;
						string author, IP, title, text;
						bool verdict;
					}
					DBPost dbPost;
					DB.getPosts.columns(dbPost.tupleof);
					with (dbPost)
						posts ~= JSONPost(id, SysTime(time).toString(), forceValidUTF8(author), IP, forceValidUTF8(title), forceValidUTF8(text), verdict);
				}
				return resp.serveJson(posts);
			}
			else
			if (resource == "/data/results")
			{
				struct JSONResult
				{
					// `engine`, `time`, `result`, `details`, `fbtime`, `fbverdict`
					string name, time;
					bool result;
					string details;

					bool feedbackSent;
					string feedbackTime;
					bool feedbackVerdict;

					bool canSendSpam, canSendHam;
				}

				auto id = to!int(args["id"]);
				DB.getResults.bindAll(id);
				JSONResult[] results;
				while (DB.getResults.step())
				{
					struct DBResult
					{
						// `engine`, `time`, `result`, `details`, `fbtime`, `fbverdict`
						string engineName;
						long time;
						bool result;
						string details;
						long fbtime;
						bool fbverdict;
					}
					DBResult dbResult;
					DB.getResults.columns(dbResult.tupleof);
					auto engine = findEngine(dbResult.engineName);
					with (dbResult)
						results ~= JSONResult(
							engineName, SysTime(time).toString(), result, details,
							fbtime != 0, SysTime(fbtime).toString(), fbverdict,
							engine ? engine.acceptsFeedback(true ) : false,
							engine ? engine.acceptsFeedback(false) : false,
						);
				}
				return resp.serveJson(results);
			}
			else
			if (resource == "/data/feedback")
			{
				auto engine = findEngine(args["name"]);
				enforce(engine, "Unknown engine");
				auto id = args["id"];
				auto isSpam = to!bool(args["spam"]);

				auto post = getPost(id);
				engine.sendFeedback(post, isSpam);
				return resp.serveJson("OK");
			}
			else
				return resp.serveFile(resource[1..$], "web/");
		}
		catch (Exception e)
		{
			log("Error: " ~ e.msg);
			if (request.resource().startsWith("/data/"))
			{
				struct ErrorReply { string error; }
				return resp.serveJson(ErrorReply(e.msg));
			}
			else
				return resp.writeError(HttpStatusCode.InternalServerError, e.msg);
			//log(o.toString);
		}
	}
}

const TOTAL_POSITIVE_THRESHOLD = 2; // at least this many spam checkers must return a positive to delete this post

void main(string[] args)
{
	quiet = false;
	getopt(args, std.getopt.config.bundling,
		"q|quiet", &quiet);
	auto log = quiet ? new FileLogger("AntiSpam") : new FileAndConsoleLogger("AntiSpam");

	login();

	bool[string] knownIDs;

	/+setInterval({
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
	}, TickDuration.from!"seconds"(30));+/

	new AntiSpamFrontend();
	socketManager.loop();
}
