module SpamEngines;

import Akismet, StopForumSpam, ProjectHoneyPot, Defensio;
public import Common;

struct CheckResult
{
	bool isSpam;
	string details;
}

struct SpamEngine
{
	CheckResult function(Message) check;
	void function(Message) sendSpam, sendHam;
}

SpamEngine[string] engines;
