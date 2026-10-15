-- Worgen (race 22) create rows were a copy of the human Northshire start.
-- Prince Liam Greymane (34850), the Lockdown giver, stands on map 654 (Gilneas).
-- The nearby stored marker 35010 is the open square beside him.
-- Death knights stay on the Ebon Hold start (map 609).

UPDATE `playercreateinfo`
SET `map` = 654,
    `zone` = 4756,
    `position_x` = -1437.25,
    `position_y` = 1420.74,
    `position_z` = 35.6393,
    `orientation` = 0
WHERE `race` = 22 AND `class` <> 6;

-- Phase 169 is the Gilneas Military District scene (Liam and the city guard).
-- Without this row a new worgen on map 654 sees an empty street.
INSERT INTO `phase_area` (`AreaId`, `PhaseId`, `Comment`)
VALUES (4756, 169, 'Gilneas Military District - worgen start, Prince Liam Greymane')
ON DUPLICATE KEY UPDATE `Comment` = VALUES(`Comment`);
