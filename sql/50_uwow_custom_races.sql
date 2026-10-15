-- ==========================================================================
--   LEGIONFORGE 7.3.5 - поддержка КАСТОМНЫХ РАС клиента (UWoW и аналоги)
--   Файл: sql/50_uwow_custom_races.sql      База: world     (идемпотентен)
--
--   ЗАЧЕМ. Клиент UWoW 7.3.5 (26124) содержит расы более новых дополнений:
--     31 Зандалары, 32 Кул-тирасцы, 34 Дворфы Чёрного Железа,
--     35 Вульперы, 36 Маг'хары, 37 Механогномы
--   (расы 27-30 Legion включаются отдельно - sql/48_legion_allied_races.sql).
--
--   Ядро само по себе о них ничего не знает: в world-базе для них нет ни
--   стартовых позиций (playercreateinfo), ни статистики (player_levelstats),
--   ни стартовых предметов. Результат - "Level 1 does not have stats data!"
--   и падение worldserver либо невозможность создать персонажа.
--
--   РЕШЕНИЕ. Клонируем все стартовые данные от базовой расы-донора:
--     31 <- 8  (тролль),      32 <- 1  (человек),  34 <- 3  (дворф),
--     35 <- 8  (тролль),      36 <- 2  (орк),      37 <- 7  (гном)
--   Донор подобран по фракции и анимациям, стартовая локация остаётся
--   классической - это гарантированно рабочая конфигурация.
--
--   ВАЖНО (вторая половина включения): в клиенте раса должна быть открыта,
--   а ядро обязано пропустить проверку дополнения:
--     race_unlock_requirement.expansion = 6 (Legion)  - делается ниже;
--     CharacterHandler.cpp: IsAlliedRacesCreationAllowed >= EXPANSION_LEGION.
--   См. docs/CUSTOM_CLIENT_UWOW.md.
--
--   Откат: sql/50_uwow_custom_races_rollback.sql
-- ==========================================================================

SET NAMES utf8mb4;

DROP TEMPORARY TABLE IF EXISTS `lf_custom_race_map`;
CREATE TEMPORARY TABLE `lf_custom_race_map` (
  `race` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `base` TINYINT UNSIGNED NOT NULL,
  `name` VARCHAR(32) NOT NULL
) ENGINE=MEMORY;

INSERT INTO `lf_custom_race_map` (`race`, `base`, `name`) VALUES
  (31, 8, 'Zandalari Troll'),
  (32, 1, 'Kul Tiran'),
  (34, 3, 'Dark Iron Dwarf'),
  (35, 8, 'Vulpera'),
  (36, 2, "Mag'har Orc"),
  (37, 7, 'Mechagnome');

-- ---------- 1. Стартовые позиции ----------
INSERT IGNORE INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
SELECT m.`race`, p.`class`, p.`map`, p.`zone`, p.`position_x`, p.`position_y`, p.`position_z`, p.`orientation`
  FROM `lf_custom_race_map` m
  JOIN `playercreateinfo` p ON p.`race` = m.`base`;

-- ---------- 2. Уровневая статистика (без неё worldserver падает) ----------
INSERT IGNORE INTO `player_levelstats` (`race`, `class`, `level`, `str`, `agi`, `sta`, `inte`)
SELECT m.`race`, s.`class`, s.`level`, s.`str`, s.`agi`, s.`sta`, s.`inte`
  FROM `lf_custom_race_map` m
  JOIN `player_levelstats` s ON s.`race` = m.`base`;

-- ---------- 3. Стартовые предметы, заклинания, панель команд ----------
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`)
SELECT m.`race`, i.`class`, i.`itemid`, i.`amount`
  FROM `lf_custom_race_map` m
  JOIN `playercreateinfo_item` i ON i.`race` = m.`base`;

INSERT IGNORE INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT (1 << (m.`race` - 1)), s.`classmask`, s.`Spell`, CONCAT(COALESCE(s.`Note`, ''), ' [LF custom race ', m.`name`, ']')
  FROM `lf_custom_race_map` m
  JOIN `playercreateinfo_spell_custom` s ON s.`racemask` = (1 << (m.`base` - 1));

INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
SELECT m.`race`, a.`class`, a.`button`, a.`action`, a.`type`
  FROM `lf_custom_race_map` m
  JOIN `playercreateinfo_action` a ON a.`race` = m.`base`;

-- [FIX 2026-01] В чистой базе ADB_735.10 у `playercreateinfo_cast_spell` нет
-- колонок `createMode` / `note`. Создаём их при отсутствии, иначе
-- ERROR 1054 (42S22): Unknown column 'createMode' in 'field list'.
SET @lf_tbl := 'playercreateinfo_cast_spell';
SET @lf_col := 'createMode';
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @lf_tbl AND COLUMN_NAME = @lf_col),
                  'DO 0',
                  'ALTER TABLE `playercreateinfo_cast_spell` ADD COLUMN `createMode` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `spell`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_tbl := 'playercreateinfo_cast_spell';
SET @lf_col := 'note';
SET @lf_ddl := IF(EXISTS (SELECT 1 FROM information_schema.COLUMNS
                           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @lf_tbl AND COLUMN_NAME = @lf_col),
                  'DO 0',
                  'ALTER TABLE `playercreateinfo_cast_spell` ADD COLUMN `note` VARCHAR(255) NULL DEFAULT NULL AFTER `createMode`');
PREPARE lf_stmt FROM @lf_ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

INSERT IGNORE INTO `playercreateinfo_cast_spell` (`raceMask`, `classMask`, `spell`, `createMode`, `note`)
SELECT (1 << (m.`race` - 1)), c.`classMask`, c.`spell`, c.`createMode`, CONCAT(COALESCE(c.`note`, ''), ' [LF custom race]')
  FROM `lf_custom_race_map` m
  JOIN `playercreateinfo_cast_spell` c ON c.`raceMask` = (1 << (m.`base` - 1));

-- ---------- 4. Снятие гейта дополнения ----------
UPDATE `race_unlock_requirement`
   SET `expansion` = 6, `achievementId` = 0
 WHERE `raceID` IN (31, 32, 34, 35, 36, 37) AND `expansion` <> 6;

INSERT INTO `race_unlock_requirement` (`raceID`, `expansion`, `achievementId`)
SELECT m.`race`, 6, 0
  FROM `lf_custom_race_map` m
 WHERE NOT EXISTS (SELECT 1 FROM `race_unlock_requirement` x WHERE x.`raceID` = m.`race`);

-- ---------- 5. Контрольный вывод ----------
SELECT m.`race` AS raceId, m.`name` AS raceName, m.`base` AS baseRace,
       (SELECT COUNT(*) FROM `playercreateinfo` p WHERE p.`race` = m.`race`) AS createInfoRows,
       (SELECT COUNT(*) FROM `player_levelstats` s WHERE s.`race` = m.`race`) AS levelStatRows,
       (SELECT COUNT(*) FROM `playercreateinfo_item` i WHERE i.`race` = m.`race`) AS startItemRows
  FROM `lf_custom_race_map` m
 ORDER BY m.`race`;

DROP TEMPORARY TABLE IF EXISTS `lf_custom_race_map`;
