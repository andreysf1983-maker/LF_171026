-- Kill targets that were also registered as the giver of that same quest.
-- Another NPC already gives each of these quests, and these creatures turn nothing in.
-- Rescues, vehicles, and credit markers are not in this list.

-- Real fights that never turned hostile (faction 7, or a monster template with no player enemy).
-- Faction 14 is the hostile monster faction used by the Blackrock Invaders.
UPDATE `creature_template`
SET `npcflag` = `npcflag` & ~2,
    `dynamicflags` = `dynamicflags` & ~4,
    `faction` = 14
WHERE `entry` IN (
    3101,  -- Vile Familiar
    3102,  -- Felstalker
    15271, -- Tender
    15273, -- Arcane Wraith
    15294, -- Feral Tender
    15298, -- Tainted Arcane Wraith
    16521, -- Blood Elf Scout
    16522, -- Surveyor Candress
    34865, -- Tunneling Worm
    1501,  -- Mindless Zombie
    2952,  -- Bristleback Invaders
    3098,  -- Mottled Boar
    706,   -- Frostmane Troll Whelp
    37073, -- Rockjaw Goon
    808    -- Grik'nir the Cold
);

-- Already hostile, or not a fight (training target, gatherable corpse). Quest flag only.
UPDATE `creature_template`
SET `npcflag` = `npcflag` & ~2,
    `dynamicflags` = `dynamicflags` & ~4
WHERE `entry` IN (
    37112, -- Wayward Fire Elemental
    38142, -- Captive Spitescale Scout
    42223, -- Irradiated Technician
    42938, -- Kurtok the Slayer
    49424, -- Marshal Redpath
    35463, -- Bloodfang Lurker
    38306, -- Zar'jira
    35118, -- Bloodfang Worgen
    35229, -- Bloodfang Stalker
    35627, -- Frenzied Stalker
    38300, -- Spitescale Wavethrasher
    38038, -- Tiki Target
    49340  -- Scarlet Corpse
);

DELETE FROM `creature_queststarter` WHERE `id` IN (
    3101, 3102, 15271, 15273, 15294, 15298, 16521, 16522, 34865,
    1501, 2952, 3098, 706, 37073, 808,
    37112, 38142, 42223, 42938, 49424, 35463, 38306,
    35118, 35229, 35627, 38300, 38038, 49340
);
