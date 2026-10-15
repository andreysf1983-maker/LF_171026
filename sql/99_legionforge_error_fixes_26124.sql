-- =====================================================================
-- LegionForge 7.3.5.26124 - Fixes for ОШИБКИ.txt (worldserver log 2026-10-12)
-- Generated from the actual startup log analysis. Apply to WORLD database.
-- Idempotent: safe to run multiple times. Backup first:
--   mysqldump world spell_loot_template spell_script_names smart_scripts
--     lfg_dungeon_template areatrigger_scripts gameobject_template_addon > backup.sql
-- Companion code fixes: ScenarioPackets.h / ScenarioMgr.cpp (crash),
-- ObjectMgr.cpp (quest type 15), LFGMgr.* (log aggregation),
-- DB2Stores.cpp (ASSERT hardening). See docs/FIX-2026-10-12.md
-- =====================================================================

-- [SQL-1] lfg_dungeon_template: coordinates for dungeons absent from
-- LFGDungeons.db2 of build 26124 (log: "contains coordinates for wrong dungeon")
DELETE FROM `lfg_dungeon_template` WHERE `dungeonId` IN (200, 228, 229, 230, 231, 232, 233, 234, 235, 236, 358);

-- [SQL-2] spell_loot_template rows referenced by spells that do not exist
-- in Spell.db2 26124 (227 rows, mostly BFA spells 253xxx). The loot can
-- never drop; core already skips them with an error per row.
-- Review with the SELECT first, then uncomment the DELETE.
-- SELECT * FROM `spell_loot_template` WHERE `entry` IN (253113, 253116, 253117, 253118, 253125, 253132, 253135, 253138, 253141, 253144, 253149, 253156, 253157, 253158, 253159, 253160, 253161, 253162, 253165, 253168, 253171, 253174, 253177, 253180, 253183, 253186, 253187, 253188, 253190, 253191, 253192, 255457, 255458, 255459, 255610, 256164, 256217, 256218, 256219, 256220, 256221, 256223, 256245, 256246, 256247, 256248, 256249, 256308, 256323, 256611, 256613, 256622, 256748, 256749, 256750, 256751, 256752, 256754, 256755, 256756, 256757, 256758, 256759, 256760, 256761, 256762, 256763, 256764, 256765, 256766, 256767, 256768, 256769, 256770, 256771, 256772, 256773, 256774, 256775, 256776, 256777, 256778, 256779, 256780, 256781, 256782, 256783, 256784, 256786, 256787, 256788, 256789, 257095, 257096, 257097, 257099, 257101, 257102, 257103, 257104, 257107, 257114, 257115, 257116, 257118, 257120, 257121, 257122, 257123, 257124, 257715, 257716, 257717, 257718, 257719, 257720, 257721, 257722, 257723, 257724, 260384, 261837, 263251, 265106, 265110, 265111, 265112, 265698, 269421, 269422, 269423, 269424, 269425, 269426, 269444, 269446, 269447, 269448, 269449, 269450, 269451, 269452, 269453, 269458, 269459, 269460, 269464, 269465, 269466, 269470, 269471, 269472, 269476, 269477, 269478, 269479, 269480, 269481, 269516, 269517, 269518, 269519, 269520, 269521, 269522, 269523, 269524, 269525, 269526, 269527, 269528, 269529, 269530, 269531, 269532, 269533, 269534, 269535, 269536, 269537, 269538, 269539, 269540, 269541, 269542, 269543, 269544, 269545, 269552, 269553, 269554, 269596, 269597, 269598, 269599, 269600, 269601, 269602, 269603, 269604, 269605, 269606, 269607, 269608, 269609, 269610, 269611, 269612, 269613, 269715, 269716, 269719, 269727, 269728, 269729, 269740, 269741, 269742, 272502, 272937, 273812, 273851, 278131, 278132, 278133, 278527, 280608);
-- DELETE FROM `spell_loot_template` WHERE `entry` IN (253113, 253116, 253117, 253118, 253125, 253132, 253135, 253138, 253141, 253144, 253149, 253156, 253157, 253158, 253159, 253160, 253161, 253162, 253165, 253168, 253171, 253174, 253177, 253180, 253183, 253186, 253187, 253188, 253190, 253191, 253192, 255457, 255458, 255459, 255610, 256164, 256217, 256218, 256219, 256220, 256221, 256223, 256245, 256246, 256247, 256248, 256249, 256308, 256323, 256611, 256613, 256622, 256748, 256749, 256750, 256751, 256752, 256754, 256755, 256756, 256757, 256758, 256759, 256760, 256761, 256762, 256763, 256764, 256765, 256766, 256767, 256768, 256769, 256770, 256771, 256772, 256773, 256774, 256775, 256776, 256777, 256778, 256779, 256780, 256781, 256782, 256783, 256784, 256786, 256787, 256788, 256789, 257095, 257096, 257097, 257099, 257101, 257102, 257103, 257104, 257107, 257114, 257115, 257116, 257118, 257120, 257121, 257122, 257123, 257124, 257715, 257716, 257717, 257718, 257719, 257720, 257721, 257722, 257723, 257724, 260384, 261837, 263251, 265106, 265110, 265111, 265112, 265698, 269421, 269422, 269423, 269424, 269425, 269426, 269444, 269446, 269447, 269448, 269449, 269450, 269451, 269452, 269453, 269458, 269459, 269460, 269464, 269465, 269466, 269470, 269471, 269472, 269476, 269477, 269478, 269479, 269480, 269481, 269516, 269517, 269518, 269519, 269520, 269521, 269522, 269523, 269524, 269525, 269526, 269527, 269528, 269529, 269530, 269531, 269532, 269533, 269534, 269535, 269536, 269537, 269538, 269539, 269540, 269541, 269542, 269543, 269544, 269545, 269552, 269553, 269554, 269596, 269597, 269598, 269599, 269600, 269601, 269602, 269603, 269604, 269605, 269606, 269607, 269608, 269609, 269610, 269611, 269612, 269613, 269715, 269716, 269719, 269727, 269728, 269729, 269740, 269741, 269742, 272502, 272937, 273812, 273851, 278131, 278132, 278133, 278527, 280608);

-- [SQL-3] spell_script_names bound to spells missing in 26124
-- (log: "_SpellScript::ValidateSpellInfo: Spell N does not exist").
-- These bindings are dead (script never loads). Review, then uncomment.
-- SELECT * FROM `spell_script_names` WHERE `spell_id` IN (39240, 39241, 49331, 52127, 56249, 60937, 62388, 65037, 65219, 71290, 74434, 81208, 86315, 90259, 92794, 94229, 103958, 114168, 114736, 115070, 117050, 137586, 157605, 159669);
-- DELETE FROM `spell_script_names` WHERE `spell_id` IN (39240, 39241, 49331, 52127, 56249, 60937, 62388, 65037, 65219, 71290, 74434, 81208, 86315, 90259, 92794, 94229, 103958, 114168, 114736, 115070, 117050, 137586, 157605, 159669);

-- [SQL-4] areatrigger_scripts for AreaTrigger IDs absent from AreaTrigger.db2
-- SELECT * FROM `areatrigger_scripts` WHERE `entry` IN (314, 373, 983, 1489, 1520, 2200, 2763, 3691, 5555, 5559, 6022, 7214, 7455, 7625, 7630, 9677, 11353, 11420, 12802, 149959, 151582);
-- DELETE FROM `areatrigger_scripts` WHERE `entry` IN (314, 373, 983, 1489, 1520, 2200, 2763, 3691, 5555, 5559, 6022, 7214, 7455, 7625, 7630, 9677, 11353, 11420, 12802, 149959, 151582);

-- [SQL-5] smart_scripts for creatures whose AIName is not SmartAI
-- (log: "is not using SmartAI, skipped loading"). Either set AIName='SmartAI'
-- in creature_template OR delete the orphan rows. Inspect first:
-- SELECT ct.entry, ct.AIName, COUNT(ss.entryorguid) FROM creature_template ct
--   JOIN smart_scripts ss ON ss.entryorguid=ct.entry AND ss.source_type=0
--  WHERE ct.entry IN (4979, 9376, 10433, 15541, 15542, 17014, 23789, 29104, 37989, 38910, 42175, 46268, 54787, 65478, 121539, 123560) GROUP BY ct.entry;
-- Option A (enable SmartAI where the scripts are intended):
-- UPDATE `creature_template` SET `AIName`='SmartAI' WHERE `entry` IN (4979, 9376, 10433, 15541, 15542, 17014, 23789, 29104, 37989, 38910, 42175, 46268, 54787, 65478, 121539, 123560) AND `AIName`='';
-- Option B (remove orphans): DELETE FROM `smart_scripts` WHERE `source_type`=0 AND `entryorguid` IN (4979, 9376, 10433, 15541, 15542, 17014, 23789, 29104, 37989, 38910, 42175, 46268, 54787, 65478, 121539, 123560);

-- [SQL-6] Orphan gameobject_template_addon (template deleted, addon left)
DELETE FROM `gameobject_template_addon` WHERE `entry` IN (235794, 280650)
  AND NOT EXISTS (SELECT 1 FROM `gameobject_template` gt WHERE gt.`entry`=`gameobject_template_addon`.`entry`);

-- [SQL-7] Custom creatures 900100-900103 / 9500100 from the log:
-- no valid display id / invalid unit_class. Fix display to a safe Legion
-- model (11686 = human male guard) or delete the customs if unused.
-- SELECT entry,name,modelid1,unit_class FROM creature_template WHERE entry IN (900100,900101,900102,900103,9500100);
UPDATE `creature_template` SET `unit_class`=1 WHERE `entry`=9500100 AND `unit_class`=0;
-- UPDATE `creature_template` SET `modelid1`=11686 WHERE `entry` IN (900100,900101,900102,900103) AND `modelid1`=0;

-- [SQL-8] Quest 24974 rewards spell 73435 which does not exist in 26124.
UPDATE `quest_template` SET `RewardSpellCast`=0 WHERE `ID`=24974 AND `RewardSpellCast`=73435;

-- [SQL-9] Creature 29264 references removed spell 58859 in Spell1.
UPDATE `creature_template` SET `spell1`=0 WHERE `entry`=29264 AND `spell1`=58859;

-- [SQL-10] Idle creatures with spawndist (auto-fixed at runtime, persist it)
UPDATE `creature` SET `spawndist`=0 WHERE `MovementType`=0 AND `spawndist`<>0;

-- [SQL-11] npc_spellclick_spells: template 130758 had the flag but no rows.
UPDATE `creature_template` SET `npcflag`=`npcflag` & ~16777216 WHERE `entry`=130758;
-- (verify the SPELLCLICK bit for your branch before running; see docs)

-- NOT auto-fixed (intentional, see docs/FIX-2026-10-12.md):
--  * 280 ScriptName rows without core scripts + 69 core scripts without DB
--    assignment: content backlog, NOT corruption. Exported to
--    docs/audit/scriptname_mismatch_2026-10-12.csv for scripting triage.
--    Do NOT mass-delete: several are boss scripts (Eye of Azshara etc.).
--  * 207 SpellScript effect mismatches + 48 Validate() failures: scripts
--    bound to spells whose DB2 effects changed in 26124. Triage list in CSV.
--  * BFA LFG dungeons (79): skipped by design on a Legion client.
--  * SpellEffect.db2 rows for spells 304000+/305000+ (1609 skipped):
--    data/dbc files are NOT from a clean 26124 client. Re-extract DB2
--    from the exact 7.3.5.26124 client; no SQL can fix wrong DB2 files.
