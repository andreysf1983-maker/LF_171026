-- =============================================================================
--  LEGIONFORGE 7.3.5 (build 26124)
--  Файл: sql/updates/characters/master/2026_01_01_01_characters_missing_tables.sql
--  База: characters
--
--  Создание таблиц и колонок, на которые ссылается ядро, но которых нет в
--  sql/base/characters.sql. Без них mysql_stmt_prepare возвращал ошибку и
--  worldserver не поднимал базу персонажей (см. ОШИБКИ.txt, строки 215-253):
--
--    Unknown column 'active'                        (character_pet)
--    Unknown column 'type' / 'garrison_type'        (character_garrison*)
--    Table 'characters.character_garrison_missions' doesn't exist
--    Table 'characters.world_quest'                 doesn't exist
--    Table 'characters.log_gm'                      doesn't exist
--    Table 'characters.character_shop'              doesn't exist
--    Table 'characters.character_recovery'          doesn't exist
--
--  Скрипт идемпотентен. Синтаксис без DELIMITER - для запуска под mysql --force.
-- =============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 1. garrison_type в таблицах гарнизона (Legion 7.3.5: гарнизоны + залы классов)
-- ---------------------------------------------------------------------------
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison' AND COLUMN_NAME = 'garrison_type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison` ADD COLUMN `garrison_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `type`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison_blueprints' AND COLUMN_NAME = 'garrison_type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison_blueprints` ADD COLUMN `garrison_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `guid`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison_buildings' AND COLUMN_NAME = 'garrison_type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison_buildings` ADD COLUMN `garrison_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `guid`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'character_garrison_followers' AND COLUMN_NAME = 'garrison_type'),
                  'DO 0',
                  'ALTER TABLE `character_garrison_followers` ADD COLUMN `garrison_type` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `guid`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 2. character_garrison_missions
--    CHAR_SEL/UPD/INS/DEL_CHARACTER_GARRISON_MISSIONS (id 551-555)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `character_garrison_missions` (
  `dbId` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `guid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `garrison_type` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `missionId` int(10) unsigned NOT NULL DEFAULT '0',
  `offerTime` int(10) unsigned NOT NULL DEFAULT '0',
  `startTime` int(10) unsigned NOT NULL DEFAULT '0',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`dbId`),
  KEY `idx_guid_type` (`guid`,`garrison_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Garrison Missions';

-- ---------------------------------------------------------------------------
-- 3. world_quest (мировые задания Legion, состояние на аккаунте мира)
--    CHAR_SEL_WORLD_QUEST / CHAR_DEL_WORLD_QUEST / CHAR_REP_WORLD_QUEST
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `world_quest` (
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `rewardid` int(10) unsigned NOT NULL DEFAULT '0',
  `starttime` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='World Quest state';

-- ---------------------------------------------------------------------------
-- 4. log_gm - журнал GM-команд (CHAR_LOG_GM_COMMAND, id 569)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `log_gm` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gm_account_id` int(10) unsigned NOT NULL DEFAULT '0',
  `gm_account_name` varchar(64) NOT NULL DEFAULT '',
  `gm_character_id` bigint(20) unsigned NOT NULL DEFAULT '0',
  `gm_character_name` varchar(12) NOT NULL DEFAULT '',
  `gm_ip` varchar(46) NOT NULL DEFAULT '',
  `target_account_id` int(10) unsigned NOT NULL DEFAULT '0',
  `target_account_name` varchar(64) NOT NULL DEFAULT '',
  `target_character_id` bigint(20) unsigned NOT NULL DEFAULT '0',
  `target_character_name` varchar(12) NOT NULL DEFAULT '',
  `target_ip` varchar(46) NOT NULL DEFAULT '',
  `command` mediumtext,
  PRIMARY KEY (`id`),
  KEY `idx_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='GM Command log';

-- ---------------------------------------------------------------------------
-- 5. character_shop - выдача товаров магазина (CHAR_SEL_SHOP, id 571)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `character_shop` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `guid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `type` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `itemId` int(10) unsigned NOT NULL DEFAULT '0',
  `itemCount` int(10) unsigned NOT NULL DEFAULT '0',
  `delivered` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_guid_delivered` (`guid`,`delivered`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Shop delivery queue';

-- ---------------------------------------------------------------------------
-- 6. character_recovery - восстановление персонажей (CHAR_SEL_RECOVERY, id 573)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `character_recovery` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `account` int(10) unsigned NOT NULL DEFAULT '0',
  `race` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `class` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `level` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `skill1` smallint(5) unsigned NOT NULL DEFAULT '0',
  `skill1_value` smallint(5) unsigned NOT NULL DEFAULT '0',
  `skill2` smallint(5) unsigned NOT NULL DEFAULT '0',
  `skill2_value` smallint(5) unsigned NOT NULL DEFAULT '0',
  `items` text,
  `spells` text,
  `at_login` smallint(5) unsigned NOT NULL DEFAULT '0',
  `delivered` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_account_delivered` (`account`,`delivered`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Character recovery queue';

-- ---------------------------------------------------------------------------
-- 7. Контрольная проверка: 7 = все таблицы на месте
-- ---------------------------------------------------------------------------
SELECT 'LEGIONFORGE characters missing tables sync' AS status,
       (SELECT COUNT(*) FROM information_schema.TABLES
          WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME IN ('character_garrison_missions','world_quest',
                               'log_gm','character_shop','character_recovery')) AS tables_created,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE()
            AND CONCAT(TABLE_NAME,'.',COLUMN_NAME) IN
                ('character_garrison.garrison_type',
                 'character_garrison_blueprints.garrison_type',
                 'character_garrison_buildings.garrison_type',
                 'character_garrison_followers.garrison_type'))                    AS garrison_type_cols;
