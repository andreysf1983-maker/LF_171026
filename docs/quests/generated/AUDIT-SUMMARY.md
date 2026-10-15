# Quest audit summary

Generated: 2026-08-24 07:13

Raw outputs in this folder. Re-run: `.\tools\generate_quest_audits.ps1`

## Counts (levels 1-999)

| Metric | Count |
|--------|------:|
| Kill objectives with **no** `creature` row | 3573 |
| Excluding training dummy **44175** | 3484 |
| Excluding dummy + `[DEPRECATED]` titles | 3431 |
| Credit bunny / script-only targets | 1774 |
| **Fixable** missing spawns (real minus credit bunnies) | 1750 |
| P05 item-use capture (L1-20) | 45 |
| P05 item-use capture (L1-999) | 343 |
| Phased on accept (L1-15) | 5 |
| Criteria / progress bar (L1-12) | 1 |
| Instance-only kill targets (L1-30) | 54 |

## Training dummy (44175) - not broken spawns

Class starter **practice spell** quests use creature **44175** (Training Dummy).
These appear in the missing-spawn audit but are **expected** - dummy is spawned by the class
starter zone script, not the world `creature` table. Pattern: **P07-like** scripted hit.

## Top QuestSortIDs - fixable missing spawns

| QuestSortID | Fixable rows |
|-------------|-------------:|
| -403 | 258 |
| 7637 | 196 |
| 7543 | 104 |
| -401 | 76 |
| 7503 | 65 |
| 7541 | 59 |
| -406 | 47 |
| 7334 | 43 |
| 8701 | 42 |
| 7558 | 41 |
| 8574 | 33 |
| -324 | 32 |
| 8899 | 29 |
| 5840 | 23 |
| -344 | 22 |
| -380 | 18 |
| 6720 | 17 |
| 11 | 16 |
| -304 | 15 |
| 406 | 14 |
| -407 | 13 |
| -397 | 12 |
| 41 | 12 |
| 1519 | 12 |
| -421 | 12 |

## Top QuestSortIDs - real missing spawns

| QuestSortID | Missing objective rows |
|-------------|----------------------:|
| -403 | 511 |
| 7637 | 411 |
| -406 | 153 |
| 7543 | 138 |
| -401 | 133 |
| 8574 | 113 |
| 7541 | 109 |
| 7334 | 100 |
| 7503 | 99 |
| 7558 | 76 |
| -407 | 61 |
| -344 | 58 |
| 8701 | 55 |
| 6719 | 44 |
| 8899 | 40 |
| 7502 | 38 |
| 6941 | 38 |
| 3358 | 36 |
| -324 | 32 |
| 0 | 31 |
| 5840 | 30 |
| -182 | 28 |
| 6720 | 27 |
| 6662 | 26 |
| -373 | 25 |

## Top QuestSortIDs - all missing (incl. dummy)

| QuestSortID | Rows |
|-------------|-----:|
| -403 | 512 |
| 7637 | 411 |
| -406 | 153 |
| 7543 | 138 |
| -401 | 133 |
| 8574 | 113 |
| 7541 | 109 |
| 7334 | 100 |
| 7503 | 99 |
| 7558 | 76 |
| -407 | 61 |
| -344 | 58 |
| 8701 | 55 |
| 6719 | 46 |
| 8899 | 40 |

## Action priority

1. **Real missing spawns** in exported starter zones (see zone catalogs) - add `creature` rows or P05 spawn-on-accept.
2. **P05 capture** quests with `StartItem` - batch QuestScript template.
3. **P09 phased** accepts - verify `conditions` type 26 + `OnConditionChange` on reward.
4. **P10 instance-only** objectives - see [INSTANCED-QUESTS.md](INSTANCED-QUESTS.md); do not spawn on open world.
5. **44175** class quests - verify dummy spawn in class starter area only if players report stuck objectives.

## Files

| File | Contents |
|------|----------|
| `audit-missing-spawns-l1-999.txt` | All kill objectives without creature row |
| `audit-missing-spawns-real-l1-999.txt` | Excludes dummy + deprecated |
| `audit-fixable-missing-spawns-l1-999.txt` | Real minus credit bunnies |
| `audit-credit-bunny-l1-999.txt` | Script-only / invisible targets |
| `audit-p05-capture-l1-20.txt` | StartItem + kill objective |
| `audit-p05-capture-l1-999.txt` | P05 all levels in band |
| `audit-phased-starter-accept.txt` | Phase on quest accept |
| `audit-criteria-starter.txt` | Criteria tree / progress bar |
| `audit-instance-only-spawns-l1-30.txt` | Mobs only on instance maps |
| `quest-sortids-starter.txt` | QuestSortID buckets (L1-12) |
