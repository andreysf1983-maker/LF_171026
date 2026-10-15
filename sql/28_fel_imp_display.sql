-- Display 20570 is the large imp mesh (same body as the warlock imp, scale 1.25).
-- Markers, credits, and vehicles list it beside a real model. They are not
-- flagged as triggers, so the server can choose 20570 and the imp is visible.
-- Summon Fel Imp (112866) summons creature 58959. That is the only creature
-- that should wear this display.

UPDATE `creature_template`
SET `modelid1` = CASE
        WHEN `modelid1` <> 20570 THEN `modelid1`
        WHEN `entry` = 58959 THEN 20570
        WHEN `modelid2` <> 0 OR `modelid3` <> 0 OR `modelid4` <> 0 THEN 0
        WHEN `name` LIKE '%Imp%' THEN 4449
        ELSE 11686
    END,
    `modelid2` = IF(`modelid2` = 20570, 0, `modelid2`),
    `modelid3` = IF(`modelid3` = 20570, 0, `modelid3`),
    `modelid4` = IF(`modelid4` = 20570, 0, `modelid4`)
WHERE `modelid1` = 20570 OR `modelid2` = 20570 OR `modelid3` = 20570 OR `modelid4` = 20570 OR `entry` = 58959;

UPDATE `creature_template`
SET `modelid1` = 20570
WHERE `entry` = 58959;

UPDATE `creature`
SET `modelid` = 0
WHERE `modelid` = 20570;
