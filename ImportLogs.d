import std.file;
import std.string;
import std.algorithm : filter;
import std.ascii;
import std.stdio;

import ae.utils.time;

import DB;

void main()
{
	int postID;
	string user, ip, title;
	string[] textLines;
	bool inText;

	int totalPosts, totalResults;

	db.exec("BEGIN TRANSACTION");

	foreach (de; filter!`endsWith(a.name,".log")`(dirEntries("oldlogs",SpanMode.shallow)))
		foreach (line; split(cast(string)read(de.name), newline.dup))
			if (line.startsWith("[") && line.hasAt(4, ' ') && line.hasAt(8, ' ') && line.hasAt(11, ' '))
			{
				auto oline = line; 	scope(failure) writeln("Error parsing line: ", oline);

				auto p = line.indexOf("] ");
				auto timeStr = line[1..p];
				long time;
				if (timeStr.length == 33)
					time = parseTime(TimeFormats.STD_DATE, timeStr).stdTime;
				else
					time = parseTime(`D M d H:i:s.E Y`, timeStr).stdTime;
				line = line[p+2..$];
				if (line.startsWith("Checking post "))
					postID = to!int(line[14..$]);
				else
				if (line.startsWith("Author: "))
					user = line[8..$];
				else
				if (line.startsWith("IP: "))
					ip = line[4..$];
				else
				if (line.startsWith("Title: "))
					title = line[7..$];
				else
				if (line == "Content:")
				{
					textLines = null;
					inText = true;
				}
				else
				if (line.startsWith("> ") && inText)
					textLines ~= line[2..$];
				else
				if (line.hasAt(20, ':'))
				{
					inText = false;
					auto engine = strip(line[0..20]);
					line = strip(line[21..$]);
					p = line.indexOf(" (");
					string resultStr, details;
					if (p>=0)
						resultStr = line[0..p],
						details = line[p+2..$-1];
					else
						resultStr = line,
						details = null;

					string[string] detailValues;
					foreach (detail; details.split(", "))
						if (p=detail.indexOf(": "), p>=0)
							detailValues[detail[0..p]] = detail[p+2..$];

					string session = null;
					if ("signature" in detailValues)
						session = detailValues["signature"];
					else
					if ("session_id" in detailValues)
						session = detailValues["session_id"];

					assert(resultStr == "SPAM" || resultStr == "not spam");
					bool result = resultStr == "SPAM";
					newResult.exec(postID, engine, time, result, details, session);
					totalResults++;
				}
				else
				if (line.startsWith("Verdict: "))
				{
					auto verdictStr = line[9..$];
					assert(verdictStr == "SPAM, deleting." || verdictStr == "not spam.");
					bool verdict = verdictStr == "SPAM, deleting.";
					string text = textLines.join("\n");
					newPost.exec(postID, time, user, /*userid*/0, ip, title, text, /*moderated*/true, verdict);
					totalPosts++;
				}
			}
			else
			if (inText)
				textLines ~= line;

	writefln("Committing...");

	db.exec("COMMIT");

	writefln("Imported %d posts and %d results", totalPosts, totalResults);
}

bool hasAt(string s, int idx, char c)
{
	return s.length > idx && s[idx] == c;
}
