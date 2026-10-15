DELETE FROM `updates_include`;
INSERT INTO `updates_include` (`path`) VALUES ('$/sql/legionforge/characters'); 

DELETE FROM `updates` WHERE `timestamp` < "2017-11-01 00:00:00";
