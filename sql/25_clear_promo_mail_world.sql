-- Stop the anniversary and faction reward letters. New characters were
-- granted these achievements on login, and each one mailed an account-bound item.
UPDATE `achievement_reward`
SET `item` = 0, `sender` = 0, `subject` = NULL, `text` = NULL, `mailTemplate` = 0
WHERE `entry` IN (
    2398,  -- WoW's 4th anniversary
    3636,  -- Jade Tiger
    4400,  -- WoW's 5th anniversary
    5863,  -- WoW's 7th Anniversary
    6131,  -- WoW's 8th Anniversary
    7853,  -- WoW's 9th Anniversary
    8820,  -- WoW's 10th Anniversary
    9496,  -- Warlord's Deathwheel
    10058, -- WoW's 11th Anniversary
    10741, -- WoW's 12th Anniversary
    11210, -- For the Alliance!
    11211, -- For the Horde!
    11848  -- WoW's 13th Anniversary
);
