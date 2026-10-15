-- Landings for scenario maps that have an area-trigger spot and no teleport spell.
-- Coordinates are the first client area trigger on that map.
-- An NPC row is added only where a spawned quest giver for that scenario exists.
-- Those NPCs cast spell 84338 (Teleport Player). The script aims it at the landing
-- and keeps the spot the player was standing on for the way back.

CREATE TABLE IF NOT EXISTS `scenario_map_landing` (
  `map_id` int unsigned NOT NULL,
  `pos_x` float NOT NULL,
  `pos_y` float NOT NULL,
  `pos_z` float NOT NULL,
  `pos_o` float NOT NULL DEFAULT 0,
  PRIMARY KEY (`map_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `scenario_npc_landing` (
  `npc_entry` int unsigned NOT NULL,
  `quest_id` int unsigned NOT NULL,
  `map_id` int unsigned NOT NULL,
  PRIMARY KEY (`npc_entry`, `quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `scenario_map_landing` (`map_id`, `pos_x`, `pos_y`, `pos_z`, `pos_o`)
SELECT * FROM (
  SELECT 999 AS map_id, -3815.44 AS pos_x, -4792.75 AS pos_y, 10.7503 AS pos_z, 0 AS pos_o
  UNION ALL SELECT 1000, -4023.08, -4748.8, 5.21768, 0
  UNION ALL SELECT 1024, 2045.92, -1980.01, 215.508, 0
  UNION ALL SELECT 1030, 767.561, 2317.53, 82.2648, 0
  UNION ALL SELECT 1031, 3795.57, 533.585, 638.757, 0
  UNION ALL SELECT 1048, -2943.34, 767.891, 4.79801, 0
  UNION ALL SELECT 1050, -1437.25, 3934.43, 6.50244, 0
  UNION ALL SELECT 1051, 1736.49, 302.559, 475.882, 0
  UNION ALL SELECT 1095, 995.075, -115.149, 452.054, 0
  UNION ALL SELECT 1099, 2347.04, -4138.3, 14.4657, 0
  UNION ALL SELECT 1103, -1158.34, -1232.5, 29.3884, 0
  UNION ALL SELECT 1104, -1452.69, 1015.83, 32.0572, 0
  UNION ALL SELECT 1112, 703.721, 574.901, 112.628, 0
  UNION ALL SELECT 1126, 6512.24, 5767.42, 28.5213, 0
  UNION ALL SELECT 1130, -5251.28, -426.663, 388.462, 0
  UNION ALL SELECT 1131, 1396.61, 802.462, 38.8667, 0
  UNION ALL SELECT 1135, -451.498, 1082.49, 133.661, 0
  UNION ALL SELECT 1144, 1126.14, 903.837, 404.101, 0
  UNION ALL SELECT 1157, -260.854, 586.809, 167.548, 0
  UNION ALL SELECT 1161, -611.005, -4994.02, -6.27734, 0
  UNION ALL SELECT 1191, 4247.82, -4192.96, 32.6476, 0
  UNION ALL SELECT 1277, 786.868, -2368.94, 99.1098, 0
  UNION ALL SELECT 1329, 1936.36, 5211.72, 183.74, 0
  UNION ALL SELECT 1374, 1483.68, 2953.02, 35.3109, 0
  UNION ALL SELECT 1528, -903.611, 645.536, 530.718, 0
  UNION ALL SELECT 1536, -12502, -13041, 227.934, 0
) AS v
WHERE NOT EXISTS (SELECT 1 FROM `scenario_map_landing` t WHERE t.map_id = v.map_id);

INSERT INTO `scenario_npc_landing` (`npc_entry`, `quest_id`, `map_id`)
SELECT * FROM (
  SELECT 63315 AS npc_entry, 31207 AS quest_id, 1031 AS map_id
  UNION ALL SELECT 67939, 32251, 1095
  UNION ALL SELECT 67940, 32248, 1104
  UNION ALL SELECT 73082, 33137, 1161
) AS v
WHERE NOT EXISTS (
  SELECT 1 FROM `scenario_npc_landing` t
  WHERE t.npc_entry = v.npc_entry AND t.quest_id = v.quest_id
);

UPDATE `creature_template`
SET `ScriptName` = 'npc_scenario_door'
WHERE `entry` IN (63315, 67939, 67940, 73082)
  AND `ScriptName` = '';

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
SELECT 84338, 'spell_scenario_npc_landing'
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM `spell_script_names`
  WHERE `spell_id` = 84338 AND `ScriptName` = 'spell_scenario_npc_landing'
);
