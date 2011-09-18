module SpamCommon;

import std.datetime;
import std.exception;

public import Common;
static import DB;

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

	/// Find a CheckResult from database log.
	private bool findResult(int id, ref CheckResult result)
	{
		DB.findResult.bindAll(id, name);
		if (DB.findResult.step())
		{
			result.cached = true;
			// `time`, `result`, `details`, `session`
			result.time    = DB.findResult.column!long(0);
			result.isSpam  = DB.findResult.column!bool(1);
			result.details = DB.findResult.column!string(2);
			result.session = DB.findResult.column!string(3);
			DB.findResult.reset();
			return true;
		}
		return false;
	}

	CheckResult check(Message m)
	{
		CheckResult result;
		if (findResult(m.id, result))
			return result;

		result = checkFunc(m);
		result.cached = false;
		result.time = Clock.currTime().stdTime;
		// `id`, `engine`, `time`, `result`, `details`, `session`
		DB.newResult.exec(m.id, name, result.time, result.isSpam, result.details, result.session);

		return result;
	}

	void sendFeedback(Message m, bool isSpam)
	{
		auto func = isSpam ? spamFunc : hamFunc;
		enforce(func, "Don't know how to send feedback of this type");
		CheckResult result;
		enforce(findResult(m.id, result), "Can't find result for this message");
		func(m, result);
	}

	bool acceptsFeedback(bool isSpam)
	{
		return (isSpam ? spamFunc : hamFunc) !is null;
	}
}

SpamEngine[] engines;
