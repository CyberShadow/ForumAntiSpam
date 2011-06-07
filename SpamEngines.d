module SpamEngines;

import Akismet, StopForumSpam;

bool function(string, string, string)[string] engines;

bool[string] checkAll(string author, string IP, string content)
{
	bool[string] result;
	foreach (name, engine; engines)
		result[name] = engine(author, IP, content);
	return result;
}
