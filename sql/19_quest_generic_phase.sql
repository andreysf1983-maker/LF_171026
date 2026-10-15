-- ============================================================
-- Assign quest_generic_phase to all phased quests without custom scripts
-- Ensures phase refresh on accept / complete / reward / abandon
-- ============================================================

UPDATE `quest_template_addon` qta
INNER JOIN (
    SELECT DISTINCT `ConditionValue1` AS quest_id
    FROM `conditions`
    WHERE `SourceTypeOrReferenceId` = 26
      AND `ConditionTypeOrReference` IN (8, 9, 28)
      AND `ConditionValue1` > 0
) c ON c.quest_id = qta.ID
SET qta.`ScriptName` = 'quest_generic_phase'
WHERE IFNULL(qta.`ScriptName`, '') = '';
