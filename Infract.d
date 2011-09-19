import std.stdio;
import std.conv;
import std.exception;

import Forum;

void main(string[] args)
{
	enforce(args.length == 4, "Usage: Infract POST POINTS ADMINNOTE");
	infract(getPost(args[1]), to!int(args[2]), args[3]);
}
