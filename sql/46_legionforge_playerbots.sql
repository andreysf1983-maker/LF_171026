-- ==========================================================================
--   LEGIONFORGE 7.3.5 - игровая бот-система (PlayerBot)
--   Файл: sql/46_legionforge_playerbots.sql
--   Боты управляются ядром: core/src/server/game/PlayerBot и
--   core/src/server/game/AI/PlayerAI. Служебные таблицы aiwaypoints.
-- ==========================================================================
-- Файл сгенерирован автоматически: tools/legion_db2/generate_legionforge_content.py
-- Билд клиента: 26124. Изменяйте данные в генераторе, а не в этом файле.
-- Запросы идемпотентны, повторное применение безопасно.
-- ==========================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


-- --------------------------------------------------------------------------
-- 1. Точки патрулирования ботов
-- --------------------------------------------------------------------------

USE `world`;
CREATE TABLE IF NOT EXISTS `aiwaypoints` (
  `entry` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `map` INT UNSIGNED NOT NULL DEFAULT 0,
  `position_x` FLOAT NOT NULL DEFAULT 0,
  `position_y` FLOAT NOT NULL DEFAULT 0,
  `position_z` FLOAT NOT NULL DEFAULT 0,
  `link` TEXT,
  `comment` TEXT,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM `aiwaypoints` WHERE `comment` LIKE 'LEGIONFORGE%';
INSERT INTO `aiwaypoints` (`entry`,`map`,`position_x`,`position_y`,`position_z`,`link`,`comment`) VALUES
(1,1220,-828.8350,4371.9100,738.6360,'','LEGIONFORGE: Даларан, площадь'),
(2,1220,-824.0000,4366.0000,738.6000,'','LEGIONFORGE: Даларан, ряд вендоров'),
(3,1220,-819.0000,4361.0000,738.6000,'','LEGIONFORGE: Даларан, ряд вендоров'),
(4,1220,-814.0000,4356.0000,738.6000,'','LEGIONFORGE: Даларан, ряд вендоров'),
(5,0,-8833.0000,628.0000,94.0000,'','LEGIONFORGE: Штормград, торговая площадь'),
(6,0,-8949.9500,-132.4930,83.5312,'','LEGIONFORGE: Штормград, ворота'),
(7,1,1629.8500,-4373.5300,31.2564,'','LEGIONFORGE: Оргриммар, главные ворота'),
(8,1,1676.7100,-4318.6600,61.7729,'','LEGIONFORGE: Оргриммар, долина силы');

SET FOREIGN_KEY_CHECKS = 1;
