-- Откат sql/48_legion_allied_races.sql: вернуть требование BfA (7) для рас 27-30.
UPDATE `race_unlock_requirement` SET `expansion` = 7 WHERE `raceID` IN (27, 28, 29, 30);
