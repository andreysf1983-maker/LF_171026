-- Saved spot a player was standing on before a scenario door sent them in.
-- The return cast of spell 84338 reads this row.

CREATE TABLE IF NOT EXISTS `character_scenario_return` (
  `guid` bigint unsigned NOT NULL,
  `from_map` int unsigned NOT NULL,
  `from_x` float NOT NULL,
  `from_y` float NOT NULL,
  `from_z` float NOT NULL,
  `from_o` float NOT NULL,
  `dest_map` int unsigned NOT NULL,
  `gave_spell` tinyint unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
