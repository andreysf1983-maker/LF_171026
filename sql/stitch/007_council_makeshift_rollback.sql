-- Undo 007_council_makeshift.sql.

DELETE FROM `instance_encounters` WHERE `entry` IN (1395, 1407, 1436, 1695, 1748) AND `creditType` = 1;

UPDATE `creature_template` SET `ScriptName` = '' WHERE `entry` = 60051 AND `ScriptName` = 'boss_generic_guardian';
UPDATE `creature_template` SET `ScriptName` = '' WHERE `entry` IN (77557, 77231, 77477) AND `ScriptName` = 'boss_iron_maidens';
UPDATE `creature_template` SET `ScriptName` = '' WHERE `entry` IN (80816, 80805, 80808) AND `ScriptName` = 'boss_grimrail_enforcers';
