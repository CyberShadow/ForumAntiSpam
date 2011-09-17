module Stats;

import std.stdio;
import std.file;
import std.string;

import Forum;

void main()
{
	login();
	
	bool[string] engineResults;
	string postID;
	int[string] engineTotal, engineFalsePositive, engineFalseNegative;
	foreach (file; listdir("logs", "*.log"))
		foreach (line; splitLines(cast(string)read(file)))
			if (line.startsWith("["))
			{
				line = line[line.indexOf("] ")+2..$];
				if (line.startsWith("Checking post "))
				{
					postID = line[14..$];
					engineResults = null;
				}
				else
				if (line.length > 20 && line[20]==':')
				{
					auto engine = strip(line[0..20]);
					auto result = strip(line[21..$]);
					if (result.startsWith("not spam"))
						engineResults[engine] = false;
					else
					if (result.startsWith("SPAM"))
						engineResults[engine] = true;
				}
				else
				if (line.startsWith("Verdict: "))
				{
					bool modVerdict = !postExists(postID);
					writefln("Post %s: %s; Mod verdict=%s", postID, engineResults, modVerdict);
					foreach (engine, engineResult; engineResults)
					{
						engineTotal[engine]++;
						if (engineResult && !modVerdict)
							engineFalsePositive[engine]++;
						else
						if (!engineResult && modVerdict)
							engineFalseNegative[engine]++;
					}
				}
			}

	foreach (engine, total; engineTotal)
	{
		int falsePositives = engine in engineFalsePositive ? engineFalsePositive[engine] : 0;
		int falseNegatives = engine in engineFalseNegative ? engineFalseNegative[engine] : 0;
		writefln("%-20s: %3d total, %3d false positives, %3d false negatives", engine, total, falsePositives, falseNegatives);
	}
}
