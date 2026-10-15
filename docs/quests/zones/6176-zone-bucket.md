# Pandaren continuation (6176)

QuestSortID: **6176** | Level range: 1-12 | Exported: 2026-08-24

See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.

| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |
|----|-------|-----|------|------|----------|---------------|--------|
| 5841 | Welcome! | 1 | 0 | 0 | P02-COLLECT | 14647 | - |
| 24469 | Hold the Line! | 1 | 0 | 24470 | P01-KILL | - | - |
| 24470 | Give 'em What-For | 2 | 24469 | 24473 | P01-KILL | - | - |
| 24471 | Aid for the Wounded | 2 | 24469 | 0 | P01-KILL, P05-ITEM-USE-CAPTURE | 49743 | - |
| 24473 | Lockdown in Anvilmar | 2 | 24470 | 0 | P00-UNKNOWN | - | - |
| 24474 | First Things First: We're Gonna Need Some Beer | 2 | 24473 | 24475 | P02-COLLECT | - | - |
| 24475 | All the Other Stuff | 2 | 24474 | 24487 | P02-COLLECT | - | - |
| 24477 | Dwarven Artifacts | 2 | 24473 | 24486 | P02-COLLECT | - | - |
| 24486 | Make Hay While the Sun Shines | 2 | 24477 | 0 | P02-COLLECT | - | - |
| 3361 | A Refugee's Quandary | 3 | 24487 | 0 | P02-COLLECT | - | - |
| 24487 | Whitebeard Needs Ye | 3 | 0 | 182 | P00-UNKNOWN | - | - |
| 24489 | Trolling for Information | 3 | 24487 | 218 | P01-KILL | - | - |
| 182 | The Troll Menace | 4 | 0 | 0 | P01-KILL | - | - |
| 218 | Ice and Fire | 5 | 24489 | 24490 | P01-KILL | - | - |
| 24490 | A Trip to Ironforge | 5 | 218 | 24491 | P00-UNKNOWN | - | - |
| 24491 | Follow that Gyro-Copter! | 5 | 24490 | 24492 | P00-UNKNOWN | - | - |
| 24492 | Pack Your Bags | 5 | 24491 | 0 | P02-COLLECT | - | - |
| 24493 | Don't Forget About Us | 5 | 24491 | 0 | P00-UNKNOWN | - | - |

## Pattern summary (this zone)

- **P00-UNKNOWN**: 5 quest(s)
- **P01-KILL**: 6 quest(s)
- **P02-COLLECT**: 7 quest(s)
- **P05-ITEM-USE-CAPTURE**: 1 quest(s)

## Objectives (implementation reference)

| Quest | Objective type | ObjectID | Description | StartItem |
|-------|----------------|----------|-------------|-----------|
| 182 The Troll Menace | MONSTER | 706 |  | 0 |
| 218 Ice and Fire | MONSTER | 808 |  | 0 |
| 218 Ice and Fire | MONSTER | 37112 |  | 0 |
| 218 Ice and Fire | MONSTER | 946 |  | 0 |
| 218 Ice and Fire | MONSTER | 37507 |  | 0 |
| 3361 A Refugee's Quandary | ITEM | 10438 |  | 0 |
| 3361 A Refugee's Quandary | ITEM | 16313 |  | 0 |
| 3361 A Refugee's Quandary | ITEM | 16314 |  | 0 |
| 5841 Welcome! | ITEM | 14647 |  | 14647 |
| 24469 Hold the Line! | MONSTER | 37070 |  | 0 |
| 24470 Give 'em What-For | MONSTER | 37073 |  | 0 |
| 24471 Aid for the Wounded | MONSTER | 37079 | Wounded Coldridge Mountaineers Aided | 49743 |
| 24474 First Things First: We're Gonna Need Some Beer | ITEM | 49744 |  | 0 |
| 24474 First Things First: We're Gonna Need Some Beer | ITEM | 49745 |  | 0 |
| 24474 First Things First: We're Gonna Need Some Beer | ITEM | 49746 |  | 0 |
| 24475 All the Other Stuff | ITEM | 49747 |  | 0 |
| 24475 All the Other Stuff | ITEM | 49748 |  | 0 |
| 24477 Dwarven Artifacts | ITEM | 49749 |  | 0 |
| 24486 Make Hay While the Sun Shines | ITEM | 49751 |  | 0 |
| 24489 Trolling for Information | MONSTER | 37109 | Soothsayer Shi'kala Scouted | 0 |
| 24489 Trolling for Information | MONSTER | 37110 | Soothsayer Rikkari Scouted | 0 |
| 24489 Trolling for Information | MONSTER | 37111 | Soothsayer Mirim'koa Scouted | 0 |
| 24492 Pack Your Bags | ITEM | 49754 |  | 0 |
| 24492 Pack Your Bags | ITEM | 49755 |  | 0 |
| 24492 Pack Your Bags | ITEM | 49756 |  | 0 |
