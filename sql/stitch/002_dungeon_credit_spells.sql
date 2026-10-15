-- spell_gen_dungeon_credit credits an encounter when the creature casts the spell.
-- These ten spell ids are not in the Legion client spell list (or the hotfix overlay),
-- so the binding can never fire and the server reports a missing spell at startup.
-- Bindings that do exist are left in place: 61863, 68663, 72706, 72830, 72959.

DELETE FROM `spell_script_names`
WHERE `ScriptName` = 'spell_gen_dungeon_credit'
  AND `spell_id` IN (58630, 59046, 59450, 64899, 64985, 65074, 65195, 68184, 68572, 68574);
