-- Откат sql/49_legion_allied_races_hotbar.sql: очистить панель союзных рас.
DELETE FROM `playercreateinfo_action` WHERE `race` IN (27, 28, 29, 30);
