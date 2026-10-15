-- Imp (entry 416) was using Legion display 64799, which is the oversized model.
-- Classic display 4449 is the small imp. Saved pets copy the display from
-- character_pet, so the template change alone does not resize an existing imp.
-- world: creature_template. characters: character_pet.

UPDATE `creature_template`
SET `modelid1` = 4449
WHERE `entry` = 416 AND `modelid1` = 64799;

UPDATE `creature_template`
SET `modelid2` = 0
WHERE `entry` = 416 AND `modelid2` = 64799;
