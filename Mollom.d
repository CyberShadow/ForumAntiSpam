module Mollom;

import std.file;
import std.string;
import std.base64;
import std.date;
import std.random;
import std.stream;

import Team15.Utils;
import Team15.LiteXML;
import Team15.Http.XMLRPC;

import SpamEngines;

private:

template CommonRequestParameters()
{
	string public_key, time, hash, nonce;
}

string server;
const string[] initialServers = ["http://xmlrpc1.mollom.com", "http://xmlrpc2.mollom.com", "http://xmlrpc3.mollom.com"];

struct ServerParams // must be outside function scope to avoid recursive expansion
{
	mixin CommonRequestParameters;
}

R request(R, T)(string methodName, T params)
{
	if (server is null)
	{
		server = initialServers[rand%$];

		auto serverList = request!(string[])("getServerList", ServerParams());
		server = serverList[rand%$];
	}

	auto config = splitlines(cast(string)read("data/mollom.txt"));
	string publicKey = config[0];
	string privateKey = config[1];
	auto t = getUTCtime();
	string time = format("%04d-%02d-%02dT%02d:%02d:%02d.%03d%s",
		YearFromTime(t),
		MonthFromTime(t)+1,
		DateFromTime(t),
		HourFromTime(t),
		MinFromTime(t),
		SecFromTime(t),
		msFromTime(t),
		"+0000"
	);
	string nonce = randomString();
	string hash = encode(cast(string)hmac_sha1(time ~ ':' ~ nonce ~ ':' ~ privateKey, cast(ubyte[])privateKey));

	params.public_key = publicKey;
	params.time = time;
	params.hash = hash;
	params.nonce = nonce;

	auto xml = formatXmlRpcCall("mollom." ~ methodName, params);
	auto result = post(server ~ "/1.0", xml.toString());
	xml = new XmlDocument(new MemoryStream(result));
	return parseXmlRpcResponse!(R)(xml);
}

struct CheckContentResult
{
	int spam;
	double quality;
	string session_id;

	enum : int
	{
		Ham = 1,
		Spam = 2,
		Unsure = 3
	}
}

CheckContentResult postMessage(Message message)
{
	struct CheckContentParams
	{
		string post_title, post_body, author_name, author_ip;
		mixin CommonRequestParameters;
	}

	return request!(CheckContentResult)("checkContent", CheckContentParams(message.title, message.text, message.author, message.IP));
}

public bool sendFeedback(string sessionID, string feedback)
{
	struct SendFeedbackParams
	{
		string session_id, feedback;
		mixin CommonRequestParameters;
	}

	return request!(bool)("sendFeedback", SendFeedbackParams(sessionID, feedback));
}

CheckResult check(Message message)
{
	auto result = postMessage(message);
	enforce(result.spam >= 1 && result.spam <= 3, "Invalid spam value");
	return CheckResult(result.spam == CheckContentResult.Spam,
		format("spam: %s, quality: %s, session_id: %s",
			result.spam==CheckContentResult.Ham ? "Ham" : result.spam==CheckContentResult.Spam ? "Spam" : "Unsure",
			result.quality,
			result.session_id
		)
	);
}

void sendSpam(Message message)
{
	sendFeedback(postMessage(message).session_id, "spam");
}

static this() { engines["Mollom"] = SpamEngine(&check, &sendSpam); }
