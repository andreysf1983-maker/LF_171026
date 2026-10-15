# Scenario landings

Working list for teleporting in and out of scenario maps. A landing on this list is a coordinate already stored in the 7.3.5 data. Creature placement uses these spots to put a character in the room. The quest teleport uses the same spots as the way in.

When an NPC should send a player into a scenario, or through an instance door, and that teleport spell is missing, the NPC casts spell 84338, Teleport Player. Spells that already exist stay as they are. This includes the 38 destination spells below, Death Gate, and Zen Pilgrimage.

Spell 84338 is the generic teleport-player effect in this client. Its own stored destination is one spot on Kalimdor (map 1, -9210, -1564, 65.45). Cast by itself, every missing door would dump the player there. The script on 84338 saves where the player is standing, then aims the teleport at the landing for that scenario from this list. The return cast of the same kind of spell reads the saved spot and sends that player home. Each player keeps their own spot, including across logout while they are still inside. A missing spell with no landing on this list is not given 84338, because there is still nowhere to send them.

## The gap

A teleport has to aim at a spot that already exists.

- **22 maps already have a marked spot.** A spell destination says where to land. Those coordinates are the known way in.
- **26 more maps have a client area-trigger position.** That is a real spot on the floor, recorded as a marker, not as the quest door. It is a known place to stand while placing creatures.
- **89 maps have a floor file and no marked spot.** A square of that floor can be read later and added here. Until a square is chosen and written into this list, that map has no teleport-in location. The square may be the middle of the room or a back corner.
- **Moonglade (map 1534) has no floor file and no spell.** There is nowhere to send a player.

Named scenario maps: 138. Already filled with creatures, so they are not placement targets: Ashran 1191, Maw of Nashal 1475, Temple of Elune 1478.

## Placement

Empty scenarios are filled by standing in the room and recording that position. The program moves a character in world space onto one map at a time. The first step onto a map is a coordinate already stored: a spell destination, a finder landing, or an area trigger. Maps with none of those use one square read from the floor file under `server\data\maps`. The coordinate that gets written for a creature is the character's position at that moment. Moonglade (1534) has no floor file, so the program has nowhere to put the character.

The Dungeon Finder remains how a player enters and leaves the scenarios that have no quest giver. This program is for placing creatures, not a second player door.

## Known way in (spell destination)

These are the coordinates a quest teleport can use now. The spell ids are the trips that already exist. They are not a set of NPC door spells, and they are not replaced by the standard enter spell. Death Gate (200428) and Zen Pilgrimage (194004) are class spells. Several others summon a vehicle or a wave and only share a destination coordinate. One NPC casts one of them: Light's Heart (112952) spellclick 226373, Holding the Tears of Elune. New scenario doors cast the standard enter spell and read a coordinate from this table.

| Map | Scenario | Spell | X | Y | Z |
|-----|----------|-------|---|---|---|
| 1014 | Peak of Serenity | 194004 | 3819.2 | 1793.27 | 950.35 |
| 1460 | Broken Shore Scenario | 224983 | 995.29 | 1876.09 | 24.77 |
| 1460 | Broken Shore Scenario | 224997 | 1268.26 | 1720.33 | 19.27 |
| 1460 | Broken Shore Scenario | 225152 | 519.26 | 1880.1 | 10.99 |
| 1460 | Broken Shore Scenario | 227792 | 868.93 | 1845.58 | 53.91 |
| 1480 | Icecrown Citadel | 200428 | -737.07 | 2204.7 | 535.67 |
| 1489 | Niskara | 216680 | 344.36 | 1804.66 | -7.68 |
| 1494 | The Violet Hold | 188163 | 1293.19 | -262.72 | 44.36 |
| 1495 | Shield's Rest | 187803 | 4914 | -91.55 | 66.14 |
| 1498 | Felsoul Hold | 186709 | 753.85 | 4963.45 | 138.2 |
| 1498 | Felsoul Hold | 210920 | 1264.6 | 5234.68 | 93.53 |
| 1500 | Broken Shore | 195237 | -2337.97 | 209.65 | 57.53 |
| 1500 | Broken Shore | 197879 | -2710 | -1818 | 179 |
| 1500 | Broken Shore | 225107 | -2751.74 | -324.79 | 38.07 |
| 1503 | Deepholm | 196083 | 2458.65 | 65.83 | -155.58 |
| 1511 | Tideskorn Harbor | 193335 | 3380.29 | 1401.9 | 69.54 |
| 1529 | Karazhan | 223838 | 1706.52 | 2275.23 | 49.83 |
| 1572 | The Maelstrom | 193094 | 824.32 | 1094.25 | 57.72 |
| 1572 | The Maelstrom | 210079 | 383.42 | 1403.67 | 193 |
| 1579 | Ulduar | 210240 | 1501 | -24.4 | 421 |
| 1600 | Throne of the Tides | 207683 | -629.42 | 808.68 | 247.67 |
| 1600 | Throne of the Tides | 208560 | -214.32 | 808.81 | 262.09 |
| 1600 | Throne of the Tides | 209133 | -44.02 | 802.24 | 797.19 |
| 1600 | Throne of the Tides | 209155 | -47.92 | 794.45 | 797.37 |
| 1600 | Throne of the Tides | 209156 | -45.91 | 811.65 | 797.54 |
| 1621 | Black Temple - Legion | 214536 | 796.88 | 304.56 | 319.76 |
| 1621 | Black Temple - Legion | 215411 | 796.88 | 304.56 | 319.76 |
| 1624 | Battle of Exodar | 220513 | -4055.47 | -11958.3 | 0.68 |
| 1629 | Netherlight Temple | 202324 | 1249.25 | 1344.14 | 185 |
| 1629 | Netherlight Temple | 221513 | 1234.62 | 1344.22 | 185.02 |
| 1629 | Netherlight Temple | 222727 | 1244.42 | 1344.24 | 185.02 |
| 1646 | Black Rook Hold [Scenario] | 224191 | 3264.82 | 7287.42 | 90.77 |
| 1653 | Great Dark Beyond | 226373 | 766.77 | -266.45 | 0 |
| 1653 | Great Dark Beyond | 226374 | 766.82 | -266.43 | 13.86 |
| 1662 | Suramar | 229237 | 949.07 | 4166.23 | 1.42 |
| 1666 | The Assault on Broken Shore | 236671 | -1188.32 | 2953.37 | 153.63 |
| 1666 | The Assault on Broken Shore | 240603 | -1111.6 | 2969.71 | 186.02 |
| 1756 | The Deaths of Chromie | 243836 | 13705.1 | 13075.7 | 343.56 |

## Known place to stand (area trigger)

Maps with no spell destination. The first client area trigger on that map is the landing, stored in `scenario_map_landing`.

Spell 84338 sends a player there only when a row in `scenario_npc_landing` names the NPC and the quest. Accepting that quest saves where the player is standing, then lands them on the spot below. Casting 84338 again while standing on that map sends them back to the saved spot. Four spawned quest givers are wired: Gurgthock (63315) to Arena of Annihilation, General Nazgrim (67939) to Dagger in the Dark, Admiral Taylor (67940) to A Little Patience, and Master Li (73082) to the Celestial Tournament. The other maps in this table have a landing and no spawned quest giver, so no NPC casts the spell for them yet.

| Map | Scenario | Area trigger | X | Y | Z | Creatures already spawned |
|-----|----------|--------------|---|---|---|---------------------------|
| 999 | Theramore's Fall (H) | 7442 | -3815.4399414062 | -4792.75 | 10.75030040741 |  |
| 1000 | Theramore's Fall (A) | 8397 | -4023.080078125 | -4748.7998046875 | 5.21767997742 |  |
| 1024 | Greenstone Village | 7868 | 2045.9235839844 | -1980.0122070312 | 215.5076751709 |  |
| 1030 | Crypt of Forgotten Kings | 7908 | 767.56079101563 | 2317.5346679688 | 82.26484680176 |  |
| 1031 | Arena of Annihilation | 8151 | 3795.5737304688 | 533.58508300781 | 638.75720214844 |  |
| 1048 | Unga Ingoo | 8056 | -2943.3403320312 | 767.890625 | 4.7980093956 |  |
| 1050 | Assault on Zan'vess | 8654 | -1437.2517089844 | 3934.4323730469 | 6.50243902206 |  |
| 1051 | Brewmoon Festival | 8089 | 1736.4896240234 | 302.55902099609 | 475.88189697266 |  |
| 1095 | Dagger in the Dark | 8633 | 995.07464599609 | -115.14930725098 | 452.05438232422 |  |
| 1099 | Naval Battle Scenario | 8845 | 2347.0383300781 | -4138.3002929688 | 14.46571063995 |  |
| 1103 | Lion's Landing | 8753 | -1158.3385009766 | -1232.4982910156 | 29.38837432861 |  |
| 1104 | A Little Patience | 8622 | -1452.6927490234 | 1015.8316040039 | 32.05723953247 |  |
| 1112 | Pursuing the Black Harvest | 8696 | 703.72052001953 | 574.90106201172 | 112.62796020508 |  |
| 1126 | Mogu Island Progression Events | 8873 | 6512.2377929688 | 5767.4165039062 | 28.52132225037 |  |
| 1130 | Blood in the Snow | 9035 | -5251.283203125 | -426.66320800781 | 388.46197509766 |  |
| 1131 | The Secrets of Ragefire | 9016 | 1396.6110839844 | 802.46179199219 | 38.86668777466 |  |
| 1135 | Mogu Island Loot Room | 8961 | -451.49826049805 | 1082.4860839844 | 133.66056823731 |  |
| 1144 | Heart of the Old God Scenario | 9097 | 1126.140625 | 903.83679199219 | 404.10134887695 |  |
| 1157 | Halfhill Scenario | 9333 | -260.85415649414 | 586.80902099609 | 167.54777526856 |  |
| 1161 | Celestial Tournament | 9349 | -611.00518798828 | -4994.0209960938 | -6.27734184265 |  |
| 1191 | Ashran - World PvP | 10297 | 4247.8227539062 | -4192.9584960938 | 32.64757919312 | yes |
| 1277 | Defense of Karabor | 9979 | 786.86804199219 | -2368.9445800781 | 99.10975646973 |  |
| 1329 | Grommashar Scenario | 10151 | 1936.3559570312 | 5211.7231445312 | 183.73970031738 |  |
| 1374 | Auchindoun Quest | 10196 | 1483.6805419922 | 2953.0207519531 | 35.31089401245 |  |
| 1528 | Skywall | 10382 | -903.61114501953 | 645.53643798828 | 530.71813964844 |  |
| 1536 | Ursocs Lair | 10386 | -12501.951171875 | -13040.997070312 | 227.93449401856 |  |

## Floor present, landing not chosen

These maps have terrain files under `server/data/maps`. No spell and no area trigger gives a coordinate yet. Do not teleport players here until a square from the floor file is chosen and added to the known way in.

- 930 A Dark Place
- 1005 A Brewing Storm
- 1035 Temple of Kotmogu
- 1102 Domination Point
- 1122 City Siege - Mogu Island Progression Scenario
- 1123 Lightning Forge - Mogu Island Progression Scenario
- 1124 Shipyard - Mogu Island Progression Scenario
- 1125 Alliance Hub - Mogu Island Progression Scenario
- 1127 Final Gate - Mogu Island Progression Scenario
- 1148 Proving Grounds
- 1155 Stromgarde Keep
- 1168 The Purge Of Grommar - Scenario
- 1200 Bonetown Scenario
- 1203 Frostfire Finale Scenario
- 1207 The Battle for Shattrath
- 1266 Circle of Blood Scenario
- 1402 Gorgrond Finale
- 1431 The Coliseum
- 1453 Scourge of Northshire
- 1455 Edge of Reality
- 1461 Azsuna Scenario
- 1475 The Maw of Nashal (creatures already spawned)
- 1478 The Temple of Elune (creatures already spawned)
- 1522 Dreadscar Rift
- 1523 Defense of the Fel Hammer Scenario
- 1526 Temple of the White Tiger
- 1533 Karazhan Catacombs
- 1539 Tirisfal Glades
- 1541 Terrace of Endless Spring
- 1545 Azsuna
- 1553 Gloaming Reef
- 1580 The Maelstrom
- 1583 Nexus Vault
- 1599 Nordrassil
- 1607 Artifact - Acquisition - Subtlety
- 1609 Temple of Storms
- 1610 Artifact - Serenity Legion Scenario
- 1611 Death Knight Campaign - Light's Hope Chapel
- 1612 The Ruins of Falanaar
- 1616 Faronaar
- 1617 Death Knight Campaign - Undercity
- 1620 Artifact - Stormwind
- 1622 Telogrus Rift Scenario
- 1623 Mage Campaign - The Oculus
- 1625 Trial of the Serpent
- 1626 The Collapse - Suramar Scenario
- 1630 Tol Barad
- 1632 The Arcway - Suramar Scenario
- 1667 Legion Ship - Vertical
- 1668 Legion Ship - Horizontal
- 1673 The Eye of Eternity - Scenario
- 1683 Artifact - Gnomeregan
- 1684 Dread Scar Rift - Warlock Scenario Platform
- 1687 Wailing Caverns
- 1688 Deadmines
- 1689 The Eye of Eternity - Mage Class Mount
- 1693 Stormstout Brewery - Monk Scenario
- 1694 Gnomeregan
- 1695 Battleship: Ruin
- 1698 Artifact - Acquisition - Tank
- 1702 Artifact - Highmountain - Dual Boss
- 1703 Halls of Valor - Scenario
- 1704 Legion Ship - Horizontal - Valsharah
- 1705 Legion Ship - Horizontal - Azsuna
- 1706 Legion Ship - Vertical - HighMountain
- 1707 Legion Ship - Vertical - Stormheim
- 1708 Stratholme - Paladin Class Mount
- 1710 Black Rook Hold - Artifact Challenge
- 1714 Halls Of Valor - Warrior Class Mount
- 1719 Dread Scar Rift - Warlock Mount Scenario
- 1723 Coldridge Valley
- 1728 Halls of Valor
- 1729 The Eye of Eternity - Mage Class Mount (Shorter Version)
- 1730 Shrine of Aviana Defense - Scenario
- 1731 Druid Mount Finale - Scenario
- 1732 Felwing Ledge - Demon Hunter Class Mount
- 1733 Azeroth's Warning Scenario
- 1734 Throne of the Four Winds - Shaman Class Mount
- 1735 Frozen Wastes
- 1736 The Ruby Sanctum
- 1737 Pocket Dimension Akazamzaraks Hat Scenario
- 1738 The Lost Glacier
- 1744 Trial of Style
- 1746 Tempest Keep: The Arcatraz
- 1764 Endless Halls
- 1774 Forge of Aeons
- 1812 Suramar
- 1818 Silvermoon City
- 1840 The Sunwell

## No landing

- 1534 Moonglade. No floor file, no spell destination, no area trigger.

## Not on this list

Dungeon and raid quests do not teleport players into the instance. No quest reward spell targets a dungeon or raid map. Entrance is the portal or the Dungeon Finder. Teleport spells that do exist on those maps fire when a portal, gossip option, or script casts them.

