INSERT IGNORE INTO `playerbot_random_names` (`name`) VALUES
('Aelric'),('Aldric'),('Amaryn'),('Ashara'),('Balthor'),
('Belthor'),('Branwen'),('Brynneth'),('Caelum'),('Caldris'),
('Cedric'),('Corvyn'),('Daenara'),('Davorin'),('Delwyn'),
('Drystan'),('Eirwen'),('Elandra'),('Elowen'),('Elowyn'),
('Faelan'),('Faelith'),('Farryn'),('Fenric'),('Galren'),
('Gareth'),('Grimwald'),('Gwyneira'),('Hadrian'),('Halden'),
('Hallowyn'),('Hestian'),('Iridessa'),('Iskander'),('Isolde'),
('Ivaris'),('Jassara'),('Jorath'),('Jorund'),('Jorvyn'),
('Kaelis'),('Kaelith'),('Kestrel'),('Korrath'),('Lirien'),
('Loriane'),('Lorne'),('Lyriana'),('Maelor'),('Maevyn'),
('Miravel'),('Mirelle'),('Morvane'),('Neryssa'),('Nymera'),('Nyssara'),
('Nythera'),('Orlana'),('Orvyn'),('Osric'),('Oswin'),
('Pellin'),('Pellinor'),('Pyralis'),('Quenara'),('Quillan'),
('Quinlan'),('Rhydian'),('Riven'),('Rivenna'),('Rowan'),
('Sableth'),('Serapha'),('Solenne'),('Sylvara'),('Talindra'),
('Tamsin'),('Thorne'),('Torvin'),('Ulfgar'),('Ulric'),
('Umbric'),('Vaelis'),('Vaelith'),('Vaelor'),('Vespera'),
('Wrenna'),('Wyland'),('Wyndra'),('Wynter'),('Xandrel'),
('Xerion'),('Ylvara'),('Ysara'),('Ysabel'),('Ysolde'),
('Zaroth'),('Zephyr'),('Zevaris'),('Zorvyn');

INSERT IGNORE INTO `playerbot_arena_names` (`name`)
SELECT `name` FROM `playerbot_random_names`;
