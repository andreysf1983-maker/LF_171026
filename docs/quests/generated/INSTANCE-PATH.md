# Instance path

Read-only. Client files plus the world database plus compiled script names. Nothing was written to the server.

Client instance maps: 326. Server instance_template rows: 161. Compiled instance script names: 108.

These are separate breaks. A fix for one pattern does not repair the others. Inside a single pattern, the same kind of edit repeats, but each dungeon still has its own map, script name, and bosses.

## Missing instance template (177)

The client says this map is a dungeon, raid, or scenario, and the server has no instance_template row.

- 605 Development Land (non-weighted textures) (raid)
- 627 Unused (DELETE ME) (scenario)
- 637 Abyssal Maw Exterior (dungeon)
- 721 Firelands Terrain 2 (dungeon)
- 734 Ahn'Qiraj Terrace (dungeon)
- 930 A Dark Place (scenario)
- 951 Nexus Legendary (dungeon)
- 977 Maelstrom Deathwing Fight (dungeon)
- 995 The Depths [UNUSED] (dungeon)
- 999 Theramore's Fall (H) (scenario)
- 1005 A Brewing Storm (scenario)
- 1014 Peak of Serenity (scenario)
- 1024 Greenstone Village (scenario)
- 1028 (UNUSED) Scenario: Mogu Ruins (scenario)
- 1029 (UNUSED) Scenario: Mogu Crypt (scenario)
- 1030 Crypt of Forgotten Kings (scenario)
- 1031 Arena of Annihilation (scenario)
- 1032 Pet Battle - Jade Forest (dungeon)
- 1035 Temple of Kotmogu (scenario)
- 1048 Unga Ingoo (scenario)
- 1049 (UNUSED) Scenario: Black Ox Temple (scenario)
- 1050 Assault on Zan'vess (scenario)
- 1051 Brewmoon Festival (scenario)
- 1095 Dagger in the Dark (scenario)
- 1099 Naval Battle Scenario (scenario)
- 1102 Domination Point (scenario)
- 1103 Lion's Landing (scenario)
- 1104 A Little Patience (scenario)
- 1112 Pursuing the Black Harvest (scenario)
- 1122 City Siege - Mogu Island Progression Scenario (scenario)
- 1123 Lightning Forge - Mogu Island Progression Scenario (scenario)
- 1124 Shipyard - Mogu Island Progression Scenario (scenario)
- 1125 Alliance Hub - Mogu Island Progression Scenario (scenario)
- 1126 Mogu Island Progression Events (scenario)
- 1127 Final Gate - Mogu Island Progression Scenario (scenario)
- 1130 Blood in the Snow (scenario)
- 1131 The Secrets of Ragefire (scenario)
- 1135 Mogu Island Loot Room (scenario)
- 1144 Heart of the Old God Scenario (scenario)
- 1148 Proving Grounds (scenario)
- … 137 more

## Template points at a bad map or parent (1)

instance_template names a map or parent the client Map list does not have, or the map is not an instance.

- map 1462 Illidans Rock InstanceType 0

## Instance has no script name (41)

The template row exists and the script column is blank. Doors, bosses, and lockouts for that map have no script to run.

- 30 Alterac Valley
- 44 <unused> Monastery
- 169 Emerald Dream
- 489 Warsong Gulch
- 529 Arathi Basin
- 559 Nagrand Arena (old)
- 562 zzOldBlade's Edge Arena
- 566 Eye of the Storm
- 572 Ruins of Lordaeron
- 598 Sunwell Fix (Unused)
- 607 Strand of the Ancients
- 617 Dalaran Sewers
- 618 The Ring of Valor
- 628 Isle of Conquest
- 996 Terrace of Endless Spring
- 1000 Theramore's Fall (A)
- 1001 Scarlet Halls
- 1007 Scholomance
- 1009 Heart of Fear
- 1098 Throne of Thunder
- 1136 Siege of Orgrimmar
- 1152 FW Horde Garrison Level 1
- 1153 FW Horde Garrison Level 3
- 1158 SMV Alliance Garrison Level 1
- 1159 SMV Alliance Garrison Level 3
- 1182 Auchindoun
- 1195 Iron Docks
- 1205 Blackrock Foundry
- 1208 Grimrail Depot
- 1209 Skyreach
- 1228 Highmaul
- 1277 Defense of Karabor
- 1330 FW Horde Garrison Level 2
- 1331 SMV Alliance Garrison Level 2
- 1358 Upper Blackrock Spire
- 1448 Hellfire Citadel
- 1462 Illidans Rock
- 1475 The Maw of Nashal
- 1498 Felsoul Hold
- 1533 Karazhan Catacombs
- … 1 more

## Script name has no C++ script (12)

The database names a script the core never registers. This is the mogu'shan vault pattern. Each name is a different script, so one new file does not cover the list.

- 1008 Mogu'shan Vaults script instance_mogu_shan_vault
- 1466 Darkheart Thicket script instance_darkheart_thicket
- 1477 Halls of Valor script instance_halls_of_valor
- 1501 Black Rook Hold script instance_black_rook_hold
- 1516 The Arcway script instance_the_arcway
- 1520 The Emerald Nightmare script instance_emerald_nightmare
- 1530 The Nighthold script instance_the_nighthold
- 1648 Trial of Valor script instance_trial_of_valor
- 1651 Return to Karazhan script instance_return_to_karazhan
- 1677 Cathedral of Eternal Night script instance_cathedral_of_eternal_night
- 1712 Antorus, the Burning Throne script instance_antorus_the_burning_throne
- 1753 Seat of the Triumvirate script instance_seat_of_triumvirate

## Script is compiled for a different map (2)

The name exists in C++, and the map id in that file is not the database map.

- instance_zulgurub db map 309, C++ map 859 (instance_zulgurub.cpp)
- instance_scarlet_monastery db map 1004, C++ map 189 (instance_scarlet_monastery.cpp)

## LFG row is not a client dungeon (0)

lfg_dungeon_template.dungeonId is not in LFGDungeons. The server logs this as coordinates for the wrong dungeon.


## LFG dungeon has no entrance (0)

The server row has position 0,0,0 and no areatrigger teleport lands on that map.


## Client LFG dungeon with no server entrance (0)

The client dungeon is not in lfg_dungeon_template and nothing teleports onto its map.


## Teleport trigger is not in the client (0)

areatrigger_teleport.ID is not in AreaTrigger. The client cannot fire that entrance.


## Teleport destination is not in WorldSafeLocs (1)

PortLocID is not in the client safe-location list, so the teleport has nowhere to send the player.

- trigger -22 port 0

## Access requirement is wrong (0)

The key, quest, map, or difficulty on access_requirement does not exist. The server drops that requirement at startup.


## Encounter row does not match the client (0)

instance_encounters.entry is not a client DungeonEncounter, the final-dungeon id is wrong, or two rows claim the same final boss.


## Encounter credit does not exist (0)

The kill creature is not in creature_template, or the credit spell is not in the client spell list.


## Encounter creature has no static spawn on its map (35)

The creature exists, and no creature row stands on the encounter map. Some of these are summoned by a script. An instance whose script is also missing cannot summon them either.

- encounter 250 Yor creature 22930 not spawned on map 557
- encounter 271 Urok Doomhowl creature 10584 not spawned on map 229
- encounter 484 Lord Aurius Rivendare creature 10440 not spawned on map 329
- encounter 606 Reliquary of Souls creature 23420 not spawned on map 564
- encounter 617 Nefarian creature 11583 not spawned on map 469
- encounter 618 Rage Winterchill creature 17767 not spawned on map 534
- encounter 619 Anetheron creature 17808 not spawned on map 534
- encounter 620 Kaz'rogal creature 17888 not spawned on map 534
- encounter 621 Azgalor creature 17842 not spawned on map 534
- encounter 652 Attumen the Huntsman creature 15550 not spawned on map 532
- encounter 672 Ragnaros creature 11502 not spawned on map 409
- encounter 726 Felmyst creature 25038 not spawned on map 580
- encounter 784 High Priest Venoxis creature 14507 not spawned on map 309
- encounter 785 High Priestess Jeklik creature 14517 not spawned on map 309
- encounter 786 High Priestess Mar'li creature 14510 not spawned on map 309
- encounter 787 Bloodlord Mandokir creature 11382 not spawned on map 309
- encounter 788 Edge of Madness creature 15083 not spawned on map 309
- encounter 789 High Priest Thekal creature 14509 not spawned on map 309
- encounter 790 Gahz'ranka creature 15114 not spawned on map 309
- encounter 791 High Priestess Arlokk creature 14515 not spawned on map 309
- encounter 792 Jin'do the Hexxer creature 11380 not spawned on map 309
- encounter 1835 Lord Kur'talos Ravencrest creature 99611 not spawned on map 1501
- encounter 1028 Ascendant Council creature 43735 not spawned on map 671
- encounter 1047 Ozumat creature 42172 not spawned on map 643
- encounter 1081 Vanessa VanCleef creature 49541 not spawned on map 36
- encounter 1083 Sinestra creature 49744 not spawned on map 671
- encounter 1087 Lord Jaraxxus creature 34780 not spawned on map 649
- encounter 1088 Northrend Beasts creature 34797 not spawned on map 649
- encounter 1089 Val'kyr Twins creature 34496 not spawned on map 649
- encounter 1095 Blood Council creature 37970 not spawned on map 631
- encounter 1807 Fenryr creature 99868 not spawned on map 1477
- encounter 1143 Yogg-Saron creature 33288 not spawned on map 603
- encounter 1206 Alysrazor creature 52530 not spawned on map 720
- encounter 1834 Smashspite the Hateful creature 98948 not spawned on map 1501
- encounter 1348 Omar the Test Dragon creature 16089 not spawned on map 598

## Encounter creature script is not compiled (16)

creature_template.ScriptName for an encounter credit is not registered in core/src/server/scripts.

- creature 98696 script boss_illysanna_ravencrest
- creature 22917 script boss_illidan_stormrage
- creature 98542 script boss_amalgam_of_souls
- creature 99200 script boss_dresaron
- creature 103344 script boss_oakheart
- creature 95676 script boss_odyn_hov
- creature 15928 script boss_thaddius
- creature 95675 script boss_god_king_kovald
- creature 99868 script boss_fenryr
- creature 95833 script boss_hyrja
- creature 94960 script boss_hymdall
- creature 91784 script boss_warlord_parjesh
- creature 91789 script boss_lady_hatecoil
- creature 91797 script boss_king_deepbeard
- creature 91808 script boss_serpentrix
- creature 96028 script boss_wrath_of_azshara

## Instance map has no creature spawns (24)

The map is an instance in the client and in instance_template, and the creature table has zero rows on it.

- 44 <unused> Monastery
- 169 Emerald Dream
- 309 Ancient Zul'Gurub
- 598 Sunwell Fix (Unused)
- 996 Terrace of Endless Spring
- 1000 Theramore's Fall (A)
- 1001 Scarlet Halls
- 1007 Scholomance
- 1098 Throne of Thunder
- 1136 Siege of Orgrimmar
- 1208 Grimrail Depot
- 1277 Defense of Karabor
- 1448 Hellfire Citadel
- 1458 Neltharion's Lair
- 1493 Vault of the Wardens
- 1498 Felsoul Hold
- 1516 The Arcway
- 1530 The Nighthold
- 1533 Karazhan Catacombs
- 1554 Boost Experience - Alliance
- 1648 Trial of Valor
- 1651 Return to Karazhan
- 1677 Cathedral of Eternal Night
- 1712 Antorus, the Burning Throne

## Dungeon spell script points at a missing spell (10)

spell_script_names names a spell the client does not have. spell_gen_dungeon_credit on 58630 is this pattern.

- spell 58630 script spell_gen_dungeon_credit is not in the client spell list
- spell 59046 script spell_gen_dungeon_credit is not in the client spell list
- spell 59450 script spell_gen_dungeon_credit is not in the client spell list
- spell 64899 script spell_gen_dungeon_credit is not in the client spell list
- spell 64985 script spell_gen_dungeon_credit is not in the client spell list
- spell 65074 script spell_gen_dungeon_credit is not in the client spell list
- spell 65195 script spell_gen_dungeon_credit is not in the client spell list
- spell 68184 script spell_gen_dungeon_credit is not in the client spell list
- spell 68572 script spell_gen_dungeon_credit is not in the client spell list
- spell 68574 script spell_gen_dungeon_credit is not in the client spell list

Dungeon-credit bindings seen: 58630=spell_gen_dungeon_credit, 59046=spell_gen_dungeon_credit, 59450=spell_gen_dungeon_credit, 61863=spell_gen_dungeon_credit, 64899=spell_gen_dungeon_credit, 64985=spell_gen_dungeon_credit, 65074=spell_gen_dungeon_credit, 65195=spell_gen_dungeon_credit, 68184=spell_gen_dungeon_credit, 68572=spell_gen_dungeon_credit, 68574=spell_gen_dungeon_credit, 68663=spell_gen_dungeon_credit, 72706=spell_gen_dungeon_credit, 72830=spell_gen_dungeon_credit, 72959=spell_gen_dungeon_credit.
