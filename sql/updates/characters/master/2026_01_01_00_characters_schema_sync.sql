-- =============================================================================
--  LEGIONFORGE 7.3.5 (build 26124)
--  Файл: sql/updates/characters/master/2026_01_01_00_characters_schema_sync.sql
--  База: characters
--
--  НАЗНАЧЕНИЕ.
--  Синхронизация схемы characters с подготовленными запросами ядра
--  (core/src/server/database/Database/Implementation/CharacterDatabase.cpp).
--  Без этих колонок/таблиц worldserver падал ещё до открытия мира:
--
--    mysql_stmt_prepare id 19/20/21/22 -> Unknown column 'c.lastLoginBuild'
--    mysql_stmt_prepare id 32/283/284  -> Unknown column 'inventorySlots'
--    mysql_stmt_prepare id 38          -> Unknown column 'explored'
--    mysql_stmt_prepare id 80          -> Table 'character_pvp_talent' doesn't exist
--    mysql_stmt_prepare id 119/120     -> Unknown column 'a.artifactTierId'
--
--  Скрипт полностью идемпотентен: каждый ALTER проверяется через
--  information_schema, повторный запуск безопасен.
--  Синтаксис намеренно тот же, что в sql/52_custom_races_31_44.sql -
--  без хранимых процедур и без DELIMITER, чтобы работать под mysql --force.
-- =============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 1. characters: inventorySlots / lastLoginBuild / xpRate
--    CHAR_SEL_CHARACTER (id 32), CHAR_INS_CHARACTER (id 283),
--    CHAR_UPD_CHARACTER (id 284), CHAR_SEL_ENUM (id 19..22)
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters'
                            AND COLUMN_NAME = 'inventorySlots'),
                  'DO 0',
                  'ALTER TABLE `characters` ADD COLUMN `inventorySlots` INT(10) UNSIGNED NOT NULL DEFAULT 0 AFTER `customDisplay3`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters'
                            AND COLUMN_NAME = 'lastLoginBuild'),
                  'DO 0',
                  'ALTER TABLE `characters` ADD COLUMN `lastLoginBuild` INT(10) UNSIGNED NOT NULL DEFAULT 0 AFTER `grantableLevels`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters'
                            AND COLUMN_NAME = 'xpRate'),
                  'DO 0',
                  'ALTER TABLE `characters` ADD COLUMN `xpRate` FLOAT NOT NULL DEFAULT 1 AFTER `lastLoginBuild`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 2. character_queststatus: explored
--    CHAR_SEL_CHARACTER_QUESTSTATUS: SELECT quest, status, timer, explored
--    Player::_LoadQuestStatus читает fields[3].GetBool()
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_queststatus'
                            AND COLUMN_NAME = 'explored'),
                  'DO 0',
                  'ALTER TABLE `character_queststatus` ADD COLUMN `explored` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `timer`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 3. character_pet: active (CHAR_SEL_ENUM / CHAR_SEL_ENUM_DECLINED_NAME)
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_pet'
                            AND COLUMN_NAME = 'active'),
                  'DO 0',
                  'ALTER TABLE `character_pet` ADD COLUMN `active` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `renamed`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 4. character_garrison: type
--    CHAR_SEL/INS/DEL_CHARACTER_GARRISON используют `type`
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison'
                            AND COLUMN_NAME = 'type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison` ADD COLUMN `type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `guid`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 5. character_garrison_blueprints: garrison_type
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison_blueprints'
                            AND COLUMN_NAME = 'garrison_type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison_blueprints` ADD COLUMN `garrison_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `guid`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 6. item_instance_artifact: artifactTierId
--    CHAR_SEL_ITEM_INSTANCE_ARTIFACT / CHAR_INS_ITEM_INSTANCE_ARTIFACT
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'item_instance_artifact'
                            AND COLUMN_NAME = 'artifactTierId'),
                  'DO 0',
                  'ALTER TABLE `item_instance_artifact` ADD COLUMN `artifactTierId` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `artifactAppearanceId`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 7. character_instance НЕ получает resettime / entranceId.
-- Эти поля принадлежат таблице `instance`; см. migration
-- 2026_01_01_02_character_instance_join_fix.sql для очистки уже затронутых БД.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 8. Таблица character_pvp_talent (PvP-таланты Legion 7.3.5)
--    CHAR_SEL_CHARACTER_PVP_TALENTS / CHAR_DEL_CHAR_PVP_TALENT /
--    CHAR_INS_CHAR_PVP_TALENT
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `character_pvp_talent` (
  `guid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `talentId` smallint(5) unsigned NOT NULL DEFAULT '0',
  `talentGroup` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`talentGroup`,`talentId`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Player PvP Talents';

-- ---------------------------------------------------------------------------
-- 9. Контрольная проверка (ожидаются единицы во всех колонках)
-- ---------------------------------------------------------------------------
SELECT 'LEGIONFORGE characters schema sync' AS status,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters'
            AND COLUMN_NAME IN ('inventorySlots','lastLoginBuild','xpRate'))        AS characters_ok,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_queststatus'
            AND COLUMN_NAME = 'explored')                                           AS quest_explored_ok,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'item_instance_artifact'
            AND COLUMN_NAME = 'artifactTierId')                                     AS artifact_tier_ok,
       (SELECT COUNT(*) FROM information_schema.TABLES
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_pvp_talent')  AS pvp_talent_ok;
