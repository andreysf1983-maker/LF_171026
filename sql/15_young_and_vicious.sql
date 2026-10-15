-- ============================================================
-- Young and Vicious (24626) — Swiftclaw visibility + quest script hook
-- Applied to: world database
-- ============================================================

UPDATE `quest_template_addon`
SET `ScriptName` = 'quest_young_and_vicious'
WHERE `ID` = 24626;

-- Aura 49414 on template addon could block visibility before quest accept
UPDATE `creature_template_addon`
SET `auras` = ''
WHERE `entry` = 37989;
