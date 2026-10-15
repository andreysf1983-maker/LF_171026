-- Bind the makeshift council scripts, and credit each fight only through a spell
-- token. creditType 1 does not mark the creature as a dungeon boss, so killing
-- one member does not complete the encounter. The script calls the credit when
-- the last member dies.
--
-- Cobalt Guardian has the same script name as the other three guardians.
-- The other three, the Spirit Kings, and Will of the Emperor already have their
-- script names in creature_template.

UPDATE `creature_template` SET `ScriptName` = 'boss_generic_guardian' WHERE `entry` = 60051 AND (`ScriptName` IS NULL OR `ScriptName` = '');
UPDATE `creature_template` SET `ScriptName` = 'boss_iron_maidens' WHERE `entry` IN (77557, 77231, 77477) AND (`ScriptName` IS NULL OR `ScriptName` = '');
UPDATE `creature_template` SET `ScriptName` = 'boss_grimrail_enforcers' WHERE `entry` IN (80816, 80805, 80808) AND (`ScriptName` IS NULL OR `ScriptName` = '');

INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`)
SELECT * FROM (
  SELECT 1395 AS entry, 1 AS creditType, 115844 AS creditEntry, 0 AS lastEncounterDungeon, 'The Stone Guard' AS comment
  UNION ALL SELECT 1407, 1, 116969, 0, 'Will of the Emperor'
  UNION ALL SELECT 1436, 1, 117948, 0, 'The Spirit Kings'
  UNION ALL SELECT 1695, 1, 156629, 0, 'The Iron Maidens'
  UNION ALL SELECT 1748, 1, 163668, 0, 'Grimrail Enforcers'
) AS `rows`
WHERE NOT EXISTS (
  SELECT 1 FROM `instance_encounters` AS `existing` WHERE `existing`.`entry` = `rows`.`entry`
);
