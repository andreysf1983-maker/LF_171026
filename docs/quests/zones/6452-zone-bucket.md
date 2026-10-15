# Mulgore Tauren (6452)

QuestSortID: **6452** | Level range: 1-12 | Exported: 2026-08-24

See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.

| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |
|----|-------|-----|------|------|----------|---------------|--------|
| 14449 | The First Step | 1 | 0 | 14452 | P00-UNKNOWN | - | - |
| 14452 | Rite of Strength | 2 | 14449 | 24852 | P01-KILL | - | - |
| 14458 | Go to Adana | 2 | 24852 | 0 | P00-UNKNOWN | - | - |
| 24852 | Our Tribe, Imprisoned | 2 | 14452 | 14458 | P03-GAMEOBJECT | - | - |
| 14455 | Stop the Thorncallers | 3 | 14458 | 14461 | P01-KILL | - | - |
| 14456 | Rite of Courage | 3 | 14458 | 14459 | P02-COLLECT | - | - |
| 14459 | The Battleboars | 4 | 14456 | 14460 | P01-KILL | - | - |
| 14461 | Feed of Evil | 4 | 14455 | 14460 | P01-KILL, P05-ITEM-USE-CAPTURE | 49539 | - |
| 14460 | Rite of Honor | 5 | 0 | 24861 | P02-COLLECT | - | - |
| 23733 | Rites of the Earthmother | 5 | 24861 | 24215 | P00-UNKNOWN | - | - |
| 24215 | Rite of the Winds | 5 | 23733 | 0 | P00-UNKNOWN | 49652 | - |
| 24861 | Last Rites, First Rites | 5 | 14460 | 23733 | P01-KILL, P05-ITEM-USE-CAPTURE | 50465 | - |

## Pattern summary (this zone)

- **P00-UNKNOWN**: 4 quest(s)
- **P01-KILL**: 5 quest(s)
- **P02-COLLECT**: 2 quest(s)
- **P03-GAMEOBJECT**: 1 quest(s)
- **P05-ITEM-USE-CAPTURE**: 2 quest(s)

## Objectives (implementation reference)

| Quest | Objective type | ObjectID | Description | StartItem |
|-------|----------------|----------|-------------|-----------|
| 14452 Rite of Strength | MONSTER | 2952 |  | 0 |
| 14455 Stop the Thorncallers | MONSTER | 36697 |  | 0 |
| 14456 Rite of Courage | ITEM | 49535 |  | 0 |
| 14459 The Battleboars | MONSTER | 36696 |  | 0 |
| 14460 Rite of Honor | ITEM | 50473 |  | 0 |
| 14461 Feed of Evil | MONSTER | 36727 | First Trough | 49539 |
| 14461 Feed of Evil | MONSTER | 37155 | Second Trough | 49539 |
| 14461 Feed of Evil | MONSTER | 37156 | Third Trough | 49539 |
| 24852 Our Tribe, Imprisoned | GAMEOBJECT | 202112 | Braves Freed | 0 |
| 24861 Last Rites, First Rites | MONSTER | 38438 | Offering Placed | 50465 |
