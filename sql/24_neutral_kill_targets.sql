-- Neutral kill targets across every expansion. These factions have no player
-- enemy and no player friend, so the creatures never attack.
-- Faction 14 is the hostile monster faction. Left alone: rescues, item-use
-- targets, destroyed objects, nests, vendors, the Ring of Blood, and the
-- death-knight prisoners you speak to before the fight.

UPDATE `creature_template`
SET `faction` = 14,
    `dynamicflags` = `dynamicflags` & ~4
WHERE `entry` IN (
    -- Classic and Cataclysm starter / old world
    15274, -- Mana Wyrm
    37070, -- Rockjaw Invader
    1502,  -- Wretched Ghoul
    1984,  -- Young Thistle Boar
    2031,  -- Young Nightsaber
    16516, -- Volatile Mutation
    34884, -- Rampaging Worgen
    42185, -- Living Contamination
    708,   -- Small Crag Boar
    1890,  -- Rattlecage Skeleton
    1985,  -- Thistle Boar
    2032,  -- Mangy Nightsaber
    36697, -- Bristleback Thorncaller
    39317, -- Northwatch Scout
    49871, -- Blackrock Worg
    49874, -- Blackrock Spy
    1504,  -- Young Night Web Spider
    1505,  -- Night Web Spider
    1986,  -- Webwood Spider
    36696, -- Armored Battleboar
    946,   -- Frostmane Novice
    37507, -- Frostmane Blade
    5472,  -- Dunemaul Enforcer
    2505,  -- Saltwater Snapjaw
    6509,  -- Bloodpetal Lasher
    6510,  -- Bloodpetal Flayer
    6511,  -- Bloodpetal Thresher
    6512,  -- Bloodpetal Trapper
    -- Cataclysm
    52392, -- Gurubashi Master Chef
    -- Pandaria, Draenor, Legion
    58116, -- Carp Hunter
    58671, -- Ancient Mogu Spirit
    76189, -- Ironmarch Grunt
    82458, -- Gar'mak Bladetwist
    89324, -- Spirit of Kairozdormu
    91100  -- Brogozog
);
