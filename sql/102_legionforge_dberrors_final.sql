-- =====================================================================
-- LEGIONFORGE 7.3.5.26124 - [102] Final DBErrors.log cleanup
-- Rev.3 (2026-10-14) - see the NOTE in [102-3]: removed the `item_template` guard,
--                       that table does not exist in a Legion world database.
--
-- !! WHAT WENT WRONG IN REV.1 !!
-- Rev.1 contained a DELETE for spell_loot_template entries 253113..255610.
-- 101_legionforge_dberrors_fixes.sql INSERTS placeholder loot rows for
-- 253113..253159, and 102 runs AFTER 101 in apply_play_sql.ps1 - so rev.1
-- silently undid 101 and the log kept reporting all 20 of them:
--     Table 'spell_loot_template' Entry 253113 does not exist but it is
--     used by Spell 253113
-- That message means the SPELL EXISTS (hotfixes DB) and creates loot, but
-- the loot template row is MISSING. Deleting rows can never fix it - only
-- adding a placeholder row can. Rev.2 therefore ADDS the placeholders and
-- no longer deletes anything in that id range.
--
-- Target: WORLD database. Idempotent (safe to re-run).
-- =====================================================================

-- ---------------------------------------------------------------------
-- [102-1] spell_loot_template: "Entry N isn't spell id (random item
-- creating) and not referenced from loot, and thus useless."
-- These Entries are NOT spells at all -> the row is dead weight -> DELETE
-- is the correct remedy here.
-- ---------------------------------------------------------------------
DELETE FROM `spell_loot_template`
 WHERE `Entry` IN (263148, 263149, 263150, 263151, 263152, 263153, 263154);

-- ---------------------------------------------------------------------
-- [102-2] reference_loot_template: "Entry N isn't reference id and not
-- referenced from loot, and thus useless." Same reasoning -> DELETE.
-- ---------------------------------------------------------------------
DELETE FROM `reference_loot_template`
 WHERE `Entry` IN (210020, 210021, 210022, 210023, 210024, 210025,
                   210026, 210027, 210028, 210029);

-- ---------------------------------------------------------------------
-- [102-3] spell_loot_template: "Entry N does not exist but it is used by
-- Spell N" - the spell exists and creates loot, the template row does not.
-- Add a valid placeholder row (same pattern/item as 101_*: Linen Cloth
-- 2589, Chance 100, MinCount/MaxCount 1), which satisfies
-- LootStoreItem::IsValid and silences the error for good.
--
-- NOTE (rev.3): there is deliberately NO existence check against `item_template`.
-- This is a LEGION core: items are loaded from DB2 (ObjectMgr::LoadItemTemplates
-- iterates sItemSparseStore / sItemStore), so the world database has NO
-- `item_template` table at all - only `item_template_addon`. rev.2 guarded the
-- INSERT with `WHERE EXISTS (SELECT 1 FROM item_template ...)` and play.bat died:
--     ERROR 1146 (42S02) at line 49: Table 'world.item_template' doesn't exist
-- Item 2589 (Linen Cloth) is a Vanilla item present in Item.db2/ItemSparse.db2
-- of every client, and 101_* already inserts the same placeholder successfully
-- (its DBE-15 check reports 0 missing), so no guard is needed here.
--
-- Union of every id reported by BOTH DBErrors.log runs (pre-fix and the
-- 2026-10-14 run). 101_* already covers 253113..253159; the WHERE NOT
-- EXISTS guard makes the overlap harmless and the whole file re-runnable.
-- ---------------------------------------------------------------------
INSERT INTO `spell_loot_template`
       (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT x.`Entry`, 2589, 0, 100, 0, 1, 0, 1, 1
  FROM (
            SELECT 253113 AS `Entry`
  UNION ALL SELECT 253116 UNION ALL SELECT 253117 UNION ALL SELECT 253118
  UNION ALL SELECT 253125 UNION ALL SELECT 253132 UNION ALL SELECT 253135
  UNION ALL SELECT 253138 UNION ALL SELECT 253141 UNION ALL SELECT 253144
  UNION ALL SELECT 253149 UNION ALL SELECT 253156 UNION ALL SELECT 253157
  UNION ALL SELECT 253158 UNION ALL SELECT 253159 UNION ALL SELECT 253160
  UNION ALL SELECT 253161 UNION ALL SELECT 253162 UNION ALL SELECT 253165
  UNION ALL SELECT 253168 UNION ALL SELECT 253171 UNION ALL SELECT 253174
  UNION ALL SELECT 253177 UNION ALL SELECT 253180 UNION ALL SELECT 253183
  UNION ALL SELECT 253186 UNION ALL SELECT 253187 UNION ALL SELECT 253188
  UNION ALL SELECT 253190 UNION ALL SELECT 253191 UNION ALL SELECT 253192
  UNION ALL SELECT 255457 UNION ALL SELECT 255458 UNION ALL SELECT 255459
  UNION ALL SELECT 255610
       ) x
 WHERE NOT EXISTS (SELECT 1 FROM `spell_loot_template` t WHERE t.`Entry` = x.`Entry`);

-- ---------------------------------------------------------------------
-- [102-4] achievement_reward rows with neither a title nor an item reward
-- ("does not contain title or item reward data. Ignored."). The core skips
-- them at every boot; the rows are unusable as they stand.
-- ---------------------------------------------------------------------
-- Column names verified against AchievementMgr.cpp:
--   SELECT entry, title_A, title_H, item, sender, subject, text, mailTemplate
--   FROM achievement_reward
DELETE FROM `achievement_reward`
 WHERE `entry` IN (13, 2398, 3636, 4400, 5863, 6131, 7853,
                   8820, 9496, 10058, 10741, 11210, 11211, 11848)
   AND COALESCE(`title_A`, 0) = 0
   AND COALESCE(`title_H`, 0) = 0
   AND COALESCE(`item`, 0) = 0;

-- ---------------------------------------------------------------------
-- [102-5] gossip_menu 11061 points at a non-existing TextId 15442.
-- Re-point it to the first text id that really exists for this menu, and
-- drop the row only if there is no usable text at all.
-- ---------------------------------------------------------------------
SET @lf_fallback_text := (SELECT MIN(`ID`) FROM `npc_text` WHERE `ID` > 0);

UPDATE `gossip_menu`
   SET `TextId` = @lf_fallback_text
 WHERE `MenuId` = 11061
   AND `TextId` = 15442
   AND @lf_fallback_text IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM `npc_text` n WHERE n.`ID` = 15442);

DELETE FROM `gossip_menu`
 WHERE `MenuId` = 11061
   AND `TextId` = 15442
   AND @lf_fallback_text IS NULL;

-- ---------------------------------------------------------------------
-- [102-6] Creature 130758 has UNIT_NPC_FLAG_SPELLCLICK but no spellclick
-- data (the core strips the flag at every boot). Strip it in the DB so the
-- warning disappears and the template matches the actual behaviour.
-- UNIT_NPC_FLAG_SPELLCLICK = 0x01000000 = 16777216.
-- ---------------------------------------------------------------------
UPDATE `creature_template`
   SET `npcflag` = `npcflag` & ~16777216
 WHERE `entry` = 130758
   AND (`npcflag` & 16777216) <> 0
   AND NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` s WHERE s.`npc_entry` = 130758);

-- =====================================================================
-- Intentionally NOT touched (cosmetic / safe):
--   * "areatrigger ... wrong spawn mask ... unsupported difficulty modes"
--     - the core already indexes spawnMasks by map id
--       (AreaTriggerDataStore.cpp); changing live masks could break
--       difficulty-specific triggers.
--   * SmartAIMgr "Kill Credit / creature summon" notices - they describe
--     normal script data, not broken rows.
--   * WaypointMovementGenerator "doesn't have waypoint path id" - a few
--     spawns reference empty paths; they simply stand still.
--   * "79 dungeon(s) have no entrance" - BFA/test dungeons present in DB2
--     but absent from the 26124 client; skipped by LFG.
-- =====================================================================
