module SendDefensioHam;

import std.stdio;

import engines.Defensio;

void main(string[] args)
{
	auto signature = args[1];
	postFeedback(signature, false);
}
