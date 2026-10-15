-- Legion 7.3.5 GM .tele destinations.
-- ADB often ships incomplete or invalid Legion rows (wrong Z, missing zones).
-- Safe to re-run: deletes by name, then inserts.

DELETE FROM `game_tele` WHERE `name` IN (
  'DalaranLegion','DalaranCity','Azsuna','ValSharah','Val''Sharah',
  'Highmountain','Stormheim','Suramar','BrokenShore','EyeAzshara',
  'Mardum','ArgusKrokuun','ArgusMacaree','ArgusAntoran',
  'HallWarlock','HallDemon','HallShaman','HallDruid','HallHunter',
  'HallPaladin','HallRogue','HallDK','HallWarrior','HallMonk','HallMage',
  'Antorus'
);

INSERT INTO `game_tele` (`position_x`,`position_y`,`position_z`,`orientation`,`map`,`name`) VALUES
(-828.835, 4371.91, 738.636, 1.88158, 1220, 'DalaranLegion'),
(-828.835, 4371.91, 738.636, 1.88158, 1220, 'DalaranCity'),
(-218.95, 5600.9, 61.1105, 3.32418, 1220, 'Azsuna'),
(2795.81, 7279.47, 21.6704, 4.75753, 1220, 'ValSharah'),
(4492.69, 4836.35, 661.706, 1.37009, 1220, 'Highmountain'),
(3854.78, 2020.04, 242.638, 3.2904, 1220, 'Stormheim'),
(1708.83, 4637.75, 124.004, 5.25153, 1220, 'Suramar'),
(-1306.66, 1741.4, 7.32331, 0.09146, 1220, 'BrokenShore'),
(-3400, 4827.46, 27.829, 3.56, 1220, 'EyeAzshara'),
(1182.7, 3282.56, 69.99, 0.08, 1481, 'Mardum'),
(1467.16, 1448.15, 491.008, 0.0, 1669, 'ArgusKrokuun'),
(5467.5, 10012.3, -78.5, 0.0, 1669, 'ArgusMacaree'),
(-2616.8, 8833.4, -67.3, 0.0, 1669, 'ArgusAntoran'),
(3094.91, 1062.63, 242.58, 4.91188, 1107, 'HallWarlock'),
(1561.02, 1399.94, 237.108, 1.69284, 1519, 'HallDemon'),
(1126.24, 1069.48, 3.55888, 6.11568, 1469, 'HallShaman'),
(4113.75, 7459.81, 48.2315, 0.907679, 1220, 'HallDruid'),
(4529.88, 5246.98, 862.193, 3.05573, 1220, 'HallHunter'),
(2373.48, -5356.95, 52.5833, 2.45032, 0, 'HallPaladin'),
(-927.239, 4501.06, 700.75, 3.98971, 1220, 'HallRogue'),
(-1502.45, 1060.68, 260.416, 4.14701, 1220, 'HallDK'),
(1028.47, 7225.17, 100.181, 1.53734, 1479, 'HallWarrior'),
(885.306, 3605.37, 192.23, 6.26366, 1514, 'HallMonk'),
(-844, 4759, 918, 0.586009, 1513, 'HallMage'),
(2866.45, -4567.44, 291.949, 0.0926814, 1712, 'Antorus');

-- Correct the known bad HallRogue Z if an older row survived under another name
UPDATE `game_tele` SET `position_z` = 700.75 WHERE `name` = 'HallRogue' AND `position_z` > 1000;
