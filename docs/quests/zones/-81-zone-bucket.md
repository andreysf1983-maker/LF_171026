# Warrior class starter (-81)

QuestSortID: **-81** | Level range: 1-12 | Exported: 2026-08-24

See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.

| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |
|----|-------|-----|------|------|----------|---------------|--------|
| 3065 | Simple Tablet | 1 | 0 | 0 | P00-UNKNOWN | 6488 | - |
| 3112 | Simple Memorandum | 1 | 0 | 0 | P02-COLLECT | 9544 | - |
| 2383 | Simple Parchment | 3 | 25126 | 0 | P02-COLLECT | 12635 | - |
| 3091 | Simple Note | 3 | 24852 | 0 | P02-COLLECT | 9547 | - |
| 3095 | Simple Scroll | 3 | 26801 | 24969 | P02-COLLECT | 9546 | - |
| 3100 | Simple Letter | 3 | 0 | 26913 | P02-COLLECT | 9542 | - |
| 3106 | Simple Rune | 3 | 24473 | 24531 | P02-COLLECT | 9543 | - |
| 3116 | Simple Sigil | 3 | 28715 | 26945 | P02-COLLECT | 9545 | - |
| 9289 | Warrior Training | 3 | 0 | 0 | P00-UNKNOWN | - | - |
| 14013 | Charge | 3 | 14069 | 0 | P01-KILL | - | - |
| 24531 | Getting Battle-Ready | 3 | 3106 | 0 | P01-KILL | - | - |
| 24969 | Charging into Battle | 3 | 0 | 28651 | P01-KILL | - | - |
| 25147 | Charge | 3 | 2383 | 0 | P01-KILL | - | - |
| 25148 | Hone Your Holler | 3 | 0 | 0 | P00-UNKNOWN | - | - |
| 26913 | Charging into Battle | 3 | 0 | 28789 | P01-KILL | - | - |
| 26945 | Learning New Techniques | 3 | 0 | 28723 | P01-KILL | - | - |
| 26958 | Your First Lesson | 3 | 9289 | 0 | P01-KILL | - | - |
| 27020 | The First Lesson | 3 | 3091 | 0 | P01-KILL | - | - |
| 1502 | Thun'grim Firegaze | 10 | 1498 | 1503 | P00-UNKNOWN | - | - |
| 1503 | Forged Steel | 10 | 1502 | 0 | P02-COLLECT | - | - |
| 1666 | Marshal Haggard | 10 | 1665 | 1667 | P00-UNKNOWN | - | - |
| 1667 | Dead-tooth Jack | 10 | 1666 | 0 | P02-COLLECT | - | - |
| 1682 | Grey Iron Weapons | 10 | 1681 | 0 | P00-UNKNOWN | - | - |
| 1686 | The Shade of Elura | 10 | 1683 | 1692 | P02-COLLECT | - | - |
| 1692 | Smith Mathiel | 10 | 1686 | 1693 | P00-UNKNOWN | 6812 | - |
| 1693 | Weapons of Elunite | 10 | 1692 | 0 | P00-UNKNOWN | - | - |
| 1820 | Speak with Coleman | 10 | 1819 | 1821 | P00-UNKNOWN | - | - |
| 9582 | Strength of One | 10 | 0 | 10350 | P01-KILL, P02-COLLECT, P05-ITEM-USE-CAPTURE | 23925 | - |
| 10350 | Behomat | 10 | 9582 | 0 | P00-UNKNOWN | - | - |
| 1680 | Tormus Deepforge | 11 | 1678 | 1681 | P00-UNKNOWN | - | - |
| 1681 | Ironband's Compound | 11 | 1680 | 1682 | P02-COLLECT | - | - |
| 1821 | Agamand Heirlooms | 11 | 1820 | 1822 | P02-COLLECT | - | - |
| 1822 | Heirloom Weapon | 11 | 1821 | 0 | P00-UNKNOWN | - | - |

## Pattern summary (this zone)

- **P00-UNKNOWN**: 12 quest(s)
- **P01-KILL**: 9 quest(s)
- **P02-COLLECT**: 13 quest(s)
- **P05-ITEM-USE-CAPTURE**: 1 quest(s)

## Objectives (implementation reference)

| Quest | Objective type | ObjectID | Description | StartItem |
|-------|----------------|----------|-------------|-----------|
| 1503 Forged Steel | ITEM | 6534 |  | 0 |
| 1667 Dead-tooth Jack | ITEM | 6782 |  | 0 |
| 1681 Ironband's Compound | ITEM | 6800 |  | 0 |
| 1686 The Shade of Elura | ITEM | 6808 |  | 0 |
| 1686 The Shade of Elura | ITEM | 6809 |  | 0 |
| 1821 Agamand Heirlooms | ITEM | 7567 |  | 0 |
| 1821 Agamand Heirlooms | ITEM | 7568 |  | 0 |
| 1821 Agamand Heirlooms | ITEM | 7569 |  | 0 |
| 1821 Agamand Heirlooms | ITEM | 7566 |  | 0 |
| 2383 Simple Parchment | ITEM | 12635 |  | 12635 |
| 3091 Simple Note | ITEM | 9547 |  | 9547 |
| 3095 Simple Scroll | ITEM | 9546 |  | 9546 |
| 3100 Simple Letter | ITEM | 9542 |  | 9542 |
| 3106 Simple Rune | ITEM | 9543 |  | 9543 |
| 3112 Simple Memorandum | ITEM | 9544 |  | 9544 |
| 3116 Simple Sigil | ITEM | 9545 |  | 9545 |
| 9582 Strength of One | MONSTER | 17556 |  | 23925 |
| 9582 Strength of One | ITEM | 23925 |  | 23925 |
| 14013 Charge | MONSTER | 44175 | Practiced Charge | 0 |
| 24531 Getting Battle-Ready | MONSTER | 44175 | Practice Charge | 0 |
| 24969 Charging into Battle | MONSTER | 44175 | Practice Charge | 0 |
| 25147 Charge | MONSTER | 44175 | Practice Charge | 0 |
| 26913 Charging into Battle | MONSTER | 44175 | Practice Charge | 0 |
| 26945 Learning New Techniques | MONSTER | 44175 | Practice Charge | 0 |
| 26958 Your First Lesson | MONSTER | 44175 | Practice Charge | 0 |
| 27020 The First Lesson | MONSTER | 44175 | Practice Charge | 0 |
