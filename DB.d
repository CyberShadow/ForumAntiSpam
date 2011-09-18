module DB;

import ae.sys.sqlite3;

SQLite db;
SQLite.PreparedStatement newPost, newResult, findResult;

static this()
{
	db = new SQLite("spam.sqlite3");

	db.exec("CREATE TABLE IF NOT EXISTS `posts` (`id` INTEGER, `time`, `author`, `IP`, `title`, `text`, `verdict`)");
	db.exec("CREATE INDEX IF NOT EXISTS `post` ON `posts` (`id`)");
	db.exec("CREATE TABLE IF NOT EXISTS `results` (`id` INTEGER, `engine`, `time`, `result`, `details`, `session`)");
	db.exec("CREATE INDEX IF NOT EXISTS `result` ON `results` (`id`, `engine`)");

	newPost    = db.prepare("INSERT INTO `posts`(`id`, `time`, `author`, `IP`, `title`, `text`, `verdict`) VALUES (?, ?, ?, ?, ?, ?, ?)");
	newResult  = db.prepare("INSERT INTO `results`(`id`, `engine`, `time`, `result`, `details`, `session`) VALUES (?, ?, ?, ?, ?, ?)");
	findResult = db.prepare("SELECT `time`, `result`, `details`, `session` FROM `results` WHERE `id` = ? AND `engine` = ? LIMIT 1");
}
