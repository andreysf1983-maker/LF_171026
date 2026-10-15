-- Undo 003_instance_journal_shells.sql. Clears the script only when it is still
-- the name that patch wrote.

UPDATE `instance_template` SET `script` = '' WHERE `map` = 1001 AND `script` = 'instance_scarlet_halls';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1004 AND `script` = 'instance_scarlet_monastery_mop';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1007 AND `script` = 'instance_scholomance_mop';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 996 AND `script` = 'instance_terrace_of_endless_spring';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1009 AND `script` = 'instance_heart_of_fear';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1098 AND `script` = 'instance_throne_of_thunder';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1136 AND `script` = 'instance_siege_of_orgrimmar';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1182 AND `script` = 'instance_auchindoun';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1208 AND `script` = 'instance_grimrail_depot';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1195 AND `script` = 'instance_iron_docks';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1209 AND `script` = 'instance_skyreach';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1358 AND `script` = 'instance_upper_blackrock_spire';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1228 AND `script` = 'instance_highmaul';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1205 AND `script` = 'instance_blackrock_foundry';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1448 AND `script` = 'instance_hellfire_citadel';
