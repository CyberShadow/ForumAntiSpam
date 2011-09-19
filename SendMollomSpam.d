module SendMollomSpam;

import std.stdio;

import engines.Mollom;

void main(string[] args)
{
	auto sessionID = args[1];
	sendFeedback(sessionID, "spam");
}
