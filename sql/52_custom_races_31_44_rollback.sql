-- =============================================================================
--  LEGIONFORGE 7.3.5 - ОТКАТ sql/52_custom_races_31_44.sql
--  Удаляет стартовые данные и разблокировку кастомных рас 31..44.
--  Типы racemask-колонок НЕ откатываются (BIGINT обратно совместим с INT).
-- =============================================================================
SET NAMES utf8mb4;

DELETE FROM `playercreateinfo`            WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `player_levelstats`           WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_item`       WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_action`     WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` >= (CAST(1 AS UNSIGNED) << 30);
DELETE FROM `playercreateinfo_cast_spell`   WHERE `raceMask` >= (CAST(1 AS UNSIGNED) << 30);
DELETE FROM `race_unlock_requirement`     WHERE `raceID` BETWEEN 31 AND 44;

SELECT 'custom races 31-44 removed' AS result;
