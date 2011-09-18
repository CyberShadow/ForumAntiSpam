module SpamCommon;

import std.datetime;

public import Common;
import DB;

struct CheckResult
{
	bool isSpam;
	string details;
	string session;

	bool cached;
	long time;
}

struct SpamEngine
{
	string name;
	CheckResult function(Message) checkFunc;
	void function(Message, CheckResult) spamFunc, hamFunc;

	CheckResult check(Message m)
	{
		findResult.bindAll(m.id, name);
		if (findResult.step())
		{
			CheckResult result;
			result.cached = true;
			// `time`, `result`, `details`, `session`
			result.time    = findResult.column!long(0);
			result.isSpam  = findResult.column!bool(1);
			result.details = findResult.column!string(2);
			result.session = findResult.column!string(3);
			findResult.reset();
			return result;
		}

		auto result = checkFunc(m);
		result.cached = false;
		result.time = Clock.currTime().stdTime;
		// `id`, `engine`, `time`, `result`, `details`, `session`
		newResult.exec(m.id, name, result.time, result.isSpam, result.details, result.session);

		return result;
	}
}

SpamEngine[] engines;
