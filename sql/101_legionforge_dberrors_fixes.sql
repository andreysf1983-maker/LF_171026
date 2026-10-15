-- =====================================================================
-- LEGIONFORGE 7.3.5.26124 - [101] Final DBErrors.log / ОШИБКИ.txt cleanup
-- Rev.2 (2026-10-13) after the setup.bat run that failed on rev.1:
--   "ERROR 1054 Unknown column 'RewardSpellCast'" -> column is `RewardSpell`.
-- EVERY table/column below is verified against the SELECT/UPDATE statements
-- the core itself executes on this database (ObjectMgr.cpp, LootMgr.cpp,
-- AreaTriggerDataStore.cpp, WorldDatabase.cpp, WaypointManager.cpp,
-- CreatureGroups.cpp). Every placeholder loot row satisfies
-- LootStoreItem::IsValid (item exists, MinCount>=1, Chance>0).
-- Applies to: WORLD database. Idempotent. No statement references its own
-- target table inside a subquery (MySQL error 1093 safe).
-- =====================================================================

-- [DBE-1] Custom LEGIONFORGE vendors 900100-900103 had NO display id at all
-- (43_legionforge_upgrade_tokens.sql re-created them without modelid1 ->
-- "does not have any existing display id", NPC invisible in game).
-- Use the Stormwind City Guard model (entry 68) when available, else 3167.
-- 43_* is fixed at the source as well; this is the safety net for play.bat.
SET @lf_guard_model = COALESCE((SELECT `modelid1` FROM `creature_template` WHERE `entry` = 68 AND `modelid1` > 0 LIMIT 1), 3167);
UPDATE `creature_template` SET `modelid1` = @lf_guard_model
 WHERE `entry` IN (900100, 900101, 900102, 900103)
   AND COALESCE(`modelid1`,0) = 0 AND COALESCE(`modelid2`,0) = 0
   AND COALESCE(`modelid3`,0) = 0 AND COALESCE(`modelid4`,0) = 0;

-- [DBE-2] Creature 9500100 (mail sender from 26_welcome_sender.sql) has
-- unit_class 0 -> warrior (1). 26_* fixed at the source as well.
UPDATE `creature_template` SET `unit_class` = 1
 WHERE `entry` = 9500100 AND COALESCE(`unit_class`,0) = 0;

-- [DBE-3] Creature 29264 references spell 58859 (absent in 26124).
UPDATE `creature_template` SET `spell1` = 0
 WHERE `entry` = 29264 AND `spell1` = 58859;

-- [DBE-4] CONTROL_VEHICLE aura 46598 must not be in creature_template_addon
-- `auras` (core strips it at load for 42010, 41366, 43273, 43279).
UPDATE `creature_template_addon`
   SET `auras` = NULLIF(TRIM(REPLACE(CONCAT(' ', COALESCE(`auras`, ''), ' '), ' 46598 ', ' ')), '')
 WHERE `entry` IN (42010, 41366, 43273, 43279)
   AND CONCAT(' ', COALESCE(`auras`, ''), ' ') LIKE '% 46598 %';

-- [DBE-5] Idle creatures (MovementType=0) must have spawndist=0
-- (GUIDs 183746/183806 in the log; same fix the core applies in memory).
UPDATE `creature` SET `spawndist` = 0 WHERE `MovementType` = 0 AND `spawndist` <> 0;

-- [DBE-6] Quest 24974: reward spell 73435 does not exist in 26124.
-- Column is `RewardSpell` (log text says RewardSpellCast - legacy wording).
UPDATE `quest_template` SET `RewardSpell` = 0
 WHERE `ID` = 24974 AND `RewardSpell` = 73435;

-- [DBE-7] Quests 39733 / 44555 are completed by spell 267673
-- (SPELL_EFFECT_QUEST_COMPLETE) -> need QUEST_SPECIAL_FLAGS_EXPLORATION_OR_EVENT (2).
INSERT INTO `quest_template_addon` (`ID`, `SpecialFlags`)
SELECT q.`ID`, 2 FROM `quest_template` q
 WHERE q.`ID` IN (39733, 44555)
   AND NOT EXISTS (SELECT 1 FROM `quest_template_addon` a WHERE a.`ID` = q.`ID`);
UPDATE `quest_template_addon`
   SET `SpecialFlags` = COALESCE(`SpecialFlags`,0) | 2
 WHERE `ID` IN (39733, 44555)
   AND (COALESCE(`SpecialFlags`,0) & 2) = 0;

-- [DBE-8] Creature template 130758: UNIT_NPC_FLAG_SPELLCLICK (0x20000) without
-- rows in npc_spellclick_spells. Core removes the flag at load; persist it.
UPDATE `creature_template`
   SET `npcflag` = `npcflag` & ~131072
 WHERE `entry` = 130758
   AND (`npcflag` & 131072) <> 0
   AND NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` n WHERE n.`npc_entry` = 130758);

-- [DBE-9] Area trigger teleports pointing to PortLocID 0 (missing in
-- WorldSafeLocs.db2 26124): dead rows, core skips them at every boot.
DELETE FROM `areatrigger_teleport` WHERE `PortLocID` = 0;

-- [DBE-10] areatrigger spawn_mask 8388870 = normal|heroic|mythic (bits 1,2,23)
-- is CORRECT for the Legion 5-man dungeons in the log. The 19 "wrong spawn
-- mask" lines are a false positive of a core bug (AreaTriggerDataStore.cpp
-- indexed spawnMasks[] by the mask instead of by map id) -> fixed in code,
-- disappears after the next build_server.bat. DO NOT touch dungeon masks:
-- clearing bit 23 would remove boss area triggers from Mythic difficulty.
-- The 5 rows on RAID maps carry the dungeon mask and therefore never spawn
-- in any raid difficulty -> give them the raid mask (14 N,15 H,16 M,17 LFR).
UPDATE `areatrigger` SET `spawn_mask` = 245760
 WHERE `map_id` IN (1520, 1648, 1530, 1676) AND `spawn_mask` = 8388870;

-- [DBE-11] Creature 36756 has lootid 36756 but creature_loot_template has
-- no such template -> the creature already drops nothing; make it explicit.
UPDATE `creature_template` SET `lootid` = 0
 WHERE `entry` = 36756 AND `lootid` = 36756
   AND NOT EXISTS (SELECT 1 FROM `creature_loot_template` t WHERE t.`Entry` = 36756);

-- [DBE-12] gameobject_loot_template rows were keyed by the CHEST ENTRY instead
-- of by its loot id (Data1): 204281->30786, 203751->29946, 203801->29959,
-- 203762->29952 ("Entry X does not exist but it is used by Gameobject Y" and
-- "Entry Y isn't gameobject entry ... useless" come in pairs). Re-key them so
-- the chests actually get the loot that was written for them.
UPDATE `gameobject_loot_template` glt
  JOIN `gameobject_template` gt ON gt.`entry` = glt.`Entry` AND gt.`type` = 3
   SET glt.`Entry` = gt.`Data1`
 WHERE glt.`Entry` IN (204281, 203751, 203801, 203762)
   AND gt.`Data1` IN (30786, 29946, 29959, 29952);

-- [DBE-13] disenchant_loot_template 180..185 are referenced by ItemSparse.db2
-- (DisenchantID, not editable in SQL) but have no rows. Clone the nearest
-- lower existing template (same expansion tier) for each missing id.
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 180, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 180)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 180);
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 181, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 181)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 181);
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 182, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 182)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 182);
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 183, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 183)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 183);
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 184, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 184)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 184);
INSERT INTO `disenchant_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 185, d.`Item`, d.`Reference`, d.`Chance`, d.`QuestRequired`, d.`LootMode`, d.`GroupId`, d.`MinCount`, d.`MaxCount`
  FROM `disenchant_loot_template` d
 WHERE d.`Entry` = (SELECT MAX(x.`Entry`) FROM `disenchant_loot_template` x WHERE x.`Entry` < 185)
   AND NOT EXISTS (SELECT 1 FROM `disenchant_loot_template` e WHERE e.`Entry` = 185);

-- [DBE-14] spell_loot_template rows whose Item is absent from Item.db2 26124
-- (items come from DB2; there is NO item_template table in a 7.x world db).
-- Exact (Entry, Item) pairs from DBErrors.log; the core skips them anyway.
DELETE FROM `spell_loot_template`
 WHERE (`Entry` = 263154 AND `Item` IN (141812, 199880, 122799, 130660, 134337))
    OR (`Entry` = 263153 AND `Item` = 141822)
    OR (`Entry` = 263151 AND `Item` = 107079);

-- [DBE-15] 15 spells present in this client's SpellEffect.db2 (BfA-era
-- "open container" effects) require a spell_loot_template; the original BfA
-- item rows cannot load (items absent) and were removed by 100_part2.
-- Minimal valid template: 1x Linen Cloth (2589, exists in every build),
-- Chance 100 -> passes IsValid, no per-row errors. The containers these
-- spells belong to do not exist in 26124, so the spells are never cast.
INSERT INTO `spell_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT x.`Entry`, 2589, 0, 100, 0, 1, 0, 1, 1
  FROM (SELECT 253113 AS `Entry` UNION ALL SELECT 253116 UNION ALL SELECT 253117 UNION ALL SELECT 253118
        UNION ALL SELECT 253125 UNION ALL SELECT 253132 UNION ALL SELECT 253135 UNION ALL SELECT 253138
        UNION ALL SELECT 253141 UNION ALL SELECT 253144 UNION ALL SELECT 253149 UNION ALL SELECT 253156
        UNION ALL SELECT 253157 UNION ALL SELECT 253158 UNION ALL SELECT 253159) x
 WHERE NOT EXISTS (SELECT 1 FROM `spell_loot_template` t WHERE t.`Entry` = x.`Entry`);

-- [DBE-16] reference_loot_template 210000..210019: not referenced by any loot
-- table ("isn't reference id and not referenced from loot, useless").
DELETE FROM `reference_loot_template`
 WHERE `Entry` BETWEEN 210000 AND 210019
   AND `Entry` NOT IN (
     SELECT r.`Reference` FROM (
       SELECT `Reference` FROM `creature_loot_template`
       UNION SELECT `Reference` FROM `gameobject_loot_template`
       UNION SELECT `Reference` FROM `item_loot_template`
       UNION SELECT `Reference` FROM `spell_loot_template`
       UNION SELECT `Reference` FROM `disenchant_loot_template`
       UNION SELECT `Reference` FROM `reference_loot_template`
     ) r WHERE r.`Reference` <> 0);

-- [DBE-17] creature_formations rows whose leader/member spawn no longer
-- exists (370509/370510/370570/370571) - core skips them; purge.
DELETE cf FROM `creature_formations` cf
  LEFT JOIN `creature` l ON l.`guid` = cf.`leaderGUID`
  LEFT JOIN `creature` m ON m.`guid` = cf.`memberGUID`
 WHERE l.`guid` IS NULL OR m.`guid` IS NULL;

-- [DBE-18] smart_scripts exist but the template does not select SmartAI
-- ("is not using SmartAI, skipped loading"). Enable SmartAI only where no
-- other AI and no C++ script is assigned (core's own recommendation).
UPDATE `creature_template` ct
  JOIN (SELECT DISTINCT `entryorguid` AS e FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` > 0) s ON s.e = ct.`entry`
   SET ct.`AIName` = 'SmartAI'
 WHERE ct.`entry` IN (4979, 9376, 10433, 15541, 15542, 17014, 23789, 29104, 37989, 38910, 42175, 46268, 54787, 65478, 121539, 123560)
   AND (ct.`AIName` = '' OR ct.`AIName` IS NULL)
   AND (ct.`ScriptName` = '' OR ct.`ScriptName` IS NULL);

-- [DBE-19] ScriptName 'areatrigger_runic_mark_1..5' exists in the ADB data but
-- the script is not part of this core -> unbind in every table that can
-- carry an areatrigger ScriptName.
UPDATE `areatrigger_template` SET `ScriptName` = '' WHERE `ScriptName` LIKE 'areatrigger\_runic\_mark\_%';
UPDATE `areatrigger`          SET `ScriptName` = '' WHERE `ScriptName` LIKE 'areatrigger\_runic\_mark\_%';
DELETE FROM `areatrigger_scripts` WHERE `ScriptName` LIKE 'areatrigger\_runic\_mark\_%';

-- [DBE-20] spell_script_names 'spell_spawn_flash_N_periodic' - same reason.
DELETE FROM `spell_script_names` WHERE `ScriptName` LIKE 'spell\_spawn\_flash\_%\_periodic';

-- [DBE-21] WaypointMovementGenerator::LoadPath "doesn't have waypoint path id"
-- (Xan'tish, Wretched Ghoul): patrol creatures whose creature_addon.path_id
-- has no rows in waypoint_data -> idle, path cleared. The load-time case
-- (path_id = 0) is already auto-fixed by the core.
UPDATE `creature` c
  JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
   SET c.`MovementType` = 0, ca.`path_id` = 0
 WHERE c.`MovementType` = 2
   AND ca.`path_id` > 0
   AND NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = ca.`path_id`);

-- =====================================================================
-- Post-checks (SELECT only; printed by apply_play_sql.ps1, never abort):
-- =====================================================================
SELECT 'DBE-1 vendors still without model' AS `check`, COUNT(*) AS `remaining`
  FROM `creature_template` WHERE `entry` IN (900100,900101,900102,900103)
   AND COALESCE(`modelid1`,0)=0 AND COALESCE(`modelid2`,0)=0
   AND COALESCE(`modelid3`,0)=0 AND COALESCE(`modelid4`,0)=0
UNION ALL
SELECT 'DBE-5 idle creatures with spawndist', COUNT(*) FROM `creature`
  WHERE `MovementType`=0 AND `spawndist`<>0
UNION ALL
SELECT 'DBE-13 disenchant 180-185 still missing', 6 - COUNT(DISTINCT `Entry`)
  FROM `disenchant_loot_template` WHERE `Entry` BETWEEN 180 AND 185
UNION ALL
SELECT 'DBE-15 spell loot templates still missing', 15 - COUNT(DISTINCT `Entry`)
  FROM `spell_loot_template` WHERE `Entry` IN (253113,253116,253117,253118,253125,253132,253135,253138,253141,253144,253149,253156,253157,253158,253159)
UNION ALL
SELECT 'DBE-21 patrols without waypoint path', COUNT(*)
  FROM `creature` c JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
  LEFT JOIN `waypoint_data` w ON w.`id` = ca.`path_id`
 WHERE c.`MovementType` = 2 AND ca.`path_id` > 0 AND w.`id` IS NULL;
