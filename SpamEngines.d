module SpamEngines;

import Akismet, StopForumSpam, ProjectHoneyPot, Defensio;

struct CheckResult
{
	bool isSpam;
	string details;
}

CheckResult function(string, string, string)[string] engines;
