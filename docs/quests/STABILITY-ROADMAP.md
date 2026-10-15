# Quest stability roadmap

Goal: **stable quest progression from level 1 through Legion endgame** without hand-fixing ~29,000 quests individually.

## Reality check (full audit)

| Category | Count | Fix strategy |
|----------|------:|--------------|
| Kill objectives, no `creature` row (all levels) | 3,573 | **Most are not broken** - see classification below |
| After excluding dummy + deprecated | 3,431 | Filter credit bunnies / scenarios next |
| Credit bunny / script-only (classified) | ~1,774 | **Not** open-world spawn fixes |
| **Fixable** missing spawns | ~1,750 | Real world spawn or P05 gaps |
| P05 item-use + kill (L1-110 generated) | ~342 raw, filtered subset applied | **`legion_quest_item_target`** + generator |
| Phased quests (`conditions` type 26) | ~80+ | **`quest_generic_phase`** + core `SendQuestUpdate` |
| Criteria / progress bar (P07/P08) | ~600+ | Per-expansion C++ scripts (largest remaining effort) |
| Instance-only objectives (P10) | hundreds | Instance scripts / map spawns - never open-world spawn |

### Why "3,431 missing spawns" is not 3,431 bugs

Many rows are **credit bunnies**, **scenario actors**, or **class order hall** objectives (QuestSortID -403, -406, etc.). They intentionally have no open-world `creature` row. Fixing them means **scripts and phasing**, not adding spawns.

## Fix layers (in order)

```
Layer 1  Pattern engines (C++ + SQL)     -> fixes thousands at once
Layer 2  Data tables (legion_* SQL)       -> batch-config without recompile
Layer 3  Zone exports + audits            -> find what's left
Layer 4  Custom scripts (P07 scenarios)   -> expansion-by-expansion
```

## Layer 1 - Implemented / in progress

| System | File | What it fixes |
|--------|------|---------------|
| P05 item-use credits | `custom_quest_fixes.cpp`, `legion_quest_item_target` | Use quest item on target -> credit |
| Generic phasing | `quest_generic_phase`, `sql/19_quest_generic_phase.sql` | Phase refresh on all status changes |
| Spawn on accept (P05) | `quest_young_and_vicious` template | Accept-gated spawns |
| Core phasing | `Player::SendQuestUpdate` | Already calls `PhasingHandler::OnConditionChange` |

## Layer 2 - Tools

```powershell
# Full audits (all levels)
.\tools\generate_quest_audits.ps1 -FullMissingSpawns

# Generate P05 SQL from DB (review before apply)
.\tools\generate_p05_sql.ps1 -LevelMax 110

# Export ALL zone buckets (not just starters)
.\tools\export_quest_catalog.ps1 -AllStarterZones -ZoneIndex   # L1-12 done
# Next: -MaxLevel 110 -AllZones (add to export script)

# Apply SQL patches
.\apply_play_sql.ps1
```

## Layer 3 - Expansion rollout order

| Phase | Level range | Content | Status |
|-------|-------------|---------|--------|
| A | 1-12 | All racial starters | Catalogs exported (89 zones) |
| B | 1-20 | Early zones + audits | Audits run |
| C | 20-60 | Classic / Cata zones | P05 generator + spawn audits |
| D | 80-90 | MoP (Wandering Isle partial) | Phase scripts + zone scripts exist |
| E | 90-100 | WoD Draenor starters | P05 + instance intros |
| F | 100-110 | **Legion Broken Isles** | Priority for "stable Legion" |
| G | 110+ | Argus, allied races | Scenario-heavy (P07 backlog) |

## Layer 4 - Not auto-fixable

These need **dedicated C++** (track in `generated/backlog.md`):

- **P07/P08** - criteria trees, progress bars, scenario UI
- **P10** - dungeon/raid/scenario map scripts
- **P12** - escorts with paths
- **Class order halls** (-403 etc.) - phased scenarios

## Definition of done (stable)

- [ ] New character can complete **full starter zone** without stuck quests
- [ ] **Legion 100-110** leveling path completable (Broken Isles zones)
- [ ] P05/P09 patterns handled by engines, not one-offs
- [ ] Audit `fixable-missing-spawns` trends down each sprint
- [ ] Player-reported quest IDs get pattern tag + batch fix, not snowflake

## Workflow for any broken quest

1. Look up ID in `master-index.csv` or zone catalog
2. Read pattern tags (P01-P12)
3. Apply recipe from [TAXONOMY.md](TAXONOMY.md)
4. If P05 -> add row to `legion_quest_item_target`, regenerate if bulk
5. If P09 -> verify `conditions`; `quest_generic_phase` should cover most
6. If P07 -> add to backlog with criteria id; implement script when batching zone

See [README.md](README.md) for tool commands.
