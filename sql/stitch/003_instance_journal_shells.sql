-- Fill blank instance_template.script values for MoP and WoD dungeons and raids.
-- The names match instance_journal_shells.cpp. A row that already has a script
-- is left alone. This does not insert creature spawns.

UPDATE `instance_template` SET `script` = 'instance_scarlet_halls' WHERE `map` = 1001 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_scarlet_monastery_mop' WHERE `map` = 1004 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_scholomance_mop' WHERE `map` = 1007 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_terrace_of_endless_spring' WHERE `map` = 996 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_heart_of_fear' WHERE `map` = 1009 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_throne_of_thunder' WHERE `map` = 1098 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_siege_of_orgrimmar' WHERE `map` = 1136 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_auchindoun' WHERE `map` = 1182 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_grimrail_depot' WHERE `map` = 1208 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_iron_docks' WHERE `map` = 1195 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_skyreach' WHERE `map` = 1209 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_upper_blackrock_spire' WHERE `map` = 1358 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_highmaul' WHERE `map` = 1228 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_blackrock_foundry' WHERE `map` = 1205 AND (`script` IS NULL OR `script` = '');
UPDATE `instance_template` SET `script` = 'instance_hellfire_citadel' WHERE `map` = 1448 AND (`script` IS NULL OR `script` = '');
