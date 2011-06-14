import std.stdio;

import Mollom;

void main(string[] args)
{
	auto sessionID = args[1];
	sendFeedback(sessionID, "spam");
}
