# Azuremyst Draenei (6456)

QuestSortID: **6456** | Level range: 1-12 | Exported: 2026-08-24

See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.

| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |
|----|-------|-----|------|------|----------|---------------|--------|
| 9278 | Welcome! | 1 | 0 | 0 | P02-COLLECT | 22888 | - |
| 9279 | You Survived! | 1 | 0 | 9280 | P00-UNKNOWN | - | - |
| 9280 | Replenishing the Healing Crystals | 1 | 9279 | 9409 | P02-COLLECT | - | - |
| 9369 | Replenishing the Healing Crystals | 1 | 0 | 9409 | P02-COLLECT | - | - |
| 9283 | Rescue the Survivors! | 2 | 9409 | 0 | P01-KILL | - | - |
| 9293 | What Must Be Done... | 2 | 10302 | 9294 | P02-COLLECT | - | - |
| 9371 | Botanist Taerix | 2 | 9409 | 10302 | P00-UNKNOWN | - | - |
| 9409 | Urgent Delivery! | 2 | 0 | 9283 | P02-COLLECT | 23568 | - |
| 10302 | Volatile Mutations | 2 | 9371 | 9293 | P01-KILL | - | - |
| 9294 | Healing the Lake | 3 | 9293 | 0 | P01-KILL, P05-ITEM-USE-CAPTURE | 22955 | - |
| 9799 | Botanical Legwork | 3 | 10302 | 0 | P02-COLLECT | - | - |
| 9303 | Inoculation | 4 | 10304 | 9309 | P01-KILL, P02-COLLECT, P05-ITEM-USE-CAPTURE | 22962 | - |
| 9305 | Spare Parts | 4 | 9294 | 9312 | P02-COLLECT | - | - |
| 10303 | The Blood Elves | 4 | 9309 | 9311 | P01-KILL | - | - |
| 10304 | Vindicator Aldar | 4 | 9294 | 9303 | P00-UNKNOWN | - | - |
| 37444 | Inoculation | 4 | 0 | 0 | P01-KILL, P02-COLLECT, P05-ITEM-USE-CAPTURE | 22962 | - |
| 37445 | Spare Parts | 4 | 0 | 0 | P02-COLLECT | - | - |
| 9309 | The Missing Scout | 5 | 9303 | 10303 | P00-UNKNOWN | - | - |
| 9311 | Blood Elf Spy | 5 | 10303 | 9312 | P01-KILL | - | - |
| 9312 | The Emitter | 5 | 0 | 0 | P00-UNKNOWN | - | - |
| 9798 | Blood Elf Plans | 5 | 0 | 0 | P02-COLLECT | 24414 | - |

## Pattern summary (this zone)

- **P00-UNKNOWN**: 5 quest(s)
- **P01-KILL**: 7 quest(s)
- **P02-COLLECT**: 11 quest(s)
- **P05-ITEM-USE-CAPTURE**: 3 quest(s)

## Objectives (implementation reference)

| Quest | Objective type | ObjectID | Description | StartItem |
|-------|----------------|----------|-------------|-----------|
| 9278 Welcome! | ITEM | 22888 |  | 22888 |
| 9280 Replenishing the Healing Crystals | ITEM | 22889 |  | 0 |
| 9283 Rescue the Survivors! | MONSTER | 16483 | Draenei Survivors Saved | 0 |
| 9293 What Must Be Done... | ITEM | 22934 |  | 0 |
| 9294 Healing the Lake | MONSTER | 88791 | Disperse the Neutralizing Agent | 22955 |
| 9303 Inoculation | MONSTER | 16534 | Nestlewood Owlkin inoculated | 22962 |
| 9303 Inoculation | ITEM | 22962 |  | 22962 |
| 9305 Spare Parts | ITEM | 22978 |  | 0 |
| 9311 Blood Elf Spy | MONSTER | 16522 |  | 0 |
| 9369 Replenishing the Healing Crystals | ITEM | 22889 |  | 0 |
| 9409 Urgent Delivery! | ITEM | 23568 |  | 23568 |
| 9798 Blood Elf Plans | ITEM | 24414 |  | 24414 |
| 9799 Botanical Legwork | ITEM | 24416 |  | 0 |
| 10302 Volatile Mutations | MONSTER | 16516 |  | 0 |
| 10303 The Blood Elves | MONSTER | 16521 |  | 0 |
| 37444 Inoculation | MONSTER | 16534 | Nestlewood Owlkin inoculated | 22962 |
| 37444 Inoculation | ITEM | 22962 |  | 22962 |
| 37445 Spare Parts | ITEM | 22978 |  | 0 |
