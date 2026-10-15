-- They Sent Assassins: Goblin Assassin (50039) is the kill target.
-- Sergeant Willem (823) is the only giver and turn-in. The assassins were
-- also registered as quest givers, so clicking one offered the quest.
DELETE FROM `creature_queststarter` WHERE `id` = 50039;

-- Faction 14 is the hostile monster faction already used by the Blackrock
-- Invaders in this same valley. Faction 7 is neutral and never attacks.
UPDATE `creature_template`
SET `npcflag` = 0, `dynamicflags` = 0, `faction` = 14
WHERE `entry` = 50039;
