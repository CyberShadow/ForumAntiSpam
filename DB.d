module DB;

import ae.sys.sqlite3;
public import ae.sys.sqlite3 : SQLiteException;

SQLite db;
SQLite.PreparedStatement newPost, newResult, findResult, setFeedback;

static this()
{
	db = new SQLite("spam.sqlite3");

	db.exec("CREATE TABLE IF NOT EXISTS `posts` (`id` INTEGER, `time`, `author`, `IP`, `title`, `text`, `verdict`, PRIMARY KEY(`id`, `time`))");
	db.exec("CREATE TABLE IF NOT EXISTS `results` (`id` INTEGER, `engine`, `time`, `result`, `details`, `session`, `fbtime`, `fbverdict`, PRIMARY KEY(`id`, `engine`, `time`))");

	newPost      = db.prepare("INSERT INTO `posts`(`id`, `time`, `author`, `IP`, `title`, `text`, `verdict`) VALUES (?, ?, ?, ?, ?, ?, ?)");
	newResult    = db.prepare("INSERT INTO `results`(`id`, `engine`, `time`, `result`, `details`, `session`) VALUES (?, ?, ?, ?, ?, ?)");
	findResult   = db.prepare("SELECT `time`, `result`, `details`, `session`, `fbtime`, `fbverdict` FROM `results` WHERE `id` = ? AND `engine` = ? LIMIT 1");
	setFeedback  = db.prepare("UPDATE `results` SET `fbtime` = ?, `fbverdict` = ? WHERE `id` = ? AND `engine` = ? AND `time` = ?");
}
