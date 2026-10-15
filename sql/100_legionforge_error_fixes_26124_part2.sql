-- =====================================================================
-- LegionForge 7.3.5.26124 - Fixes PART 2 for ОШИБКИ.txt (log 2026-10-12 21:23, 2293 lines)
-- Generated 2026-10-13 from the ACTUAL log of this clone. Apply to WORLD db.
-- Idempotent: safe to run multiple times. BACKUP FIRST:
--   mysqldump world spell_loot_template spell_script_names smart_scripts
--     conditions areatrigger_scripts gameobject_template_addon
--     criteria_data item_loot_template lfg_dungeon_template > backup_before_100.sql
-- Companion code fixes: DB2Stores.cpp / LootMgr.cpp / SmartScriptMgr.cpp /
-- ConditionMgr.cpp (ASSERT hardening + log aggregation). See
-- docs/FIX-2026-10-13_FULL_AUDIT.md
-- =====================================================================

-- [SAFE-1] lfg_dungeon_template for dungeons absent from LFGDungeons.db2 26124 (11)
DELETE FROM `lfg_dungeon_template` WHERE `dungeonId` IN (200, 228, 229, 230, 231, 232, 233, 234, 235, 236, 358);

-- [SAFE-2] spell_loot_template referenced by spells absent from Spell.db2 26124
-- (227 rows in log, mostly BFA spells 253xxx-280xxx; loot can never drop,
-- core skips every row with an error at each boot). Was commented out in 99_*, now applied.
DELETE FROM `spell_loot_template` WHERE `entry` IN (253113, 253116, 253117, 253118, 253125, 253132, 253135, 253138, 253141, 253144, 253149, 253156, 253157, 253158, 253159, 253160, 253161, 253162, 253165, 253168, 253171, 253174, 253177, 253180, 253183, 253186, 253187, 253188, 253190, 253191, 253192, 255457, 255458, 255459, 255610, 256164, 256217, 256218, 256219, 256220, 256221, 256223, 256245, 256246, 256247, 256248, 256249, 256308, 256323, 256611, 256613, 256622, 256748, 256749, 256750, 256751, 256752, 256754, 256755, 256756, 256757, 256758, 256759, 256760, 256761, 256762, 256763, 256764, 256765, 256766, 256767, 256768, 256769, 256770, 256771, 256772, 256773, 256774, 256775, 256776, 256777, 256778, 256779, 256780, 256781, 256782, 256783, 256784, 256786, 256787, 256788, 256789, 257095, 257096, 257097, 257099, 257101, 257102, 257103, 257104, 257107, 257114, 257115, 257116, 257118, 257120, 257121, 257122, 257123, 257124, 257715, 257716, 257717, 257718, 257719, 257720, 257721, 257722, 257723, 257724, 260384, 261837, 263251, 265106, 265110, 265111, 265112, 265698, 269421, 269422, 269423, 269424, 269425, 269426, 269444, 269446, 269447, 269448, 269449, 269450, 269451, 269452, 269453, 269458, 269459, 269460, 269464, 269465, 269466, 269470, 269471, 269472, 269476, 269477, 269478, 269479, 269480, 269481, 269516, 269517, 269518, 269519, 269520, 269521, 269522, 269523, 269524, 269525, 269526, 269527, 269528, 269529, 269530, 269531, 269532, 269533, 269534, 269535, 269536, 269537, 269538, 269539, 269540, 269541, 269542, 269543, 269544, 269545, 269552, 269553, 269554, 269596, 269597, 269598, 269599, 269600, 269601, 269602, 269603, 269604, 269605, 269606, 269607, 269608, 269609, 269610, 269611, 269612, 269613, 269715, 269716, 269719, 269727, 269728, 269729, 269740, 269741, 269742, 272502, 272937, 273812, 273851, 278131, 278132, 278133, 278527, 280608);

-- [SAFE-3] spell_script_names bindings to spells absent from 26124 (dead bindings,
-- script never loads). Exact IDs from "spell (Id: N) does not exist" in log.
DELETE FROM `spell_script_names` WHERE `spell_id` IN (-84583, -47569, -47509, -46951, -19572, 324, 1126, 7001, 8232, 19740, 20217, 20230, 25042, 27683, 30823, 39142, 45462, 47948, 47960, 50453, 50720, 50725, 53412, 55440, 58630, 58677, 59046, 59450, 59725, 61698, 62791, 64899, 64904, 64985, 65074, 65195, 68184, 68572, 68574, 70827, 72868, 72869, 75880, 88766, 91436, 91442, 91444, 93202, 93261, 93262, 93263, 94009, 103958, 106162, 108196, 108920, 108945, 114175, 114851, 115921, 123273, 123766, 123980, 124336, 140023, 159429, 206237, 342521, 534556);

-- [SAFE-4] ValidateSpellInfo missing spells (subset may overlap SAFE-3; idempotent)
DELETE FROM `spell_script_names` WHERE `spell_id` IN (65219, 103958, 159669, 157605, 52127, 56249, 86315, 39240, 39241, 49331, 60937, 65037, 71290, 0, 94229, 92794, 115070, 62388, 137586, 114168, 114736, 90259, 81208, 74434, 117050);

-- [SAFE-5] conditions Terrain Swap (SourceType 25) for maps absent from Map.db2 26124
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 25 AND `SourceEntry` IN (200244, 200243, 200301, 200302, 200303, 200304, 200305, 200306, 200200, 200201, 200202, 200203, 200204, 200205, 200206, 200207, 200208, 200209, 200210, 200211, 200212, 200213, 200214, 200215, 200216, 200217, 200218, 200219, 200220, 200221, 200222, 200223, 200224, 200225, 200226, 200227, 200228, 200229, 200230, 200231, 200232, 200233, 200234, 200235, 200236, 200237, 200238, 200239, 200240, 200241, 200242);

-- [SAFE-6] areatrigger_scripts for AreaTrigger IDs absent from AreaTrigger.db2
DELETE FROM `areatrigger_scripts` WHERE `entry` IN (2200, 9677, 5559, 314, 373, 5555, 2763, 1489, 7630, 7625, 149959, 983, 12802, 3691, 7214, 151582, 11420, 6022, 7455, 11353, 1520);

-- [SAFE-7] gameobject_template_addon orphans (template does not exist)
DELETE FROM `gameobject_template_addon` WHERE `entry` IN (280650, 235794);

-- [SAFE-8] criteria_data for non-existing criteria
DELETE FROM `criteria_data` WHERE `criteria_id` IN (6180, 10066, 10067, 6084, 6133);

-- [SAFE-9] item_loot_template useless entries (not an item, not referenced)
DELETE FROM `item_loot_template` WHERE `entry` IN (200100, 200101, 200102, 200103, 200104, 200105, 200106, 200107, 200108, 200109, 200110, 200111, 200112, 200113, 200114, 200115, 200116, 200117, 200118, 200119, 200120, 200121, 200122, 200123, 200124, 200125, 200126, 200127, 200128, 200129);

-- =====================================================================
-- REVIEW (NOT auto-applied - inspect with the SELECT, then uncomment):
-- =====================================================================
-- [R-1] disenchant_loot_template entries 180, 181, 182, 183, 184, 185: check item_template.DisenchantID
--   SELECT * FROM `item_template` WHERE `DisenchantID` IN (180, 181, 182, 183, 184, 185);
--   -- DELETE FROM `disenchant_loot_template` WHERE `entry` IN (180, 181, 182, 183, 184, 185);
-- [R-2] Creatures without any display id 900100, 900101, 900102, 900103 (custom 900100+):
--   set a valid Modelid from creature_model_info of build 26124, do NOT delete blindly.
-- [R-3] smart_scripts for creatures not using SmartAI 4979, 9376, 10433, 15541, 15542, 17014, 23789, 29104, 37989, 38910, 42175, 46268, 54787, 65478, 121539, 123560:
--   either UPDATE creature_template SET AIName='SmartAI' ... or DELETE orphan smart_scripts
--   after checking the creature is not scripted in C++ (ScriptName).
-- [R-4] achievement_reward rows with no title/item, areatrigger spawn-mask rows,
--   creature_formations with dead leader/member GUIDs, SPELL_AURA_CONTROL_VEHICLE
--   auras in creature_template_addon: content data - fix per-row, see audit doc CSV.
-- =====================================================================
