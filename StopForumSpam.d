module StopForumSpam;

import std.stream;
import std.date;
import std.file;

import Team15.Utils;
import Team15.LiteXML;
import Team15.Http.Common;

import SpamEngines;

private:

const DAYS_THRESHOLD = 3; // consider an IP match as a positive if it was last seen at most this many days ago

CheckResult check(Message message)
{
	auto xml = new XmlDocument(new MemoryStream(download("http://www.stopforumspam.com/api?ip=" ~ message.IP)));
	auto response = xml["response"];
	enforce(response.attributes["success"] == "true", "StopForumSpam API error");
	if (response["appears"].text == "no")
		return CheckResult(false, "appears=false");
	auto date = parse(response["lastseen"].text);
	return CheckResult(
		date + DAYS_THRESHOLD*TicksPerDay > getUTCtime(),
		message.IP ~ " last seen: " ~ response["lastseen"].text ~ ", frequency: " ~ response["frequency"].text
	);
}

void sendSpam(Message message)
{
	auto key = cast(string)read("data/stopforumspam.txt");

	auto result = download("http://www.stopforumspam.com/add.php?" ~ encodeUrlParameters([
		"username"[] : message.author,
		"ip_addr"    : message.IP,
		"api_key"    : key
	]));

	enforce(result == "", result);
}

static this() { engines["StopForumSpam"] = SpamEngine(&check/*, &sendSpam*/); }
