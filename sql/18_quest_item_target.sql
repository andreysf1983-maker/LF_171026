-- ============================================================
-- Data-driven P05 item-use quest credits (legion_quest_item_target)
-- Creature uses ScriptName npc_quest_item_target
-- ============================================================

CREATE TABLE IF NOT EXISTS `legion_quest_item_target` (
  `creature_entry` int unsigned NOT NULL,
  `spell_id` int unsigned NOT NULL DEFAULT 0 COMMENT '0 = any spell while player has item',
  `quest_id` int unsigned NOT NULL,
  `item_id` int unsigned NOT NULL DEFAULT 0,
  `credit_entry` int unsigned NOT NULL,
  `follow_player` tinyint unsigned NOT NULL DEFAULT 0,
  `despawn_ms` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`creature_entry`, `quest_id`, `spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Echo Isles (6453)
REPLACE INTO `legion_quest_item_target`
  (`creature_entry`, `spell_id`, `quest_id`, `item_id`, `credit_entry`, `follow_player`, `despawn_ms`)
VALUES
  (39157, 70874, 24623, 52283, 39157, 1, 60000),
  (38560, 70879, 24813, 52065, 38560, 0, 3000);

UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = 'npc_quest_item_target'
WHERE `entry` IN (39157, 38560);

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (39157, 38560) AND `source_type` = 0;
