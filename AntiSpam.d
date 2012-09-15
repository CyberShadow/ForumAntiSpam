module AntiSpam;

import std.stdio;
import std.file;
import std.string;
import std.getopt;
import std.datetime : SysTime, Date, UTC, dur;
import std.exception;
import std.array : array;
import std.algorithm : map;

import ae.net.asockets;
import ae.net.http.server;
import ae.net.http.responseex;
import ae.sys.log;
import ae.sys.timing;
import ae.utils.array;
import ae.utils.text;

import Forum;
import SpamCommon;
import engines.All;
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

	void onRequest(HttpRequest request, HttpServerConnection conn)
	{
		auto resp = new HttpResponseEx();
		try
		{
			auto resource = request.resource;
			//log(request.resource);
			string[string] args;
			{
				sizediff_t pos;
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
				info.baseUrl = publicBaseUrl;
				resp.serveJson(info);
			}
			else
			if (resource == "/data/dates")
			{
				string[] dates;
				while (DB.getDates.step())
					dates ~= (cast(Date)SysTime(DB.getDates.column!long(0), UTC())).toSimpleString();
				resp.serveJson(dates);
			}
			else
			if (resource == "/data/posts")
			{
				struct JSONPost
				{
					int id;
					string time, user;
					int userid;
					string ip, title, text;
					bool moderated, verdict;
				}

				auto date = Date.fromSimpleString(args["date"]);
				DB.getPosts.bindAll(SysTime(date, UTC()).stdTime, SysTime(date + dur!"days"(1), UTC()).stdTime);
				JSONPost[] posts;
				while (DB.getPosts.step())
				{
					Post post;
					DB.getPosts.columns(post.dbPost.tupleof);
					with (post.dbPost)
						posts ~= JSONPost(id, SysTime(time, UTC()).toString(), forceValidUTF8(user), userid, ip, forceValidUTF8(title), forceValidUTF8(text), moderated, verdict);
				}
				resp.serveJson(posts);
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
							engineName, SysTime(time, UTC()).toString(), result, details,
							fbtime != 0, SysTime(fbtime, UTC()).toString(), fbverdict,
							engine ? engine.acceptsFeedback(true ) : false,
							engine ? engine.acceptsFeedback(false) : false,
						);
				}
				resp.serveJson(results);
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
				resp.serveJson("OK");
			}
			else
			if (resource == "/data/sql")
			{
				struct SQLResult
				{
					string[] columns;
					string[][] rows;
					bool tooMany;
				}
				SQLResult result;
				foreach (cells, columns; DB.db.query(args["sql"]))
				{
					if (!result.columns)
						result.columns = array(map!`a.idup`(columns));
					result.rows ~= array(map!`a.idup`(cells));
					if (result.rows.length > 1000)
					{
						result.tooMany = true;
						break;
					}
				}
				resp.serveJson(result);
			}
			else
				resp.serveFile(resource[1..$], "web/");
		}
		catch (Exception e)
		{
			log("Error: " ~ e.msg);
			if (request.resource().startsWith("/data/"))
			{
				struct ErrorReply { string error; }
				resp.serveJson(ErrorReply(e.msg));
			}
			else
				resp.writeError(HttpStatusCode.InternalServerError, e.msg);
			//log(o.toString);
		}
		conn.sendResponse(resp);
	}
}

const TOTAL_POSITIVE_THRESHOLD = 2; // at least this many spam checkers must return a positive to delete this post
const MAX_INFRACTION_POINTS = 20; // infracted points are proportional to certainty

void main(string[] args)
{
	quiet = false;
	getopt(args, std.getopt.config.bundling,
		"q|quiet", &quiet);
	auto log = quiet ? new FileLogger("AntiSpam") : new FileAndConsoleLogger("AntiSpam");

	string[] enabledEngines = splitLines(readText("data/engines.txt"));
	bool[string] knownPosts;

	void run()
	{
		string[] posts = getPostsToModerate() ~ getThreadsToModerate();
		foreach (id; posts)
			if (!(id in knownPosts))
			{
				log("Checking post " ~ id);
				auto post = getPost(id);
				log("Author: " ~ post.user);
				log("IP: " ~ post.ip);
				log("Title: " ~ post.title);
				log("Content:");
				foreach (line; splitLines(forceValidUTF8(post.text)))
					log("> " ~ line);

				string[] positiveEngines;
				int totalEngines = 0;
				foreach (engine; spamEngines)
					if (enabledEngines.contains(engine.name))
					{
						totalEngines++;
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
					if (positiveEngines.length == totalEngines)
						reason = "Definitely spam";
					else
						reason = "Spam (" ~ positiveEngines.join(", ") ~ ")";
					deletePost(id, reason);
					DB.moderatePost.exec(true, post.id, post.time);
					infract(post, MAX_INFRACTION_POINTS*cast(int)positiveEngines.length/totalEngines, reason);
				}
				else
				if (totalEngines>0)
				{
					log("Verdict: not spam.");
					DB.moderatePost.exec(false, post.id, post.time);
				}
				else
					log("Verdict: no engines configured.");

				log("###########################################################################################");
				knownPosts[id] = true;
			}
	}

	run();
	setInterval(&run, TickDuration.from!"seconds"(30));// +/

	new AntiSpamFrontend();
	socketManager.loop();
}
