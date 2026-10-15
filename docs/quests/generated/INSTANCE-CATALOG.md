# Dungeons and raids through Legion

Built from the Legion 7.3.5 client Adventure Guide (`JournalInstance`, `JournalEncounter`) plus `LFGDungeons` and this server's `instance_template` and creature spawns.

That is the same list the Legion client shows in the Dungeon Journal. Wowhead and Warcraft Wiki describe the same places in prose. The live retail site is a later expansion, so its dungeon list is a different game and is not the source for this server.

A row is missing creatures when the spawn count is 0. A row is missing a script when the script column is blank or the map has no `instance_template` row. A script name in the database still needs a C++ file that the server actually loads.

World bosses and invasion points are left out. They share map ids with raids in the journal and are not dungeon encounters.

## Classic (16 dungeons, 4 raids)

### Blackfathom Deeps — map 48, dungeon

Script: `instance_blackfathom_deeps`. Creatures spawned: 210.

1. Ghamoo-Ra
2. Domina
3. Subjugator Kor'ul
4. Thruk
5. Guardian of the Deep
6. Executioner Gore
7. Twilight Lord Bathiel
8. Aku'mai

### Blackrock Depths — map 230, dungeon

Script: `instance_blackrock_depths`. Creatures spawned: 1234.

1. High Interrogator Gerstahn
2. Lord Roccor
3. Houndmaster Grebmar
4. Ring of Law
5. Pyromancer Loregrain
6. Lord Incendius
7. Warder Stilgiss
8. Fineous Darkvire
9. Bael'Gar
10. General Angerforge
11. Golem Lord Argelmach
12. Hurley Blackbreath
13. Phalanx
14. Plugger Spazzring
15. Ambassador Flamelash
16. The Seven
17. Magmus
18. Emperor Dagran Thaurissan

### Dire Maul — map 429, dungeon

Script: `instance_dire_maul`. Creatures spawned: 1007.

1. Zevrim Thornhoof
2. Hydrospawn
3. Lethtendris
4. Alzzin the Wildshaper
5. Tendris Warpwood
6. Illyanna Ravenoak
7. Magister Kalendris
8. Immol'thar
9. Prince Tortheldrin
10. Guard Mol'dar
11. Stomper Kreeg
12. Guard Fengus
13. Guard Slip'kik
14. Captain Kromcrush
15. Cho'Rush the Observer
16. King Gordok

### Gnomeregan — map 90, dungeon

Script: `instance_gnomeregan`. Creatures spawned: 412.

1. Grubbis
2. Viscous Fallout
3. Electrocutioner 6000
4. Crowd Pummeler 9-60
5. Mekgineer Thermaplugg

### Lower Blackrock Spire — map 229, dungeon

Script: `instance_blackrock_spire`. Creatures spawned: 721.

1. Highlord Omokk
2. Shadow Hunter Vosh'gajin
3. War Master Voone
4. Mother Smolderweb
5. Urok Doomhowl
6. Quartermaster Zigris
7. Halycon
8. Gizrul the Slavener
9. Overlord Wyrmthalak

### Maraudon — map 349, dungeon

Script: `instance_maraudon`. Creatures spawned: 442.

1. Noxxion
2. Razorlash
3. Tinkerer Gizlock
4. Lord Vyletongue
5. Celebras the Cursed
6. Landslide
7. Rotgrip
8. Princess Theradras

### Ragefire Chasm — map 389, dungeon

Script: `instance_ragefire_chasm`. Creatures spawned: 140.

1. Adarogg
2. Dark Shaman Koranthal
3. Slagmaw
4. Lava Guard Gordoth

### Razorfen Downs — map 129, dungeon

Script: `instance_razorfen_downs`. Creatures spawned: 237.

1. Aarux
2. Mordresh Fire Eye
3. Mushlump
4. Death Speaker Blackthorn
5. Amnennar the Coldbringer

### Razorfen Kraul — map 47, dungeon

Script: `instance_razorfen_kraul`. Creatures spawned: 165.

1. Hunter Bonetusk
2. Roogug
3. Warlord Ramtusk
4. Groyat, the Blind Hunter
5. Charlga Razorflank

### Scarlet Monastery - OLD — map 189, dungeon

Script: `instance_scarlet_monastery`. Creatures spawned: 470.

No journal bosses.

### Stratholme — map 329, dungeon

Script: `instance_stratholme`. Creatures spawned: 771.

1. Hearthsinger Forresten
2. Timmy the Cruel
3. Commander Malor
4. Willey Hopebreaker
5. Instructor Galford
6. Balnazzar
7. The Unforgiven
8. Baroness Anastari
9. Nerub'enkan
10. Maleki the Pallid
11. Magistrate Barthilas
12. Ramstein the Gorger
13. Lord Aurius Rivendare

### The Stockade — map 34, dungeon

Script: `instance_the_stockade`. Creatures spawned: 142.

1. Hogger
2. Lord Overheat
3. Randolph Moloch

### The Temple of Atal'hakkar — map 109, dungeon

Script: `instance_sunken_temple`. Creatures spawned: 119.

1. Avatar of Hakkar
2. Jammal'an the Prophet
3. Wardens of the Dream
4. Shade of Eranikus

### Uldaman — map 70, dungeon

Script: `instance_uldaman`. Creatures spawned: 297.

1. Revelosh
2. The Lost Dwarves
3. Ironaya
4. Obsidian Sentinel
5. Ancient Stone Keeper
6. Galgann Firehammer
7. Grimlok
8. Archaedas

### Wailing Caverns — map 43, dungeon

Script: `instance_wailing_caverns`. Creatures spawned: 180.

1. Lady Anacondra
2. Lord Pythas
3. Lord Cobrahn
4. Kresh
5. Skum
6. Lord Serpentis
7. Verdan the Everliving
8. Mutanus the Devourer

### Zul'Farrak — map 209, dungeon

Script: `instance_zulfarrak`. Creatures spawned: 373.

1. Gahz'rilla
2. Antu'sul
3. Theka the Martyr
4. Witch Doctor Zum'rah
5. Nekrum & Sezz'ziz
6. Chief Ukorz Sandscalp

### Blackwing Lair — map 469, raid

Script: `instance_blackwing_lair`. Creatures spawned: 191.

1. Razorgore the Untamed
2. Vaelastrasz the Corrupt
3. Broodlord Lashlayer
4. Firemaw
5. Ebonroc
6. Flamegor
7. Chromaggus
8. Nefarian

### Molten Core — map 409, raid

Script: `instance_molten_core`. Creatures spawned: 283.

1. Lucifron
2. Magmadar
3. Gehennas
4. Garr
5. Shazzrah
6. Baron Geddon
7. Sulfuron Harbinger
8. Golemagg the Incinerator
9. Majordomo Executus
10. Ragnaros

### Ruins of Ahn'Qiraj — map 509, raid

Script: `instance_ruins_of_ahnqiraj`. Creatures spawned: 377.

1. Kurinnaxx
2. General Rajaxx
3. Moam
4. Buru the Gorger
5. Ayamiss the Hunter
6. Ossirian the Unscarred

### Temple of Ahn'Qiraj — map 531, raid

Script: `instance_temple_of_ahnqiraj`. Creatures spawned: 647.

1. The Prophet Skeram
2. Silithid Royalty
3. Battleguard Sartura
4. Fankriss the Unyielding
5. Viscidus
6. Princess Huhuran
7. The Twin Emperors
8. Ouro
9. C'thun

## The Burning Crusade (16 dungeons, 8 raids)

### Auchenai Crypts — map 558, dungeon

Script: `instance_auchenai_crypts`. Creatures spawned: 200.

1. Shirrak the Dead Watcher
2. Exarch Maladaar

### Hellfire Ramparts — map 543, dungeon

Script: `instance_ramparts`. Creatures spawned: 88.

1. Watchkeeper Gargolmar
2. Omor the Unscarred
3. Vazruden the Herald

### Magisters' Terrace — map 585, dungeon

Script: `instance_magisters_terrace`. Creatures spawned: 230.

1. Selin Fireheart
2. Vexallus
3. Priestess Delrissa
4. Kael'thas Sunstrider

### Mana-Tombs — map 557, dungeon

Script: `instance_mana_tombs`. Creatures spawned: 182.

1. Pandemonius
2. Tavarok
3. Yor
4. Nexus-Prince Shaffar

### Old Hillsbrad Foothills — map 560, dungeon

Script: `instance_old_hillsbrad`. Creatures spawned: 494.

1. Lieutenant Drake
2. Captain Skarloc
3. Epoch Hunter

### Sethekk Halls — map 556, dungeon

Script: `instance_sethekk_halls`. Creatures spawned: 186.

1. Darkweaver Syth
2. Anzu
3. Talon King Ikiss

### Shadow Labyrinth — map 555, dungeon

Script: `instance_shadow_labyrinth`. Creatures spawned: 271.

1. Ambassador Hellmaw
2. Blackheart the Inciter
3. Grandmaster Vorpil
4. Murmur

### The Arcatraz — map 552, dungeon

Script: `instance_arcatraz`. Creatures spawned: 131.

1. Zereketh the Unbound
2. Dalliah the Doomsayer
3. Wrath-Scryer Soccothrates
4. Harbinger Skyriss

### The Black Morass — map 269, dungeon

Script: `instance_the_black_morass`. Creatures spawned: 313.

1. Chrono Lord Deja
2. Temporus
3. Aeonus

### The Blood Furnace — map 542, dungeon

Script: `instance_blood_furnace`. Creatures spawned: 162.

1. The Maker
2. Broggok
3. Keli'dan the Breaker

### The Botanica — map 553, dungeon

Script: `instance_the_botanica`. Creatures spawned: 214.

1. Commander Sarannis
2. High Botanist Freywinn
3. Thorngrin the Tender
4. Laj
5. Warp Splinter

### The Mechanar — map 554, dungeon

Script: `instance_mechanar`. Creatures spawned: 123.

1. Mechano-Lord Capacitus
2. Nethermancer Sepethrea
3. Pathaleon the Calculator

### The Shattered Halls — map 540, dungeon

Script: `instance_shattered_halls`. Creatures spawned: 216.

1. Grand Warlock Nethekurse
2. Blood Guard Porung
3. Warbringer O'mrogg
4. Warchief Kargath Bladefist

### The Slave Pens — map 547, dungeon

Script: `instance_the_slave_pens`. Creatures spawned: 320.

1. Mennu the Betrayer
2. Rokmar the Crackler
3. Quagmirran

### The Steamvault — map 545, dungeon

Script: `instance_steam_vault`. Creatures spawned: 158.

1. Hydromancer Thespia
2. Mekgineer Steamrigger
3. Warlord Kalithresh

### The Underbog — map 546, dungeon

Script: `instance_the_underbog`. Creatures spawned: 163.

1. Hungarfen
2. Ghaz'an
3. Swamplord Musel'ek
4. The Black Stalker

### Black Temple — map 564, raid

Script: `instance_black_temple`. Creatures spawned: 582.

1. High Warlord Naj'entus
2. Supremus
3. Shade of Akama
4. Teron Gorefiend
5. Gurtogg Bloodboil
6. Reliquary of Souls
7. Mother Shahraz
8. The Illidari Council
9. Illidan Stormrage

### Gruul's Lair — map 565, raid

Script: `instance_gruuls_lair`. Creatures spawned: 15.

1. High King Maulgar
2. Gruul the Dragonkiller

### Karazhan — map 532, raid

Script: `instance_karazhan`. Creatures spawned: 909.

1. Servant's Quarters
2. Attumen the Huntsman
3. Moroes
4. Maiden of Virtue
5. Opera Hall
6. The Curator
7. Shade of Aran
8. Terestian Illhoof
9. Netherspite
10. Chess Event
11. Prince Malchezaar

### Magtheridon's Lair — map 544, raid

Script: `instance_magtheridons_lair`. Creatures spawned: 53.

1. Magtheridon

### Serpentshrine Cavern — map 548, raid

Script: `instance_serpent_shrine`. Creatures spawned: 219.

1. Hydross the Unstable
2. The Lurker Below
3. Leotheras the Blind
4. Fathom-Lord Karathress
5. Morogrim Tidewalker
6. Lady Vashj

### Sunwell Plateau — map 580, raid

Script: `instance_sunwell_plateau`. Creatures spawned: 469.

1. Kalecgos
2. Brutallus
3. Felmyst
4. The Eredar Twins
5. M'uru
6. Kil'jaeden

### The Battle for Mount Hyjal — map 534, raid

Script: `instance_hyjal`. Creatures spawned: 606.

1. Rage Winterchill
2. Anetheron
3. Kaz'rogal
4. Azgalor
5. Archimonde

### The Eye — map 550, raid

Script: `instance_the_eye`. Creatures spawned: 225.

1. Al'ar
2. Void Reaver
3. High Astromancer Solarian
4. Kael'thas Sunstrider

## Wrath of the Lich King (16 dungeons, 9 raids)

### Ahn'kahet: The Old Kingdom — map 619, dungeon

Script: `instance_ahnkahet`. Creatures spawned: 327.

1. Elder Nadox
2. Prince Taldaram
3. Jedoga Shadowseeker
4. Amanitar
5. Herald Volazj

### Azjol-Nerub — map 601, dungeon

Script: `instance_azjol_nerub`. Creatures spawned: 122.

1. Krik'thir the Gatewatcher
2. Hadronox
3. Anub'arak

### Drak'Tharon Keep — map 600, dungeon

Script: `instance_drak_tharon_keep`. Creatures spawned: 177.

1. Trollgore
2. Novos the Summoner
3. King Dred
4. The Prophet Tharon'ja

### Gundrak — map 604, dungeon

Script: `instance_gundrak`. Creatures spawned: 182.

1. Slad'ran
2. Drakkari Colossus
3. Moorabi
4. Eck the Ferocious
5. Gal'darah

### Halls of Lightning — map 602, dungeon

Script: `instance_halls_of_lightning`. Creatures spawned: 191.

1. General Bjarngrim
2. Volkhan
3. Ionar
4. Loken

### Halls of Reflection — map 668, dungeon

Script: `instance_halls_of_reflection`. Creatures spawned: 134.

1. Falric
2. Marwyn
3. Escape from Arthas

### Halls of Stone — map 599, dungeon

Script: `instance_halls_of_stone`. Creatures spawned: 121.

1. Krystallus
2. Maiden of Grief
3. Tribunal of Ages
4. Sjonnir the Ironshaper

### Pit of Saron — map 658, dungeon

Script: `instance_pit_of_saron`. Creatures spawned: 602.

1. Forgemaster Garfrost
2. Ick & Krick
3. Scourgelord Tyrannus

### The Culling of Stratholme — map 595, dungeon

Script: `instance_culling_of_stratholme`. Creatures spawned: 376.

1. Meathook
2. Salramm the Fleshcrafter
3. Chrono-Lord Epoch
4. Mal'Ganis

### The Forge of Souls — map 632, dungeon

Script: `instance_forge_of_souls`. Creatures spawned: 79.

1. Bronjahm
2. Devourer of Souls

### The Nexus — map 576, dungeon

Script: `instance_nexus`. Creatures spawned: 345.

1. Commander Kolurg
2. Commander Stoutbeard
3. Grand Magus Telestra
4. Anomalus
5. Ormorok the Tree-Shaper
6. Keristrasza

### The Oculus — map 578, dungeon

Script: `instance_oculus`. Creatures spawned: 152.

1. Drakos the Interrogator
2. Varos Cloudstrider
3. Mage-Lord Urom
4. Ley-Guardian Eregos

### The Violet Hold — map 608, dungeon

Script: `instance_violet_hold`. Creatures spawned: 45.

1. Erekem
2. Moragg
3. Ichoron
4. Xevozz
5. Lavanthor
6. Zuramat the Obliterator
7. Cyanigosa

### Trial of the Champion — map 650, dungeon

Script: `instance_trial_of_the_champion`. Creatures spawned: 184.

1. Grand Champions
2. Eadric the Pure
3. Argent Confessor Paletress
4. The Black Knight

### Utgarde Keep — map 574, dungeon

Script: `instance_utgarde_keep`. Creatures spawned: 146.

1. Prince Keleseth
2. Skarvald & Dalronn
3. Ingvar the Plunderer

### Utgarde Pinnacle — map 575, dungeon

Script: `instance_utgarde_pinnacle`. Creatures spawned: 230.

1. Svala Sorrowgrave
2. Gortok Palehoof
3. Skadi the Ruthless
4. King Ymiron

### Icecrown Citadel — map 631, raid

Script: `instance_icecrown_citadel`. Creatures spawned: 621.

1. Lord Marrowgar
2. Lady Deathwhisper
3. Icecrown Gunship Battle
4. Deathbringer Saurfang
5. Festergut
6. Rotface
7. Professor Putricide
8. Blood Prince Council
9. Blood-Queen Lana'thel
10. Valithria Dreamwalker
11. Sindragosa
12. The Lich King

### Naxxramas — map 533, raid

Script: `instance_naxxramas`. Creatures spawned: 857.

1. Anub'Rekhan
2. Grand Widow Faerlina
3. Maexxna
4. Noth the Plaguebringer
5. Heigan the Unclean
6. Loatheb
7. Instructor Razuvious
8. Gothik the Harvester
9. The Four Horsemen
10. Patchwerk
11. Grobbulus
12. Gluth
13. Thaddius
14. Sapphiron
15. Kel'Thuzad

### Onyxia's Lair — map 249, raid

Script: `instance_onyxias_lair`. Creatures spawned: 105.

1. Onyxia

### The Eye of Eternity — map 616, raid

Script: `instance_eye_of_eternity`. Creatures spawned: 16.

1. Malygos

### The Obsidian Sanctum — map 615, raid

Script: `instance_obsidian_sanctum`. Creatures spawned: 168.

1. Sartharion

### The Ruby Sanctum — map 724, raid

Script: `instance_ruby_sanctum`. Creatures spawned: 50.

1. Halion

### Trial of the Crusader — map 649, raid

Script: `instance_trial_of_the_crusader`. Creatures spawned: 222.

1. The Northrend Beasts
2. Lord Jaraxxus
3. Champions of the Alliance
4. Champions of the Horde
5. Twin Val'kyr
6. Anub'arak

### Ulduar — map 603, raid

Script: `instance_ulduar`. Creatures spawned: 1280.

1. Flame Leviathan
2. Ignis the Furnace Master
3. Razorscale
4. XT-002 Deconstructor
5. The Assembly of Iron
6. Kologarn
7. Auriaya
8. Hodir
9. Thorim
10. Freya
11. Mimiron
12. General Vezax
13. Yogg-Saron
14. Algalon the Observer

### Vault of Archavon — map 624, raid

Script: `instance_vault_of_archavon`. Creatures spawned: 36.

1. Archavon the Stone Watcher
2. Emalon the Storm Watcher
3. Koralon the Flame Watcher
4. Toravon the Ice Watcher

## Cataclysm (14 dungeons, 6 raids)

### Blackrock Caverns — map 645, dungeon

Script: `instance_blackrock_caverns`. Creatures spawned: 181.

1. Rom'ogg Bonecrusher
2. Corla, Herald of Twilight
3. Karsh Steelbender
4. Beauty
5. Ascendant Lord Obsidius

### Deadmines — map 36, dungeon

Script: `instance_deadmines`. Creatures spawned: 546.

1. Glubtok
2. Helix Gearbreaker
3. Foe Reaper 5000
4. Admiral Ripsnarl
5. Captain" Cookie
6. Vanessa VanCleef

### End Time — map 938, dungeon

Script: `instance_end_time`. Creatures spawned: 341.

1. Echo of Baine
2. Echo of Jaina
3. Echo of Sylvanas
4. Echo of Tyrande
5. Murozond

### Grim Batol — map 670, dungeon

Script: `instance_grim_batol`. Creatures spawned: 556.

1. General Umbriss
2. Forgemaster Throngus
3. Drahga Shadowburner
4. Erudax, the Duke of Below

### Halls of Origination — map 644, dungeon

Script: `instance_halls_of_origination`. Creatures spawned: 340.

1. Temple Guardian Anhuur
2. Earthrager Ptah
3. Anraphet
4. Isiset, Construct of Magic
5. Ammunae, Construct of Life
6. Setesh, Construct of Destruction
7. Rajh, Construct of Sun

### Hour of Twilight — map 940, dungeon

Script: `instance_hour_of_twilight`. Creatures spawned: 591.

1. Arcurion
2. Asira Dawnslayer
3. Archbishop Benedictus

### Lost City of the Tol'vir — map 755, dungeon

Script: `instance_lost_city_of_the_tolvir`. Creatures spawned: 372.

1. General Husam
2. Lockmaw
3. High Prophet Barim
4. Siamat

### Shadowfang Keep — map 33, dungeon

Script: `instance_shadowfang_keep`. Creatures spawned: 490.

1. Baron Ashbury
2. Baron Silverlaine
3. Commander Springvale
4. Lord Walden
5. Lord Godfrey

### The Stonecore — map 725, dungeon

Script: `instance_stonecore`. Creatures spawned: 226.

1. Corborus
2. Slabhide
3. Ozruk
4. High Priestess Azil

### The Vortex Pinnacle — map 657, dungeon

Script: `instance_the_vortex_pinnacle`. Creatures spawned: 145.

1. Grand Vizier Ertan
2. Altairus
3. Asaad, Caliph of Zephyrs

### Throne of the Tides — map 643, dungeon

Script: `instance_throne_of_the_tides`. Creatures spawned: 143.

1. Lady Naz'jar
2. Commander Ulthok, the Festering Prince
3. Mindbender Ghur'sha
4. Ozumat

### Well of Eternity — map 939, dungeon

Script: `instance_well_of_eternity`. Creatures spawned: 129.

1. Peroth'arn
2. Queen Azshara
3. Mannoroth and Varo'then

### Zul'Aman — map 568, dungeon

Script: `instance_zulaman`. Creatures spawned: 611.

1. Akil'zon
2. Nalorakk
3. Jan'alai
4. Halazzi
5. Hex Lord Malacrass
6. Daakara

### Zul'Gurub — map 859, dungeon

Script: `instance_zulgurub`. Creatures spawned: 1213.

1. High Priest Venoxis
2. Bloodlord Mandokir
3. Cache of Madness - Gri'lek
4. Cache of Madness - Hazza'rah
5. Cache of Madness - Renataki
6. Cache of Madness - Wushoolay
7. High Priestess Kilnara
8. Zanzil
9. Jin'do the Godbreaker

### Baradin Hold — map 757, raid

Script: `instance_baradin_hold`. Creatures spawned: 35.

1. Argaloth
2. Occu'thar
3. Alizabal, Mistress of Hate

### Blackwing Descent — map 669, raid

Script: `instance_blackwing_descent`. Creatures spawned: 104.

1. Omnotron Defense System
2. Magmaw
3. Atramedes
4. Chimaeron
5. Maloriak
6. Nefarian's End

### Dragon Soul — map 967, raid

Script: `instance_dragon_soul`. Creatures spawned: 1291.

1. Morchok
2. Warlord Zon'ozz
3. Yor'sahj the Unsleeping
4. Hagara the Stormbinder
5. Ultraxion
6. Warmaster Blackhorn
7. Spine of Deathwing
8. Madness of Deathwing

### Firelands — map 720, raid

Script: `instance_firelands`. Creatures spawned: 309.

1. Beth'tilac
2. Lord Rhyolith
3. Alysrazor
4. Shannox
5. Baleroc, the Gatekeeper
6. Majordomo Staghelm
7. Ragnaros

### The Bastion of Twilight — map 671, raid

Script: `instance_the_bastion_of_twilight`. Creatures spawned: 133.

1. Halfus Wyrmbreaker
2. Theralion and Valiona
3. Ascendant Council
4. Cho'gall
5. Sinestra

### Throne of the Four Winds — map 754, raid

Script: `instance_throne_of_the_four_winds`. Creatures spawned: 92.

1. The Conclave of Wind
2. Al'Akir

## Mists of Pandaria (9 dungeons, 5 raids)

### Gate of the Setting Sun — map 962, dungeon

Script: `instance_gate_setting_sun`. Creatures spawned: 804.

1. Saboteur Kip'tilak
2. Striker Ga'dok
3. Commander Ri'mok
4. Raigonn

### Mogu'shan Palace — map 994, dungeon

Script: `instance_mogu_shan_palace`. Creatures spawned: 929.

1. Trial of the King
2. Gekkan
3. Xin the Weaponmaster

### Scarlet Halls — map 1001, dungeon

Script: `instance_scarlet_halls`. Creatures spawned: 0.

1. Houndmaster Braun
2. Armsmaster Harlan
3. Flameweaver Koegler

### Scarlet Monastery — map 1004, dungeon

Script: `instance_scarlet_monastery_mop`. Creatures spawned: 180.

1. Thalnos the Soulrender
2. Brother Korloff
3. High Inquisitor Whitemane

### Scholomance — map 1007, dungeon

Script: `instance_scholomance_mop`. Creatures spawned: 0.

1. Instructor Chillheart
2. Jandice Barov
3. Rattlegore
4. Lilian Voss
5. Darkmaster Gandling

### Shado-Pan Monastery — map 959, dungeon

Script: `instance_shadopan_monastery`. Creatures spawned: 327.

1. Gu Cloudstrike
2. Master Snowdrift
3. Sha of Violence
4. Taran Zhu

### Siege of Niuzao Temple — map 1011, dungeon

Script: `instance_siege_of_the_niuzao_temple`. Creatures spawned: 364.

1. Vizier Jin'bak
2. Commander Vo'jak
3. General Pa'valak
4. Wing Leader Ner'onok

### Stormstout Brewery — map 961, dungeon

Script: `instance_stormstout_brewery`. Creatures spawned: 464.

1. Ook-Ook
2. Hoptallus
3. Yan-Zhu the Uncasked

### Temple of the Jade Serpent — map 960, dungeon

Script: `instance_temple_of_jade_serpent`. Creatures spawned: 183.

1. Wise Mari
2. Lorewalker Stonestep
3. Liu Flameheart
4. Sha of Doubt

### Heart of Fear — map 1009, raid

Script: `instance_heart_of_fear`. Creatures spawned: 227.

1. Imperial Vizier Zor'lok
2. Blade Lord Ta'yak
3. Garalon
4. Wind Lord Mel'jarak
5. Amber-Shaper Un'sok
6. Grand Empress Shek'zeer

### Mogu'shan Vaults — map 1008, raid

Script: `instance_mogu_shan_vault`. Creatures spawned: 606.

1. The Stone Guard
2. Feng the Accursed
3. Gara'jal the Spiritbinder
4. The Spirit Kings
5. Elegon
6. Will of the Emperor

### Siege of Orgrimmar — map 1136, raid

Script: `instance_siege_of_orgrimmar`. Creatures spawned: 0.

1. Immerseus
2. The Fallen Protectors
3. Norushen
4. Sha of Pride
5. Galakras
6. Iron Juggernaut
7. Kor'kron Dark Shaman
8. General Nazgrim
9. Malkorok
10. Spoils of Pandaria
11. Thok the Bloodthirsty
12. Siegecrafter Blackfuse
13. Paragons of the Klaxxi
14. Garrosh Hellscream

### Terrace of Endless Spring — map 996, raid

Script: `instance_terrace_of_endless_spring`. Creatures spawned: 0.

1. Protectors of the Endless
2. Tsulong
3. Lei Shi
4. Sha of Fear

### Throne of Thunder — map 1098, raid

Script: `instance_throne_of_thunder`. Creatures spawned: 0.

1. Jin'rokh the Breaker
2. Horridon
3. Council of Elders
4. Tortos
5. Megaera
6. Ji-Kun
7. Durumu the Forgotten
8. Primordius
9. Dark Animus
10. Iron Qon
11. Twin Consorts
12. Lei Shen
13. Ra-den

## Warlords of Draenor (8 dungeons, 3 raids)

### Auchindoun — map 1182, dungeon

Script: `instance_auchindoun`. Creatures spawned: 331.

1. Vigilant Kaathar
2. Soulbinder Nyami
3. Azzakel
4. Teron'gor

### Bloodmaul Slag Mines — map 1175, dungeon

Script: `instance_Bloodmaul`. Creatures spawned: 457.

1. Magmolatus
2. Slave Watcher Crushto
3. Roltall
4. Gug'rokk

### Grimrail Depot — map 1208, dungeon

Script: `instance_grimrail_depot`. Creatures spawned: 0.

1. Rocketspark and Borka
2. Nitrogg Thundertower
3. Skylord Tovra

### Iron Docks — map 1195, dungeon

Script: `instance_iron_docks`. Creatures spawned: 591.

1. Fleshrender Nok'gar
2. Grimrail Enforcers
3. Oshir
4. Skulloc

### Shadowmoon Burial Grounds — map 1176, dungeon

Script: `instance_shadowmoon_burial_grounds`. Creatures spawned: 320.

1. Sadana Bloodfury
2. Nhallish
3. Bonemaw
4. Ner'zhul

### Skyreach — map 1209, dungeon

Script: `instance_skyreach`. Creatures spawned: 298.

1. Ranjit
2. Araknath
3. Rukhran
4. High Sage Viryx

### The Everbloom — map 1279, dungeon

Script: `instance_everbloom`. Creatures spawned: 310.

1. Witherbark
2. Ancient Protectors
3. Archmage Sol
4. Xeri'tac
5. Yalnu

### Upper Blackrock Spire — map 1358, dungeon

Script: `instance_upper_blackrock_spire`. Creatures spawned: 361.

1. Orebender Gor'ashan
2. Kyrak
3. Commander Tharbek
4. Ragewing the Untamed
5. Warlord Zaela

### Blackrock Foundry — map 1205, raid

Script: `instance_blackrock_foundry`. Creatures spawned: 513.

1. Oregorger
2. Hans'gar and Franzok
3. Beastlord Darmac
4. Gruul
5. Flamebender Ka'graz
6. Operator Thogar
7. The Blast Furnace
8. Kromog
9. The Iron Maidens
10. Blackhand

### Hellfire Citadel — map 1448, raid

Script: `instance_hellfire_citadel`. Creatures spawned: 0.

1. Hellfire Assault
2. Iron Reaver
3. Kormrok
4. Hellfire High Council
5. Kilrogg Deadeye
6. Gorefiend
7. Shadow-Lord Iskar
8. Socrethar the Eternal
9. Fel Lord Zakuun
10. Xhul'horac
11. Tyrant Velhari
12. Mannoroth
13. Archimonde

### Highmaul — map 1228, raid

Script: `instance_highmaul`. Creatures spawned: 627.

1. Kargath Bladefist
2. The Butcher
3. Tectus
4. Brackenspore
5. Twin Ogron
6. Ko'ragh
7. Imperator Mar'gok

## Legion (13 dungeons, 5 raids)

### Assault on Violet Hold — map 1544, dungeon

Script: `instance_violet_hold_legion`. Creatures spawned: 145.

1. Blood-Princess Thal'ena
2. Festerface
3. Shivermaw
4. Anub'esset
5. Millificent Manastorm
6. Mindflayer Kaahrj
7. Fel Lord Betrug
8. Sael'orn

### Black Rook Hold — map 1501, dungeon

Script: `instance_black_rook_hold`. Creatures spawned: 217.

1. The Amalgam of Souls
2. Illysanna Ravencrest
3. Smashspite the Hateful
4. Lord Kur'talos Ravencrest

### Cathedral of Eternal Night — map 1677, dungeon

Script: `instance_cathedral_of_eternal_night`. Creatures spawned: 0.

1. Agronox
2. Thrashbite the Scornful
3. Domatrax
4. Mephistroth

### Court of Stars — map 1571, dungeon

Script: `instance_court_of_stars`. Creatures spawned: 472.

1. Patrol Captain Gerdo
2. Talixae Flamewreath
3. Advisor Melandrus

### Darkheart Thicket — map 1466, dungeon

Script: `instance_darkheart_thicket`. Creatures spawned: 291.

1. Archdruid Glaidalis
2. Oakheart
3. Dresaron
4. Shade of Xavius

### Eye of Azshara — map 1456, dungeon

Script: `instance_eye_of_azshara`. Creatures spawned: 613.

1. Warlord Parjesh
2. Lady Hatecoil
3. King Deepbeard
4. Serpentrix
5. Wrath of Azshara

### Halls of Valor — map 1477, dungeon

Script: `instance_halls_of_valor`. Creatures spawned: 219.

1. Hymdall
2. Hyrja
3. Fenryr
4. God-King Skovald
5. Odyn

### Maw of Souls — map 1492, dungeon

Script: `instance_maw_of_souls`. Creatures spawned: 182.

1. Ymiron, the Fallen King
2. Harbaron
3. Helya

### Neltharion's Lair — map 1458, dungeon

Script: `instance_neltharions_lair`. Creatures spawned: 0.

1. Rokmora
2. Ularogg Cragshaper
3. Naraxas
4. Dargrul the Underking

### Return to Karazhan — map 1651, dungeon

Script: `instance_return_to_karazhan`. Creatures spawned: 0.

1. Opera Hall: Wikket
2. Opera Hall: Westfall Story
3. Opera Hall: Beautiful Beast
4. Maiden of Virtue
5. Attumen the Huntsman
6. Moroes
7. The Curator
8. Shade of Medivh
9. Mana Devourer
10. Viz'aduum the Watcher

### Seat of the Triumvirate — map 1753, dungeon

Script: `instance_seat_of_triumvirate`. Creatures spawned: 686.

1. Zuraal the Ascended
2. Saprish
3. Viceroy Nezhar
4. L'ura

### The Arcway — map 1516, dungeon

Script: `instance_the_arcway`. Creatures spawned: 0.

1. Ivanyr
2. Corstilax
3. General Xakal
4. Nal'tira
5. Advisor Vandros

### Vault of the Wardens — map 1493, dungeon

Script: `instance_vault_of_the_wardens`. Creatures spawned: 0.

1. Tirathon Saltheril
2. Inquisitor Tormentorum
3. Ash'golm
4. Glazer
5. Cordana Felsong

### Antorus, the Burning Throne — map 1712, raid

Script: `instance_antorus_the_burning_throne`. Creatures spawned: 0.

1. Garothi Worldbreaker
2. Felhounds of Sargeras
3. Antoran High Command
4. Portal Keeper Hasabel
5. Eonar the Life-Binder
6. Imonar the Soulhunter
7. Kin'garoth
8. The Coven of Shivarra
9. Varimathras
10. Aggramar
11. Argus the Unmaker

### The Emerald Nightmare — map 1520, raid

Script: `instance_emerald_nightmare`. Creatures spawned: 403.

1. Nythendra
2. Il'gynoth, Heart of Corruption
3. Elerethe Renferal
4. Ursoc
5. Dragons of Nightmare
6. Cenarius
7. Xavius

### The Nighthold — map 1530, raid

Script: `instance_the_nighthold`. Creatures spawned: 0.

1. Skorpyron
2. Chronomatic Anomaly
3. Trilliax
4. Spellblade Aluriel
5. Tichondrius
6. Krosus
7. High Botanist Tel'arn
8. Star Augur Etraeus
9. Grand Magistrix Elisande
10. Gul'dan

### Tomb of Sargeras — map 1676, raid

Script: `instance_tomb_of_sargeras`. Creatures spawned: 1015.

1. Goroth
2. Demonic Inquisition
3. Harjatan
4. Sisters of the Moon
5. Mistress Sassz'ine
6. The Desolate Host
7. Maiden of Vigilance
8. Fallen Avatar
9. Kil'jaeden

### Trial of Valor — map 1648, raid

Script: `instance_trial_of_valor`. Creatures spawned: 0.

1. Odyn
2. Guarm
3. Helya
