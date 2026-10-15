CREATE TABLE IF NOT EXISTS `aiwaypoints` (
  `entry` int unsigned NOT NULL AUTO_INCREMENT,
  `map` int unsigned NOT NULL DEFAULT 0,
  `position_x` float NOT NULL DEFAULT 0,
  `position_y` float NOT NULL DEFAULT 0,
  `position_z` float NOT NULL DEFAULT 0,
  `link` text,
  `comment` text,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
