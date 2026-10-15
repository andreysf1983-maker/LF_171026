# Quest directory

Pattern-based quest knowledge for Project Legion — **fix classes of quests, not one-offs forever**.

## Start here

| Doc | Purpose |
|-----|---------|
| [TAXONOMY.md](TAXONOMY.md) | Pattern codes (P01–P12) and **fix recipes** |
| [INSTANCING.md](INSTANCING.md) | Phasing vs dungeons vs scenarios — when to use which |
| [STABILITY-ROADMAP.md](STABILITY-ROADMAP.md) | Full-game stability plan by pattern and expansion |
| [../PROBLEM-AREAS.md](../PROBLEM-AREAS.md) | Blockers overview (phasing, spells, warlock) |
| [../stability/MASTER-INVENTORY.md](../stability/MASTER-INVENTORY.md) | **Full categorized problem list (Q/W/S/C/I/…)** |
| [../stability/WARLOCK-PET.md](../stability/WARLOCK-PET.md) | Warlock summon / imp discovery |
| [zones/README.md](zones/README.md) | Zone-by-zone quest catalogs (exported from DB) |
| [../QUEST_REFERENCE.md](../QUEST_REFERENCE.md) | DB tables, external links, audit SQL |

## Workflow

```
Player report → Find quest ID in zone catalog → Read pattern tags → Apply recipe from TAXONOMY
                                                      ↓
                                            Same pattern elsewhere in zone? Batch-fix
```

## Regenerate zone catalogs

From repo root (requires MySQL from `setup.bat`):

```powershell
# All starter zone buckets (auto-discover QuestSortIDs, levels 1-12)
.\tools\export_quest_catalog.ps1 -AllStarterZones -ZoneIndex

# Curated 9-zone export only
.\tools\export_quest_catalog.ps1

# One zone (QuestSortID from quest_template.QuestSortID)
.\tools\export_quest_catalog.ps1 -ZoneId 6453

# Pattern counts across exported zones
.\tools\export_quest_catalog.ps1 -AllStarterZones -PatternReport

# Full quest index (~29k rows CSV with pattern tags)
.\tools\export_quest_catalog.ps1 -MasterIndex

# Missing spawn + instancing audits
.\tools\generate_quest_audits.ps1
.\tools\generate_quest_audits.ps1 -FullMissingSpawns

# P05 item-use table seeds (review sql/generated_p05_item_targets.sql)
.\tools\generate_p05_sql.ps1 -LevelMax 110

# Apply world SQL patches (18, 19, generated P05 if present)
.\apply_play_sql.ps1
```

Output:
- `docs/quests/zones/<slug>.md` — per-zone catalogs
- `docs/quests/generated/master-index.csv` — all quests
- `docs/quests/generated/AUDIT-SUMMARY.md` — missing spawn audit
- `docs/quests/generated/INSTANCED-QUESTS.md` — phased + instance objectives

## Scope

| Bucket | Quest count (world DB) | Our approach |
|--------|------------------------|--------------|
| All quests | ~29,000 | **master-index.csv** + pattern taxonomy |
| Starter zones (1–12) | ~1,127 across ~55+ QuestSortIDs | **Full catalogs** via `-AllStarterZones` |
| Phased (`conditions` type 26) | audit in generated/ | Recipe P09 + [INSTANCED-QUESTS.md](generated/INSTANCED-QUESTS.md) |
| Item-use capture (`StartItem` + kill) | ~3,000 low-level | Prioritize P05 in starter zones |
| Criteria / progress bar | ~600+ | P07/P08 backlog |

We are **not** hand-writing 29k quest pages. We **are** building:

1. **Pattern recipes** — one fix template per interaction type  
2. **Zone catalogs** — every quest in a zone with tags + objective IDs  
3. **Audit SQL** — find missing spawns, missing phases, broken chains  
4. **Custom scripts** — only where pattern needs server hook (`P11`)

## Adding a zone to the catalog

Edit `$ZoneCatalog` in `tools/export_quest_catalog.ps1`:

```powershell
5999 = @{ Slug = "5999-my-zone"; Name = "My Zone (5999)"; LevelMax = 20 }
```

Re-run export. Commit the new markdown under `docs/quests/zones/`.

## Status legend (use in zone file Notes)

| Status | Meaning |
|--------|---------|
| `OK` | Verified in-game |
| `SCRIPT` | Custom script landed |
| `PHASE` | Phase conditions need work |
| `TODO` | Not tested / suspected broken |
| `RETAIL` | Behavior confirmed from Wowhead/wiki only |

## Related SQL

- `sql/16_quest_audit_queries.sql` — reusable diagnostics  
- `sql/15_young_and_vicious.sql` — example P05 + P11 fix  
