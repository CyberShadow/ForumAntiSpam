import Team15.Utils;
import Team15.LiteXML;

import std.stream;
import std.date;

const DAYS_THRESHOLD = 3; // consider an IP match as a positive if it was last seen at most this many days ago

CheckResult check(string, string IP, string)
{
	auto xml = new XmlDocument(new MemoryStream(download("http://www.stopforumspam.com/api?ip=" ~ IP)));
	auto response = xml["response"];
	enforce(response.attributes["success"] == "true", "StopForumSpam API error");
	if (response["appears"].text == "no")
		return CheckResult(false, "appears=false");
	auto date = parse(response["lastseen"].text);
	return CheckResult(
		date + DAYS_THRESHOLD*TicksPerDay > getUTCtime(),
		IP ~ " last seen: " ~ response["lastseen"].text ~ ", frequency: " ~ response["frequency"].text
	);
}

import SpamEngines;

static this() { engines["StopForumSpam"] = &check; }
