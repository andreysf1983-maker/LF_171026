-- LegionForge targets client 7.3.5.26124 only. The original update moved the realm to 26365,
-- which made the 26124 client show the realm as "Incompatible". Keep the realm on 26124.
UPDATE `realmlist` SET `gamebuild`=26124 WHERE `gamebuild`=26365;

ALTER TABLE `realmlist` CHANGE `gamebuild` `gamebuild` int(10) unsigned NOT NULL DEFAULT '26124';
