module engines.StopForumSpam;

import std.stream;
import std.datetime;
import std.file;
import std.exception;

import ae.net.http.common;
import ae.utils.xml;
import ae.utils.cmd;
import ae.utils.time;

import SpamCommon;

private:

const DAYS_THRESHOLD = 3; // consider an IP match as a positive if it was last seen at most this many days ago

CheckResult check(Post post)
{
	auto xml = new XmlDocument(new MemoryStream(cast(char[])download("http://www.stopforumspam.com/api?ip=" ~ post.ip)));
	auto response = xml["response"];
	enforce(response.attributes["success"] == "true", "StopForumSpam API error");
	if (response["appears"].text == "no")
		return CheckResult(false, "appears=false");
	auto date = parseTime("Y-m-d H:i:s", response["lastseen"].text);
	return CheckResult(
		date + dur!"days"(DAYS_THRESHOLD) > Clock.currTime(),
		post.ip ~ " last seen: " ~ response["lastseen"].text ~ ", frequency: " ~ response["frequency"].text
	);
}

void sendSpam(Post post, CheckResult checkResult)
{
	auto key = readText("data/stopforumspam.txt");

	auto result = download("http://www.stopforumspam.com/add.php?" ~ encodeUrlParameters([
		"username"[] : post.user,
		"ip_addr"    : post.ip,
		"email"      : null,
		"api_key"    : key
	]));

	enforce(result == "", result);
}

static this() { spamEngines ~= SpamEngine("StopForumSpam", &check, &sendSpam); }
