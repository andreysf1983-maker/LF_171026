DELETE FROM `spell_script_names`
WHERE `spell_id` = 84338 AND `ScriptName` = 'spell_scenario_npc_landing';

UPDATE `creature_template`
SET `ScriptName` = ''
WHERE `entry` IN (63315, 67939, 67940, 73082)
  AND `ScriptName` = 'npc_scenario_door';

DROP TABLE IF EXISTS `scenario_npc_landing`;
DROP TABLE IF EXISTS `scenario_map_landing`;
