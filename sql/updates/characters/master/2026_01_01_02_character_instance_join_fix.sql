-- =============================================================================
-- LEGIONFORGE 7.3.5 (build 26124) - исправление ambiguous column при старте.
-- База: characters
--
-- Причина: предыдущая версия 2026_01_01_00_characters_schema_sync.sql ошибочно
-- добавляла resettime и entranceId в character_instance. Оба поля уже принадлежат
-- таблице instance, присоединяемой запросом ядра:
--   SELECT ... resettime, entranceId
--     FROM character_instance LEFT JOIN instance ON instance = id
-- MySQL 1052: Column 'resettime' in field list is ambiguous.
--
-- Удаляем только две ошибочно добавленные колонки из character_instance.
-- Правильные значения остаются в instance.resettime / instance.entranceId.
-- Повторный запуск безопасен; остальные данные персонажей не затрагиваются.
-- =============================================================================

SET @lf_ddl := IF(EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'character_instance'
       AND COLUMN_NAME = 'resettime'
),
'ALTER TABLE `character_instance` DROP COLUMN `resettime`',
'DO 0');
PREPARE lf_stmt FROM @lf_ddl;
EXECUTE lf_stmt;
DEALLOCATE PREPARE lf_stmt;

SET @lf_ddl := IF(EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'character_instance'
       AND COLUMN_NAME = 'entranceId'
),
'ALTER TABLE `character_instance` DROP COLUMN `entranceId`',
'DO 0');
PREPARE lf_stmt FROM @lf_ddl;
EXECUTE lf_stmt;
DEALLOCATE PREPARE lf_stmt;

-- Контроль: должно вернуть 0.
SELECT COUNT(*) AS erroneous_character_instance_columns_remaining
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME = 'character_instance'
   AND COLUMN_NAME IN ('resettime', 'entranceId');
