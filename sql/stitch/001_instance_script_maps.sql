-- Point instance scripts at the map the C++ script was compiled for.
-- instance_zulgurub is written for Zul'Gurub (859). Ancient Zul'Gurub (309) was also
-- named with that script, so the old map ran the Cataclysm encounter script.
-- instance_scarlet_monastery is written for Scarlet Monastery of Old (189).
-- Scarlet Monastery (1004) was also named with that script.
-- 859 and 189 already have the correct script names. This only clears the extras.

UPDATE `instance_template` SET `script` = '' WHERE `map` = 309 AND `script` = 'instance_zulgurub';
UPDATE `instance_template` SET `script` = '' WHERE `map` = 1004 AND `script` = 'instance_scarlet_monastery';
