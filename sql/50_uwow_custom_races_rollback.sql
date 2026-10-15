-- ==========================================================================
--   LEGIONFORGE 7.3.5 - откат поддержки кастомных рас (31,32,34,35,36,37)
--   Файл: sql/50_uwow_custom_races_rollback.sql    База: world
-- ==========================================================================
SET NAMES utf8mb4;

DELETE FROM `playercreateinfo`         WHERE `race` IN (31,32,34,35,36,37);
DELETE FROM `player_levelstats`        WHERE `race` IN (31,32,34,35,36,37);
DELETE FROM `playercreateinfo_item`    WHERE `race` IN (31,32,34,35,36,37);
DELETE FROM `playercreateinfo_action`  WHERE `race` IN (31,32,34,35,36,37);
DELETE FROM `playercreateinfo_spell_custom`
 WHERE `racemask` IN (1<<30, 1<<31, 1<<33, 1<<34, 1<<35, 1<<36);
DELETE FROM `playercreateinfo_cast_spell`
 WHERE `raceMask` IN (1<<30, 1<<31, 1<<33, 1<<34, 1<<35, 1<<36);
DELETE FROM `race_unlock_requirement`  WHERE `raceID` IN (31,32,34,35,36,37);
