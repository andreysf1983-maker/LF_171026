# Wandering Isle / Pandaren (5736)

QuestSortID: **5736** | Level range: 1-12 | Exported: 2026-08-24

See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.

| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |
|----|-------|-----|------|------|----------|---------------|--------|
| 29405 | The Lesson of the Iron Staff | 1 | 0 | 29406 | P01-KILL | - | - |
| 30027 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30033 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30034 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30035 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30036 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30037 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30038 | The Lesson of the Iron Bough | 1 | 0 | 29406 | P01-KILL | - | - |
| 30039 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30040 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30041 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30042 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30043 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30044 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 30045 | Much to Learn | 1 | 0 | 29405 | P00-UNKNOWN | - | - |
| 29406 | The Lesson of the Sandy Fist | 2 | 0 | 0 | P01-KILL | - | - |
| 29407 | The First Sign of Winter | 2 | 0 | 0 | P02-COLLECT | - | - |
| 29408 | The Lesson of the Burning Scroll | 2 | 29524 | 0 | P01-KILL, P05-ITEM-USE-CAPTURE | 80212 | - |
| 29409 | The Disciple's Challenge | 2 | 29408 | 0 | P01-KILL | - | - |
| 29410 | Aysa of the Tushui | 2 | 29409 | 0 | P00-UNKNOWN | - | - |
| 29524 | The Lesson of Stifled Pride | 2 | 29406 | 0 | P01-KILL | - | - |
| 29414 | The Way of the Tushui | 3 | 0 | 0 | P01-KILL, P09-PHASED, P11-CUSTOM-SCRIPT | - | `q_the_way_of_the_tushui` |
| 29419 | The Missing Driver | 3 | 29410 | 29414 | P01-KILL, P09-PHASED | - | - |
| 29424 | Items of Utmost Importance | 3 | 29410 | 29414 | P02-COLLECT | - | - |
| 29522 | Ji of the Huojin | 3 | 29414 | 0 | P00-UNKNOWN | - | - |
| 29417 | The Way of the Huojin | 4 | 29522 | 0 | P01-KILL | - | - |
| 29418 | Kindling the Fire | 4 | 29417 | 29420 | P02-COLLECT | - | - |
| 29420 | The Spirit's Guardian | 4 | 0 | 0 | P00-UNKNOWN | - | - |
| 29421 | Only the Worthy Shall Pass | 4 | 29664 | 0 | P01-KILL, P09-PHASED, P11-CUSTOM-SCRIPT | - | `q_only_the_worthy_shall_pass` |
| 29422 | Huo, the Spirit of Fire | 4 | 29421 | 0 | P01-KILL, P05-ITEM-USE-CAPTURE, P09-PHASED | 72583 | - |
| 29523 | Fanning the Flames | 4 | 29417 | 29420 | P02-COLLECT | 72109 | - |
| 29664 | The Challenger's Fires | 4 | 29420 | 0 | P01-KILL, P05-ITEM-USE-CAPTURE | 75008 | - |
| 29703 | Barrel of Monkies | 4 | 0 | 0 | P01-KILL | - | - |
| 29423 | The Passion of Shen-zin Su | 5 | 29422 | 0 | P01-KILL, P09-PHASED, P11-CUSTOM-SCRIPT | - | `q_passion_of_shenzin_su` |
| 29773 | Wugou, the Spirit of Earth | 6 | 29680 | 29768 | P01-KILL | - | - |
| 30817 | The Healing of Shen-zin Su | 9 | 0 | 0 | P01-KILL | - | - |
| 30454 | Pandaren Alliance Tracking Quest | 10 | 0 | 0 | P00-UNKNOWN | - | - |
| 30455 | Pandaren Horde Tracking Quest | 10 | 0 | 0 | P00-UNKNOWN | - | - |
| 30818 | A New Fate | 10 | 30817 | 0 | P00-UNKNOWN | - | - |
| 32396 | Uncompletable Binding Quest [DND] | 10 | 0 | 0 | P00-UNKNOWN | - | - |

## Pattern summary (this zone)

- **P00-UNKNOWN**: 14 quest(s)
- **P01-KILL**: 22 quest(s)
- **P02-COLLECT**: 4 quest(s)
- **P05-ITEM-USE-CAPTURE**: 3 quest(s)
- **P09-PHASED**: 5 quest(s)
- **P11-CUSTOM-SCRIPT**: 3 quest(s)

## Objectives (implementation reference)

| Quest | Objective type | ObjectID | Description | StartItem |
|-------|----------------|----------|-------------|-----------|
| 29405 The Lesson of the Iron Staff | MONSTER | 54139 | Loot and Equip a Training Weapon | 0 |
| 29406 The Lesson of the Sandy Fist | MONSTER | 53714 | Training Targets destroyed | 0 |
| 29407 The First Sign of Winter | ITEM | 71079 |  | 0 |
| 29408 The Lesson of the Burning Scroll | MONSTER | 59591 | Snatch the Master's Flame | 80212 |
| 29408 The Lesson of the Burning Scroll | MONSTER | 59570 | Burn the Edict of Temperance | 80212 |
| 29409 The Disciple's Challenge | MONSTER | 54611 | Defeat Jaomin Ro | 0 |
| 29414 The Way of the Tushui | MONSTER | 54856 | Protect Aysa while she meditates | 0 |
| 29417 The Way of the Huojin | MONSTER | 54131 | Fe-Feng attackers slain | 0 |
| 29418 Kindling the Fire | ITEM | 72111 |  | 0 |
| 29419 The Missing Driver | MONSTER | 54855 | Rescue the Cart Driver | 0 |
| 29421 Only the Worthy Shall Pass | MONSTER | 54734 | Defeat Master Li Fei | 0 |
| 29422 Huo, the Spirit of Fire | MONSTER | 54787 | Reignite the Spirit of Fire | 72583 |
| 29423 The Passion of Shen-zin Su | MONSTER | 61128 | Bring the Spirit of Fire to the Temple of Five Dawns | 0 |
| 29424 Items of Utmost Importance | ITEM | 72071 |  | 0 |
| 29523 Fanning the Flames | ITEM | 72112 |  | 72109 |
| 29524 The Lesson of Stifled Pride | MONSTER | 54586 | Sparring Trainees defeated | 0 |
| 29664 The Challenger's Fires | MONSTER | 56048 | Challenger Torch lit | 75008 |
| 29664 The Challenger's Fires | MONSTER | 56037 | Red Brazier lit | 75008 |
| 29664 The Challenger's Fires | MONSTER | 56038 | Blue Brazier lit | 75008 |
| 29664 The Challenger's Fires | MONSTER | 56040 | Violet Brazier lit | 75008 |
| 29703 Barrel of Monkies | MONSTER | 55148 |  | 0 |
| 29773 Wugou, the Spirit of Earth | MONSTER | 55545 | Spur the Ox Cart | 0 |
| 30027 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Handwrap | 0 |
| 30027 The Lesson of the Iron Bough | MONSTER | 57849 | Loot and Equip a second Trainee's Handwrap | 0 |
| 30033 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Spellblade | 0 |
| 30033 The Lesson of the Iron Bough | MONSTER | 57849 | Loot and Equip a Trainee's Hand Fan | 0 |
| 30034 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Crossbow | 0 |
| 30035 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Mace | 0 |
| 30035 The Lesson of the Iron Bough | MONSTER | 57849 | Loot and Equip a Trainee's Book of Prayers | 0 |
| 30036 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Dagger | 0 |
| 30036 The Lesson of the Iron Bough | MONSTER | 57849 | Loot and Equip a Second Trainee's Dagger | 0 |
| 30037 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Axe | 0 |
| 30037 The Lesson of the Iron Bough | MONSTER | 57849 | Loot and Equip a Trainee's Shield | 0 |
| 30038 The Lesson of the Iron Bough | MONSTER | 54139 | Loot and Equip a Trainee's Sword | 0 |
| 30817 The Healing of Shen-zin Su | MONSTER | 56011 | Protect the healers | 0 |
