-- ============================================================
-- Quest audit queries (world database)
-- Use with: mysql --defaults-extra-file=setup_tmp/mysql.cnf world
-- Documented in: docs/quests/README.md
-- ============================================================

-- 1) Kill objectives with NO creature spawn anywhere in world (NOT EXISTS — safe for only_full_group_by)
SELECT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID AS creature_entry, qo.Description
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
WHERE qo.Type = 0
  AND qo.ObjectID > 0
  AND qt.QuestLevel BETWEEN 1 AND 20
  AND NOT EXISTS (SELECT 1 FROM creature c WHERE c.id = qo.ObjectID)
ORDER BY qt.QuestSortID, qo.QuestID
LIMIT 500;

-- 1b) Same as (1) but exclude training dummy 44175 (class practice quests)
SELECT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID AS creature_entry, qo.Description
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
WHERE qo.Type = 0
  AND qo.ObjectID > 0
  AND qo.ObjectID != 44175
  AND qt.QuestLevel BETWEEN 1 AND 20
  AND qt.LogTitle NOT LIKE '[DEPRECATED]%'
  AND NOT EXISTS (SELECT 1 FROM creature c WHERE c.id = qo.ObjectID)
ORDER BY qt.QuestSortID, qo.QuestID
LIMIT 500;

-- 2) Quests that provide an item + require killing same creature (P05-ITEM-USE-CAPTURE candidates)
SELECT qt.ID, qt.LogTitle, qt.QuestSortID, qt.StartItem, qo.ObjectID AS target_entry, qo.Description
FROM quest_template qt
JOIN quest_objectives qo ON qo.QuestID = qt.ID AND qo.Type = 0
WHERE qt.StartItem > 0
  AND qt.QuestLevel BETWEEN 1 AND 20
ORDER BY qt.QuestSortID, qt.ID;

-- 3) Phase areas linked to quest accept (condition type 9)
SELECT c.SourceGroup AS area_or_phase_id, c.ConditionValue1 AS quest_id,
       qt.LogTitle, c.Comment
FROM conditions c
LEFT JOIN quest_template qt ON qt.ID = c.ConditionValue1
WHERE c.SourceTypeOrReferenceId = 26
  AND c.ConditionTypeOrReference = 9
ORDER BY c.SourceGroup, c.ConditionValue1;

-- 4) Quests with criteria-tree objectives (P07 — scripted / scenario-like)
SELECT DISTINCT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID AS criteria_tree_id
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
WHERE qo.Type = 14
  AND qt.QuestLevel BETWEEN 1 AND 20
ORDER BY qt.QuestSortID, qo.QuestID;

-- 5) Custom quest scripts registered in DB
SELECT qta.ID, qt.LogTitle, qta.ScriptName
FROM quest_template_addon qta
JOIN quest_template qt ON qt.ID = qta.ID
WHERE qta.ScriptName IS NOT NULL AND qta.ScriptName != ''
ORDER BY qta.ID;

-- 6) Chain breaks: NextQuestID points to missing quest
SELECT qta.ID, qt.LogTitle, qta.NextQuestID AS broken_next
FROM quest_template_addon qta
JOIN quest_template qt ON qt.ID = qta.ID
LEFT JOIN quest_template nxt ON nxt.ID = qta.NextQuestID
WHERE qta.NextQuestID > 0 AND nxt.ID IS NULL
LIMIT 100;

-- 8) Instance-only kill objectives (creature has no open-world spawn)
SELECT DISTINCT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID AS creature_entry,
       c.map, c.zoneId, c.areaId
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
JOIN creature c ON c.id = qo.ObjectID
WHERE qo.Type = 0 AND qo.ObjectID > 0 AND qt.QuestLevel BETWEEN 1 AND 30
  AND NOT EXISTS (
    SELECT 1 FROM creature c2
    WHERE c2.id = qo.ObjectID AND c2.map IN (0, 1, 530, 571, 732, 870, 1116, 1220, 1464)
  )
ORDER BY qt.QuestSortID, qo.QuestID;
