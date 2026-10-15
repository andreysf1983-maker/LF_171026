-- Boss credit for encounters whose creature name is the boss name plus a title,
-- or whose creature_template carries the single boss script for that name.
-- Council fights and developer dummy encounters are listed below and are not given a kill credit.

INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`)
SELECT * FROM (
  SELECT 793 AS entry, 0 AS creditType, 14834 AS creditEntry, 0 AS lastEncounterDungeon, 'Hakkar' AS comment
  UNION ALL SELECT 1299, 0, 56173, 0, 'Madness of Deathwing'
  UNION ALL SELECT 1414, 0, 59479, 0, 'Yan-Zhu the Uncasked'
  UNION ALL SELECT 1447, 0, 61485, 0, 'General Pa''valak'
  UNION ALL SELECT 1463, 0, 62164, 0, 'Garalon'
  UNION ALL SELECT 1464, 0, 62205, 0, 'Wing Leader Ner''onok'
  UNION ALL SELECT 1498, 0, 62397, 0, 'Wind Lord Mel''jarak'
  UNION ALL SELECT 1499, 0, 62511, 0, 'Amber-Shaper Un''sok'
  UNION ALL SELECT 1571, 0, 69099, 0, 'Nalak'
  UNION ALL SELECT 1660, 0, 75247, 0, 'Groyat, the Blind Hunter'
  UNION ALL SELECT 1661, 0, 4421, 0, 'Chalgra Razorflank'
  UNION ALL SELECT 1664, 0, 74435, 0, 'Mushlump'
  UNION ALL SELECT 1665, 0, 74875, 0, 'Death Speaker Blackthorn'
  UNION ALL SELECT 1668, 0, 74476, 0, 'Domina'
  UNION ALL SELECT 1669, 0, 74565, 0, 'Subjugator Kor''ul'
  UNION ALL SELECT 1670, 0, 74988, 0, 'Executioner Gore'
  UNION ALL SELECT 1671, 0, 74728, 0, 'Twilight Lord Bathiel'
  UNION ALL SELECT 1675, 0, 74505, 0, 'Thruk'
  UNION ALL SELECT 1676, 0, 74508, 0, 'Guardian of the Deep'
  UNION ALL SELECT 1678, 0, 86219, 0, 'Azzakel, Vanguard of the Legion'
  UNION ALL SELECT 1682, 0, 76407, 0, 'Ner''zhul'
  UNION ALL SELECT 1696, 0, 77182, 0, 'Oregorger the Devourer'
  UNION ALL SELECT 1713, 0, 77692, 0, 'Kromog, Legend of the Mountain'
  UNION ALL SELECT 1721, 0, 78714, 0, 'Kargath Bladefist'
  UNION ALL SELECT 1722, 0, 78948, 0, 'Tectus, The Living Mountain'
  UNION ALL SELECT 1754, 0, 83612, 0, 'Skulloc, Son of Gruul'
  UNION ALL SELECT 1755, 0, 83746, 0, 'Rukhmar, Sun-God of the Arakkoa'
  UNION ALL SELECT 1756, 0, 83846, 0, 'Yalnu'
  UNION ALL SELECT 1864, 0, 103769, 0, 'Xavius'
  UNION ALL SELECT 1870, 0, 104218, 0, 'Advisor Melandrus'
  UNION ALL SELECT 1873, 0, 105393, 0, 'Il''gynoth, The Heart of Corruption'
  UNION ALL SELECT 1876, 0, 106087, 0, 'Elerethe Renferal'
  UNION ALL SELECT 1877, 0, 104636, 0, 'Cenarius'
  UNION ALL SELECT 1888, 0, 108678, 0, 'Shar''thos'
  UNION ALL SELECT 1909, 0, 18667, 0, 'Blackheart the Inciter'
  UNION ALL SELECT 1914, 0, 20912, 0, 'Harbinger Skyriss'
  UNION ALL SELECT 1917, 0, 108879, 0, 'Humongris'
  UNION ALL SELECT 1919, 0, 17881, 0, 'Aeonus'
  UNION ALL SELECT 1920, 0, 17879, 0, 'Chrono Lord Deja'
  UNION ALL SELECT 1921, 0, 17880, 0, 'Temporus'
  UNION ALL SELECT 1949, 0, 110378, 0, 'Drugon the Frostblood'
  UNION ALL SELECT 1950, 0, 110321, 0, 'Na''zak the Fiend'
  UNION ALL SELECT 1951, 0, 99929, 0, 'Flotsam'
  UNION ALL SELECT 1952, 0, 109331, 0, 'Calamir'
  UNION ALL SELECT 1953, 0, 108829, 0, 'Levantus'
  UNION ALL SELECT 1995, 0, 28234, 0, 'Tribunal of Ages'
  UNION ALL SELECT 2000, 0, 36658, 0, 'Scourgelord Tyrannus'
  UNION ALL SELECT 2002, 0, 26529, 0, 'Meathook'
  UNION ALL SELECT 2003, 0, 26532, 0, 'Chrono-Lord Epoch'
  UNION ALL SELECT 2004, 0, 26530, 0, 'Salram the Fleshcrafter'
  UNION ALL SELECT 2010, 0, 26731, 0, 'Grand Magus Telestra'
  UNION ALL SELECT 2021, 0, 35451, 0, 'The Black Knight'
  UNION ALL SELECT 2025, 0, 23954, 0, 'Ingvar the Plunderer'
  UNION ALL SELECT 2037, 0, 115767, 0, 'Mistress Sassz''ine'
  UNION ALL SELECT 2051, 0, 117269, 0, 'Kil''jaeden'
) AS proposed
WHERE NOT EXISTS (SELECT 1 FROM `instance_encounters` existing WHERE existing.entry = proposed.entry);

-- Council or multi-boss encounters. One kill is not the whole encounter:
-- 1086 map 649 Faction Champions
-- 1121 map 533 The Four Horsemen
-- 1395 map 1008 The Stone Guard
-- 1407 map 1008 Will of the Emperor
-- 1436 map 1008 The Spirit Kings
-- 1442 map 994 Trial of the King
-- 1695 map 1205 The Iron Maidens
-- 1719 map 1228 Twin Ogron
-- 1748 map 1195 Grimrail Enforcers
-- 1757 map 1279 Ancient Protectors
-- 1854 map 1520 Dragons of Nightmare
-- 1879 map 1220 The Soultakers
-- 2022 map 650 Grand Champions
-- 2024 map 574 Skarvold & Dalronn
-- 1693 map 1205 Hans'gar & Franzok
-- 2048 map 1676 Demonic Inquisition
-- 2050 map 1676 Sisters of the Moon
-- Developer placeholder encounters:
-- 1874 map 1457 Raid Boss Dummy (5min)
-- 1875 map 1457 Raid Boss Dummy (10min)
-- 1918 map 1148 Timed Damage Dummy
-- No single creature:
-- 1662 map 129 Aaurx candidates []
-- 1685 map 1182 Soulbinder Nyami candidates [(76177, 'Soulbinder Nyami', 1), (77810, 'Soulbinder Nyami', 1)]
-- 1690 map 1205 Blast Furnace candidates []
-- 1745 map 1191 Ashran candidates []
-- 1747 map 605 Ken's Test Encounter [DNT] candidates []
-- 1749 map 1195 Fleshrender Nok'gar candidates [(81305, "Fleshrender Nok'gar", 3), (87451, "Fleshrender Nok'gar", 3)]
-- 1856 map 1544 Fel Lord Betrug candidates [(102446, 'Fel Lord Betrug', 1), (102891, 'Fel Lord Betrug', 1), (106373, 'Fel Lord Betrug', 1)]
-- 1990 map 668 Escaped from Arthas candidates []
-- 2018 map 608 Second Prisoner candidates []
-- 2019 map 608 First Prisoner candidates []
-- 2023 map 650 Argent Champion candidates [(30188, 'Argent Champion', 1), (30675, 'Argent Champion', 1), (37928, 'Argent Champion', 1)]
-- 2049 map 1689 Primal Rage of Frost candidates [(116672, 'Primal Rage of Frost', 0), (119300, 'Primal Rage of Frost', 0)]
-- 2059 map 1703 Fury of the God Queen candidates []
-- 2079 map 1669 Keeper Aedis candidates []
-- 2080 map 1669 Void-Blade Zedaat candidates [(123761, 'Void-Blade Zedaat', 0), (127911, 'Void-Blade Zedaat', 0)]
-- 2081 map 1669 Imp Mother candidates [(98497, 'Imp Mother', 0), (98621, 'Imp Mother', 0), (118648, 'Imp Mother', 1), (120943, 'Imp Mother', 1)]
-- 2083 map 1669 Mistress Alluradel: the only template with that name is level 1, so it is not the boss.
