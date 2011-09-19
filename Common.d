module Common;

struct Message
{
	int id;
	long time;
	string author, IP, title, text;

	bool moderated, verdict;

	bool cached;
}
