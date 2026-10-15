-- Ensure every Legion dungeon/raid has an instance_template row.
-- parent 1220 = Broken Isles, 1669 = Argus. Missing rows = blank/unenterable instances.

INSERT INTO `instance_template` (`map`, `parent`, `script`, `allowMount`) VALUES
(1456, 1220, 'instance_eye_of_azshara', 1),
(1458, 1220, 'instance_neltharions_lair', 0),
(1466, 1220, 'instance_darkheart_thicket', 0),
(1477, 1220, 'instance_halls_of_valor', 1),
(1492, 1220, 'instance_maw_of_souls', 0),
(1493, 1220, 'instance_vault_of_the_wardens', 0),
(1501, 1220, 'instance_black_rook_hold', 0),
(1516, 1220, 'instance_the_arcway', 0),
(1544, 1220, 'instance_violet_hold_legion', 0),
(1571, 1220, 'instance_court_of_stars', 0),
(1651, 0,    'instance_return_to_karazhan', 0),
(1677, 1220, 'instance_cathedral_of_eternal_night', 0),
(1753, 1669, 'instance_seat_of_the_triumvirate', 0),
(1520, 1220, 'instance_the_emerald_nightmare', 1),
(1530, 1220, 'instance_the_nighthold', 0),
(1648, 1220, 'instance_trial_of_valor', 1),
(1676, 1220, 'instance_tomb_of_sargeras', 0),
(1712, 1669, 'instance_antorus_the_burning_throne', 1)
ON DUPLICATE KEY UPDATE
  parent=VALUES(parent),
  script=IF(script IS NULL OR script='', VALUES(script), script),
  allowMount=VALUES(allowMount);
