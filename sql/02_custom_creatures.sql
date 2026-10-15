-- gameobject.isActive column (required by this core build; skip if already present)
SET @stmt = IF(
  EXISTS(SELECT 1 FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'gameobject'
           AND COLUMN_NAME = 'isActive'),
  'SELECT 1',
  'ALTER TABLE `gameobject` ADD COLUMN `isActive` TINYINT(1) NOT NULL DEFAULT 0 AFTER `state`'
);
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;
