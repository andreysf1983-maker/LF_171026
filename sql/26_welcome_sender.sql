-- Mail sender shown in the client. Not spawned.
INSERT INTO `creature_template`
  (`entry`, `name`, `subname`, `faction`, `minlevel`, `maxlevel`,
   `BaseAttackTime`, `RangeAttackTime`, `HealthScalingExpansion`,
   `npcflag`, `unit_flags`, `modelid1`, `unit_class`)
VALUES
  (9500100, 'n0social', '', 35, 1, 1, 2000, 2000, -1, 0, 512, 3167, 1)
ON DUPLICATE KEY UPDATE
  `name` = 'n0social',
  `npcflag` = 0,
  `modelid1` = 3167,
  `unit_class` = 1;  -- LEGIONFORGE 2026-10-13: was 0 -> "invalid unit_class (0)" at every start

-- Level 80 achievement mailed this letter from Rhonin (16128).
UPDATE `achievement_reward`
SET `item` = 0, `sender` = 0, `subject` = NULL, `text` = NULL, `mailTemplate` = 0
WHERE `entry` = 13;
