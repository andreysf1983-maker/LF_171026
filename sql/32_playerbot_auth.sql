CREATE TABLE IF NOT EXISTS `playerbot_random_names` (
  `name` varchar(12) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `playerbot_arena_names` (
  `name` varchar(12) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
