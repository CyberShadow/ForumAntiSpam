module DB;

import ae.sys.sqlite3;
public import ae.sys.sqlite3 : SQLiteException;

SQLite db;
SQLite.PreparedStatement newPost, newResult, findResult, setFeedback, getDates, getPosts, getResults, findPost, moderatePost;

static this()
{
	db = new SQLite("spam.sqlite3");

	db.exec("CREATE TABLE IF NOT EXISTS `posts` (`id` INTEGER, `time`, `user`, `ip`, `title`, `text`, `moderated`, `verdict`, PRIMARY KEY(`id`, `time`))");
	db.exec("CREATE TABLE IF NOT EXISTS `results` (`id` INTEGER, `engine`, `time`, `result`, `details`, `session`, `fbtime`, `fbverdict`, PRIMARY KEY(`id`, `engine`, `time`))");

	newPost      = db.prepare("INSERT INTO `posts`(`id`, `time`, `user`, `ip`, `title`, `text`, `moderated`, `verdict`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
	newResult    = db.prepare("INSERT INTO `results`(`id`, `engine`, `time`, `result`, `details`, `session`) VALUES (?, ?, ?, ?, ?, ?)");
	findResult   = db.prepare("SELECT `time`, `result`, `details`, `session`, `fbtime`, `fbverdict` FROM `results` WHERE `id` = ? AND `engine` = ? LIMIT 1");
	setFeedback  = db.prepare("UPDATE `results` SET `fbtime` = ?, `fbverdict` = ? WHERE `id` = ? AND `engine` = ? AND `time` = ?");
	getDates     = db.prepare("SELECT DISTINCT `time`/(10*1000*1000*3600*24)*(10*1000*1000*3600*24) AS `day` FROM `posts` ORDER BY `day` DESC");
	getPosts     = db.prepare("SELECT * FROM `posts` WHERE `time` BETWEEN ? AND ? ORDER BY `time` DESC");
	getResults   = db.prepare("SELECT `engine`, `time`, `result`, `details`, `fbtime`, `fbverdict` FROM `results` WHERE `id` = ?");
	findPost     = db.prepare("SELECT * FROM `posts` WHERE `id` = ? LIMIT 1");
	moderatePost = db.prepare("UPDATE `posts` SET `moderated` = 1, `verdict` = ? WHERE `id` = ? AND `time` = ?");
}
