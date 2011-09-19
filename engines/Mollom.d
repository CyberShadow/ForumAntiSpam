module engines.Mollom;

import std.file;
import std.string;
import std.base64;
import std.datetime;
import std.random;
import std.stream;

import ae.utils.xml;
import ae.utils.xmlrpc;
import ae.utils.time;
import ae.utils.text;
import ae.utils.digest;
import ae.utils.cmd;

import SpamCommon;

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
		server = initialServers[uniform(0, $)];

		auto serverList = request!(string[])("getServerList", ServerParams());
		server = serverList[uniform(0, $)];
	}

	auto config = splitLines(cast(string)read("data/mollom.txt"));
	string publicKey = config[0];
	string privateKey = config[1];
	string time = formatTime(`Y-m-d\TH:i:s.EO`, Clock.currTime(UTC()));
	string nonce = randomString();
	string hash = Base64.encode(hmac_sha1(time ~ ':' ~ nonce ~ ':' ~ privateKey, cast(ubyte[])privateKey)).idup;

	params.public_key = publicKey;
	params.time = time;
	params.hash = hash;
	params.nonce = nonce;

	auto request = formatXmlRpcCall("mollom." ~ methodName, params);
	scope(failure) std.file.write("mollom-request.xml", request.toString());
	auto result = post(server ~ "/1.0", request.toString());
	auto response = new XmlDocument(new MemoryStream(cast(char[])result));
	return parseXmlRpcResponse!(R)(response);
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

CheckContentResult postMessage(Post post)
{
	struct CheckContentParams
	{
		string post_title, post_body, author_name, author_ip;
		mixin CommonRequestParameters;
	}

	return request!(CheckContentResult)("checkContent", CheckContentParams(post.title, post.text, post.user, post.ip));
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

CheckResult check(Post post)
{
	auto result = postMessage(post);
	enforce(result.spam >= 1 && result.spam <= 3, "Invalid spam value");
	return CheckResult(result.spam == CheckContentResult.Spam,
		format("spam: %s, quality: %s, session_id: %s",
			result.spam==CheckContentResult.Ham ? "Ham" : result.spam==CheckContentResult.Spam ? "Spam" : "Unsure",
			result.quality,
			result.session_id
		),
		result.session_id
	);
}

void sendSpam(Post post, CheckResult checkResult)
{
	sendFeedback(checkResult.session, "spam");
}

static this() { spamEngines ~= SpamEngine("Mollom", &check, &sendSpam); }
