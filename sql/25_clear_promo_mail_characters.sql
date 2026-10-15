-- Remove the anniversary and faction letters already sitting in mailboxes.
DELETE ii FROM `item_instance` ii
INNER JOIN `mail_items` mi ON mi.item_guid = ii.guid
INNER JOIN `mail` m ON m.id = mi.mail_id
WHERE m.subject IN (
    'For the Alliance!',
    'For the Horde!',
    'Jade Tiger',
    'Warlord''s Deathwheel',
    'WoW''s 10th Anniversary',
    'WoW''s 11th Anniversary!',
    'WoW''s 12th Anniversary!',
    'WoW''s 13th Anniversary!',
    'WoW''s 4th anniversary!',
    'WoW''s 5th anniversary!',
    'WoW''s 7th Anniversary!',
    'WoW''s 8th Anniversary!',
    'WoW''s 9th Anniversary!'
);

DELETE mi FROM `mail_items` mi
INNER JOIN `mail` m ON m.id = mi.mail_id
WHERE m.subject IN (
    'For the Alliance!',
    'For the Horde!',
    'Jade Tiger',
    'Warlord''s Deathwheel',
    'WoW''s 10th Anniversary',
    'WoW''s 11th Anniversary!',
    'WoW''s 12th Anniversary!',
    'WoW''s 13th Anniversary!',
    'WoW''s 4th anniversary!',
    'WoW''s 5th anniversary!',
    'WoW''s 7th Anniversary!',
    'WoW''s 8th Anniversary!',
    'WoW''s 9th Anniversary!'
);

DELETE FROM `mail`
WHERE `subject` IN (
    'For the Alliance!',
    'For the Horde!',
    'Jade Tiger',
    'Warlord''s Deathwheel',
    'WoW''s 10th Anniversary',
    'WoW''s 11th Anniversary!',
    'WoW''s 12th Anniversary!',
    'WoW''s 13th Anniversary!',
    'WoW''s 4th anniversary!',
    'WoW''s 5th anniversary!',
    'WoW''s 7th Anniversary!',
    'WoW''s 8th Anniversary!',
    'WoW''s 9th Anniversary!'
);
