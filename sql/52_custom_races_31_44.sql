-- =============================================================================
--  LEGIONFORGE 7.3.5 (build 26124)
--  Файл:  sql/52_custom_races_31_44.sql        База: world
--  Тема:  кастомные расы клиента 31..44 (UWoW-подобная сборка build 26124)
--
--  Что делает:
--    1. Расширяет racemask-колонки до BIGINT UNSIGNED (бит расы 33..44 не
--       помещается в INT UNSIGNED - молча получался 0).
--    2. Клонирует стартовые данные расы-донора для каждой кастомной расы:
--         playercreateinfo, player_levelstats, playercreateinfo_item,
--         playercreateinfo_action, playercreateinfo_spell_custom,
--         playercreateinfo_cast_spell.
--    3. Прописывает race_unlock_requirement.expansion = 6 (Legion), иначе
--       HandleCharCreateOpcode отвечает CHAR_CREATE_FAILED
--       ("tried to create character with unavailable race").
--
--  Соответствие "раса -> донор" совпадает с CustomRaces.Definitions в
--  server/worldserver.conf.dist. Если меняете одно - меняйте и другое.
--
--  Требуется патч ядра (MAX_RACES=45 + реестр кастомных рас), иначе строки
--  playercreateinfo будут отброшены при загрузке:
--      "Wrong race 31 in `playercreateinfo` table, ignoring."
--
--  Скрипт идемпотентен (INSERT IGNORE / UPDATE / условный ALTER).
--  Откат: sql/52_custom_races_31_44_rollback.sql
-- =============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 0. Таблица соответствия кастомных рас базовым (донорам)
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `lf_race_31_44`;
CREATE TEMPORARY TABLE `lf_race_31_44` (
  `race` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `base` TINYINT UNSIGNED NOT NULL,
  `team` VARCHAR(10)      NOT NULL,
  `name` VARCHAR(64)      NOT NULL
) ENGINE = MEMORY;

INSERT INTO `lf_race_31_44` (`race`, `base`, `team`, `name`) VALUES
  (31,  8, 'HORDE',    'Zandalari Troll (race 31, Horde)'),
  (32,  1, 'ALLIANCE', 'Kul Tiran (race 32, Alliance)'),
  (33,  4, 'ALLIANCE', 'Custom race 33 (Alliance, donor: Night Elf)'),
  (34,  3, 'ALLIANCE', 'Dark Iron Dwarf (race 34, Alliance)'),
  (35,  9, 'HORDE',    'Vulpera (race 35, Horde)'),
  (36,  2, 'HORDE',    'Mag\'har Orc (race 36, Horde)'),
  (37,  7, 'ALLIANCE', 'Mechagnome (race 37, Alliance)'),
  (38,  8, 'HORDE',    'Custom race 38 (Horde, donor: Troll)'),
  (39, 10, 'HORDE',    'Custom race 39 (Horde, donor: Blood Elf)'),
  (40, 11, 'ALLIANCE', 'Custom race 40 (Alliance, donor: Draenei)'),
  (41, 22, 'ALLIANCE', 'Custom race 41 (Alliance, donor: Worgen)'),
  (42,  9, 'HORDE',    'Custom race 42 (Horde, donor: Goblin)'),
  (43, 24, 'NEUTRAL',  'Custom race 43 (Neutral, donor: Pandaren)'),
  (44, 27, 'HORDE',    'Custom race 44 (Horde, donor: Nightborne)');

-- ---------------------------------------------------------------------------
-- 1. racemask-колонки -> BIGINT UNSIGNED (иначе биты рас 33..44 теряются)
-- ---------------------------------------------------------------------------
SET @tbl := 'playercreateinfo_spell_custom';
SET @col := 'racemask';
SET @dt  := (SELECT DATA_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col);
SET @ddl := IF(@dt IS NULL, 'DO 0',
           IF(@dt = 'bigint', 'DO 0',
              CONCAT('ALTER TABLE `', @tbl, '` MODIFY `', @col, '` BIGINT UNSIGNED NOT NULL DEFAULT 0')));
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @tbl := 'playercreateinfo_cast_spell';
SET @col := 'raceMask';
SET @dt  := (SELECT DATA_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col);
SET @ddl := IF(@dt IS NULL, 'DO 0',
           IF(@dt = 'bigint', 'DO 0',
              CONCAT('ALTER TABLE `', @tbl, '` MODIFY `', @col, '` BIGINT UNSIGNED NOT NULL DEFAULT 0')));
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- [FIX 2026-01] Чистая база ADB_735.10 содержит `playercreateinfo_cast_spell`
-- только с колонками (raceMask, classMask, spell). Колонок `createMode` и `note`
-- там НЕТ, из-за чего патч падал:
--     ERROR 1054 (42S22) at line 115: Unknown column 'createMode' in 'field list'
-- Ядро читает только raceMask/classMask/spell (ObjectMgr.cpp:3505), поэтому
-- создаём недостающие колонки с безопасными значениями по умолчанию.
SET @tbl := 'playercreateinfo_cast_spell';
SET @col := 'createMode';
SET @ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col),
               'DO 0',
               'ALTER TABLE `playercreateinfo_cast_spell` ADD COLUMN `createMode` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `spell`');
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @tbl := 'playercreateinfo_cast_spell';
SET @col := 'note';
SET @ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col),
               'DO 0',
               'ALTER TABLE `playercreateinfo_cast_spell` ADD COLUMN `note` VARCHAR(255) NULL DEFAULT NULL AFTER `createMode`');
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- Гарантируем наличие таблиц, необходимых клонированию рас (в пустой базе их нет).
CREATE TABLE IF NOT EXISTS `player_levelstats` (
  `race` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `class` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `level` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `str` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '0',
  `agi` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '0',
  `sta` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '0',
  `inte` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`race`,`class`,`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `race_unlock_requirement` (
  `raceID` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `expansion` TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
  `achievementId` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`raceID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ---------------------------------------------------------------------------
-- 2. Стартовая позиция и классы (без этого PlayerInfo не создаётся и клиент
--    получает CHAR_CREATE_FAILED)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `playercreateinfo`
  (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
SELECT m.`race`, p.`class`, p.`map`, p.`zone`, p.`position_x`, p.`position_y`, p.`position_z`, p.`orientation`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo` p ON p.`race` = m.`base`;

-- Характеристики по уровням (клон расы-донора, чтобы не было "дыр" 2+ уровня)
INSERT IGNORE INTO `player_levelstats` (`race`, `class`, `level`, `str`, `agi`, `sta`, `inte`)
SELECT m.`race`, s.`class`, s.`level`, s.`str`, s.`agi`, s.`sta`, s.`inte`
  FROM `lf_race_31_44` m
  JOIN `player_levelstats` s ON s.`race` = m.`base`;

-- Стартовые предметы
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`)
SELECT m.`race`, i.`class`, i.`itemid`, i.`amount`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_item` i ON i.`race` = m.`base`;

-- Панель команд (hotbar)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
SELECT m.`race`, a.`class`, a.`button`, a.`action`, a.`type`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_action` a ON a.`race` = m.`base`;

-- ---------------------------------------------------------------------------
-- 3. Масочные таблицы: 64-битный сдвиг (CAST(1 AS UNSIGNED) = BIGINT UNSIGNED)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT (CAST(1 AS UNSIGNED) << (m.`race` - 1)), s.`classmask`, s.`Spell`,
       CONCAT(COALESCE(s.`Note`, ''), ' [LF custom race ', m.`name`, ']')
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_spell_custom` s ON s.`racemask` = (CAST(1 AS UNSIGNED) << (m.`base` - 1));

INSERT IGNORE INTO `playercreateinfo_cast_spell` (`raceMask`, `classMask`, `spell`, `createMode`, `note`)
SELECT (CAST(1 AS UNSIGNED) << (m.`race` - 1)), c.`classMask`, c.`spell`, c.`createMode`,
       CONCAT(COALESCE(c.`note`, ''), ' [LF custom race]')
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_cast_spell` c ON c.`raceMask` = (CAST(1 AS UNSIGNED) << (m.`base` - 1));

-- ---------------------------------------------------------------------------
-- 4. Разблокировка рас: expansion 6 (Legion). Значение 7 (BfA) приводило к
--    CHAR_CREATE_EXPANSION, а GetMaxLevelForExpansion(7) в этом ядре = 0.
-- ---------------------------------------------------------------------------
UPDATE `race_unlock_requirement`
   SET `expansion` = 6, `achievementId` = 0
 WHERE `raceID` BETWEEN 31 AND 44;

INSERT INTO `race_unlock_requirement` (`raceID`, `expansion`, `achievementId`)
SELECT m.`race`, 6, 0
  FROM `lf_race_31_44` m
 WHERE NOT EXISTS (SELECT 1 FROM `race_unlock_requirement` x WHERE x.`raceID` = m.`race`);

-- ---------------------------------------------------------------------------
-- 5. Контрольный вывод: сколько строк стартовых данных получила каждая раса.
--    createInfoRows = 0  =>  персонажа этой расы создать НЕЛЬЗЯ.
-- ---------------------------------------------------------------------------
SELECT m.`race`                                                        AS raceId,
       m.`name`                                                        AS raceName,
       m.`base`                                                        AS donorRace,
       m.`team`                                                        AS team,
       (SELECT COUNT(*) FROM `playercreateinfo`      p WHERE p.`race` = m.`race`) AS createInfoRows,
       (SELECT COUNT(*) FROM `player_levelstats`     s WHERE s.`race` = m.`race`) AS levelStatRows,
       (SELECT COUNT(*) FROM `playercreateinfo_item` i WHERE i.`race` = m.`race`) AS startItemRows,
       (SELECT COUNT(*) FROM `playercreateinfo_action` a WHERE a.`race` = m.`race`) AS actionBarRows,
       (SELECT COUNT(*) FROM `race_unlock_requirement` r WHERE r.`raceID` = m.`race`) AS unlockRows
  FROM `lf_race_31_44` m
 ORDER BY m.`race`;

DROP TEMPORARY TABLE IF EXISTS `lf_race_31_44`;

-- Готово. Перезапустите worldserver: расы 31..44 должны появиться в окне
-- создания и персонажи должны создаваться.
