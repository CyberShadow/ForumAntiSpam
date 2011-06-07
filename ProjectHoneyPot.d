module ProjectHoneyPot;

import Team15.Utils;

import std.socket;
import std.file;
import std.string;

const DAYS_THRESHOLD  =  3; // consider an IP match as a positive if it was last seen at most this many days ago
const SCORE_THRESHOLD = 10; // consider an IP match as a positive if its ProjectHoneyPot score is at least this value

bool check(string, string IP, string)
{
	with (phpCheck(IP))
		return present && daysLastSeen <= DAYS_THRESHOLD && threatScore >= SCORE_THRESHOLD;
}

import SpamEngines;

static this() { engines["ProjectHoneyPot"] = &check; }

private:

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

/*
import std.stdio;
void main(string[] args)
{
	auto result = phpCheck(args[1]);
	foreach (i, t; result.tupleof)
		writefln("%s: %d", result.tupleof[i].stringof, result.tupleof[i]);
}*/