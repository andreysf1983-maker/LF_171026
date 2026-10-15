-- ============================================================
-- Warlock starter pet: remove legacy Summon Imp (688) auto-cast
-- Legion teaches the demon via specialization spells at the proper level.
-- Applied to: world database
-- ============================================================

DELETE FROM `playercreateinfo_cast_spell`
WHERE `classMask` = 256 AND `spell` = 688;
