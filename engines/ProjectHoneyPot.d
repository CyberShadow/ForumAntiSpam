module engines.ProjectHoneyPot;

import std.socket;
import std.file;
import std.string;

import SpamCommon;

private:

const DAYS_THRESHOLD  =  3; // consider an IP match as a positive if it was last seen at most this many days ago
const SCORE_THRESHOLD = 10; // consider an IP match as a positive if its ProjectHoneyPot score is at least this value

CheckResult check(Post post)
{
	auto result = phpCheck(post.ip);
	with (result)
		return CheckResult(present && daysLastSeen <= DAYS_THRESHOLD && threatScore >= SCORE_THRESHOLD,
			present ? format(
				post.ip ~ " last seen: %d days ago, threat score: %d/255, type: %s",
				daysLastSeen,
				threatScore,
				(
					( type == 0      ? ["Search Engine"  ] : []) ~
					((type & 0b0001) ? ["Suspicious"     ] : []) ~
					((type & 0b0010) ? ["Harvester"      ] : []) ~
					((type & 0b0100) ? ["Comment Spammer"] : [])
				).join(", ")
			) : post.ip ~ " not present in database / lookup error"
		);
}

struct PHPResult
{
	bool present;
	ubyte daysLastSeen, threatScore, type;
}

PHPResult phpCheck(string ip)
{
	auto key = cast(string)read("data/projecthoneypot.txt");

	string[] sections = split(ip, ".");
	assert(sections.length == 4);
	sections.reverse;
	string addr = ([key] ~ sections ~ ["dnsbl.httpbl.org"]).join(".");
	InternetHost ih = new InternetHost;
	if (!ih.getHostByName(addr))
		return PHPResult(false);
	auto resultIP = cast(ubyte[])(&ih.addrList[0])[0..1];
	resultIP.reverse;
	enforce(resultIP[0] == 127, "PHP API error");
	return PHPResult(true, resultIP[1], resultIP[2], resultIP[3]);
}

static this() { spamEngines ~= SpamEngine("ProjectHoneyPot", &check); }

/+
import std.stdio;
void main(string[] args)
{
	/+auto result = phpCheck(args[1]);
	foreach (i, t; result.tupleof)
		writefln("%s: %d", result.tupleof[i].stringof, result.tupleof[i]);+/
	writefln("%s", check(null, args[1], null, null).details);
}+/