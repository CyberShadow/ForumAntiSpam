module Common;

struct DBPost
{
	int id;
	long time;
	string user, ip, title, text;

	bool moderated, verdict;
}

struct Post
{
	DBPost dbPost;
	alias dbPost this;

	bool cached;
}
