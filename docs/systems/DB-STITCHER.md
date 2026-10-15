# DB stitcher — reference integrity and repair system

**Status:** D0 is in. `python tools/legion_db2/export_stitch_sources.py` exports the §2 client tables plus taxi nodes, paths, path nodes, broadcast text, artifact appearances, and tact keys, then `overlay_hotfixes.py` lays matching hotfix rows over those CSVs (replace or insert by ID, then `hotfix_data` deletes). Checks pass: display 4449 present, 68486 absent, Durotar, quest 24626, phase group 10000, spell 14313, criteria tree 63736 removed, taxi path 6054, broadcast text 1, tact key 58. Locale translation tables are not copied; the English strings live on the base hotfix rows. The stitch store and rules are not started.

Dungeon and raid script names through Legion are loaded: blank MoP and WoD `instance_template.script` values are filled by `sql/stitch/003_instance_journal_shells.sql`, and `instance_journal_shells.cpp` registers those names. Neltharion's Lair, Vault of the Wardens, and Assault on Violet Hold now call the instance scripts that were already compiled. `python tools/legion_db2/harden_instances.py` reports no script pointed at the wrong map. The Empty set is the side list in `docs/quests/INSTANCING.md`: maps with no creatures, boss-count shells, and instances whose boss scripts are empty or not loaded. They are hidden from the Dungeon Finder by `sql/stitch/004_hide_empty_instances.sql` and `sql/stitch/008_hide_incomplete_instances.sql`. That work is deferred. Boss credit for a spawned creature whose name matches the encounter is `sql/stitch/005_instance_encounter_credits.sql`. Council fights that do have spells are `sql/stitch/007_council_makeshift.sql`. Dungeon and raid placement stays deferred. The current stitch is quests and scenario maps, which are the instances that are not dungeons or raids. `sql/stitch/009_scenario_instance_templates.sql` adds the missing `instance_template` rows. The catalog is `docs/quests/generated/QUEST-INSTANCES.md`.

**What "stitching" means here:** every thing the game shows the player — a quest, item, NPC, object, spell, dungeon, raid or piece of land — is assembled from rows spread across four databases, the client's DB2 files and the C++ script registry. **Stitching** resolves every one of those references and proves it points at something that exists *and* is the right kind of thing in the right place. **Restitching** proposes and applies repairs, then re-runs the check to prove the repair held.

Related: [LOGGING-SYSTEM.md](LOGGING-SYSTEM.md) (runtime "reference miss" events feed this), [../stability/MASTER-INVENTORY.md](../stability/MASTER-INVENTORY.md) (findings that motivate it).

---

## 1. Why we need it

The Sep 23 scan found problems that are all the same shape — something references something that is missing, wrong, or unreachable:

| Finding | What the reference is | What's wrong |
|---------|-----------------------|--------------|
| TPL1 | `creature_template.unit_class` → class | Value 0 isn't a class; core silently substitutes Warrior |
| TPL3 | `creature_template.modelid2` → display | Display 68486 doesn't exist ("can crash the client") |
| TPL4 | custom NPC → a way to meet it | No spawn, no summoner, no script creates it in the open world |
| ENV7 | `ScriptName` → C++ script | 295 names with no implementation |
| ENV9 | script → spell | Spell 58630 doesn't exist |
| Q2–Q5 | quest step → phased NPC set | The alternate-phase creatures don't exist |
| Q12 | quest objective → creature | ~1,750 objectives with no spawn and no known summoner |
| N5 | `disables.entry` 688 | Looks like the spell, is actually a quest — a *type* confusion |

Checking these one at a time is how the project got here. The stitcher checks **all** references, **all** the time, with the same rules.

---

## 2. Sources of truth

| Source | What lives there | How the stitcher reads it |
|--------|------------------|---------------------------|
| **Client DB2** (`server/data/dbc/enUS/*.db2`, build 25996) | Items (`Item`, `ItemSparse`), spells (`Spell*`), maps (`Map`, `MapDifficulty`), land (`AreaTable`, `WorldMapArea`), phases (`Phase`, `PhaseXPhaseGroup`), dungeons (`LFGDungeons`, `JournalInstance`, `JournalEncounter`, `DungeonEncounter`), displays (`CreatureDisplayInfo`), factions (`Faction`, `FactionTemplate`), criteria (`CriteriaTree`, `Criteria`), area triggers (`AreaTrigger`), skills (`SkillLine`, `SkillLineAbility`) | Export to CSV (extends `tools/legion_db2/`; about 22 tables already exported), load into the stitch store |
| **`hotfixes` DB** (334 tables) | Server-side overrides of DB2 rows (`broadcast_text`, `hotfix_data`, a few `spell*`, `item_sparse`) | Overlay: a hotfix row replaces the DB2 row with the same ID |
| **`world` DB** (223 tables) | Templates, spawns, quests, loot, vendors, gossip, SmartAI, conditions, phases, instances, LFG | MySQL, read-only, set-based queries |
| **`characters` DB** (126 tables) | Player-owned references (pets, companions, action bars, inventory, quest status) | MySQL, read-only |
| **`auth` DB** | Accounts/realms | Not stitched (no gameplay references) |
| **Script registry** | Names registered by `CreatureScript("…")`, `SpellScript`, `InstanceMapScript`, etc. | Two sources, compared: parse `core/src/server/scripts/**` for registration strings, and the startup log's `server.scripts_loaded` event (LOGGING-SYSTEM §8.1) |
| **Map geometry** | `server/data/maps`, `vmaps` | Point → zone/area lookup and height checks for spawns ("land" stitching), via a helper built on the existing map extractor code or a GM command batch |
| **Runtime evidence** | `ref.miss`, `ref.fallback`, `sql.rejected` events | Parsed from `events_<run>.jsonl` |

**Precedence when sources disagree:** hotfixes over DB2 for client data; `world` for server behaviour; the script registry decides whether a `ScriptName` is live; runtime evidence *raises the severity* of a static finding but never replaces it.

---

## 3. The model: entities and edges

Everything is loaded into one **reference graph**:

- **Entity** = one addressable thing: `quest:24626`, `item:52283`, `creature_template:39157`, `spawn:creature:123456`, `spell:688`, `map:1`, `area:362`, `phase:629`, `script:npc_quest_item_target`, `lfg:143`.
- **Edge** = one reference from a row column to an entity, with metadata: source table/column/row key, expected target *kind*, and a *role* (for example `quest_objective_kill`, `vendor_sells`, `spawn_of`).

A stitch rule says, for an edge: the target must **exist**, be the **right kind**, and satisfy **semantic constraints** (reachable, in the right place, right phase, right faction, right level band).

```
quest:24626 ──objective_kill──▶ creature_template:37989 ──spawned_by──▶ script:quest_young_and_vicious
     │                                   │
     └─start_item──▶ item:50053          └─display──▶ display:xxxxx (CreatureDisplayInfo)
```

The graph makes two things possible: **forward** ("what does quest 24626 need?") and **reverse** ("what breaks if creature 37989 is deleted?").

---

## 4. Domain stitch maps

Each table below is the edge catalog for one player-visible domain. `→` means "must resolve to". Every row becomes a rule (§5).

### 4.1 Quest

| From | → | Semantic checks |
|------|---|-----------------|
| `quest_template.ID` | exists in `QuestV2`/client cache (if exported) | Title matches `quest_template_locale`/client |
| `QuestSortID` (>0) | `area` / (<0) quest sort | Zone exists |
| `RewardNextQuest`, `quest_template_addon.PrevQuestID/NextQuestID/ExclusiveGroup` | `quest` | Chain has no cycles; prev/next are reciprocal; no chain step is disabled in `disables` type 1 |
| `StartItem`, `RewardItem1-4`, `RewardChoiceItemID1-6`, `ItemDrop1-4`, `RequiredItemId*` | `item` (DB2 + hotfix) | Quest items flagged as quest items; bind type sensible |
| `RewardSpell`, `SourceSpellID` | `spell` | Spell exists and is castable on the player |
| `RewardFactionID1-5`, `RewardTitle`, `RewardCurrency*` | faction / title / currency | exist |
| `quest_objectives` by `Type`: 0 kill → `creature_template`; 1 item → `item`; 2 GO → `gameobject_template`; 3 talk → `creature_template`; 5 spell → `spell`; 10 areatrigger → `areatrigger`; 14 criteria → `CriteriaTree`; 15 progress bar → objectives flagged part-of-progress-bar | Target **reachable**: spawned in world, or summoned by a spell/script/SmartAI, or a credit bunny with a crediting path (§6.2) |
| `creature_queststarter/questender`, `gameobject_queststarter/questender` | quest + template | Giver/ender is spawned, reachable, correct faction for the quest's allowed races |
| `quest_template_addon.ScriptName` | script registry | Script exists |
| `conditions` (source types 19/20 quest, 26 phase) | quest/phase/area | Phase conditions reference quests that exist and phases that exist |
| `quest_poi`, `quest_poi_points` | map/area | POI coordinates are on the quest's map and inside its zone |

### 4.2 Item

| From | → | Semantic checks |
|------|---|-----------------|
| any item reference (loot, vendor, quest, equip, createinfo, trainer reagents, SmartAI) | `Item` + `ItemSparse` (+ hotfix) | Item exists in the **client** data (server-only IDs show as "?" in-game) |
| `ItemSparse.SpellID*` (use spells) | `spell` | exists |
| `ItemSparse.StartQuestID` | `quest` | exists, not disabled |
| `npc_vendor.item`, `ExtendedCost` | item / `ItemExtendedCost` | vendor is spawned; cost exists |
| `*_loot_template.Item` (Reference=0) / `.Reference` | item / `reference_loot_template` | Reference chains terminate; no orphan templates ("isn't … referenced from loot, and thus useless", seen in `DBErrors.log`) |
| `creature_equip_template.ItemID1-3` | item | Real item (log already shows unknown equip items) |

### 4.3 NPC (creature)

| From | → | Semantic checks |
|------|---|-----------------|
| `creature.id` | `creature_template` | exists |
| `creature.map`, `zoneId`, `areaId`, `x/y/z` | map / area / geometry | Point is on the map, height within tolerance of ground, `zoneId/areaId` columns match the geometry lookup |
| `creature.PhaseId`, `PhaseGroup`, `phaseUseFlags` | `Phase`, `PhaseXPhaseGroup` | Phase exists; some condition or aura can actually put a player in it (otherwise the spawn is invisible forever) |
| `creature.spawnMask` / difficulty | `MapDifficulty` | Difficulties exist for that map |
| `creature_template.modelid1-4` | `CreatureDisplayInfo` + `creature_model_info` | Display exists client-side (TPL3) |
| `unit_class`, `faction`, `rank`, `type`, `family` | enums / `FactionTemplate` / `CreatureFamily` | Valid values (TPL1); faction appropriate for role (companions: not 35 once hired, TPL2) |
| `minlevel/maxlevel` | `creature_classlevelstats` | Base stats exist for each level (N3 check lives here) |
| `ScriptName` | script registry | Script exists (ENV7) |
| `AIName='SmartAI'` | `smart_scripts` rows | Rows exist; if rows exist, AIName is SmartAI |
| `smart_scripts` action params | spell / creature / text / waypoint / quest per action type | Each parameter resolves by type |
| `creature_text`, `gossip_menu`, `npc_text` | `broadcast_text` (hotfix) | Text exists |
| `npc_trainer` / `trainer_spell` | spell | Spell exists and is learnable by the trainer's class |
| `creature_template.KillCredit1-2` | `creature_template` | Credit target exists and is referenced by some quest objective |
| `vehicle_template_accessory`, `npc_spellclick_spells` | creature / spell | exist |
| Custom entries 9500000–9599999 | custom rule pack (§5.4) | Template sane; a way to meet it exists (TPL4) |

### 4.4 GameObject

Same as NPC for `gameobject` / `gameobject_template` / `gameobject_template_addon` / loot / quest starter/ender / `ScriptName` / phase, plus `gameobject_template.displayId` → `GameObjectDisplayInfo`, `Data*` fields by GO type (e.g. chest loot ID, spell caster spell, door linked trap).

### 4.5 Spell

| From | → | Semantic checks |
|------|---|-----------------|
| `spell_script_names.spell_id` + `ScriptName` | spell + script registry | Both exist; script's `Validate()` spells exist (startup log shows "did not match dbc effect data") |
| `spell_area.spell/area/quest_start/quest_end` | spell / area / quest | exist |
| `spell_linked_spell`, `spell_proc`, `spell_bonus_data` | spell | exist |
| `SpellEffect` summon / learn / trigger spell / kill credit MiscValue | creature / spell | Summoned creature exists; learn target exists |
| `disables` sourceType 0 | spell | ID is really a spell (**and** sourceType 1 IDs are really quests — N5) |

### 4.6 Dungeon / raid

| From | → | Semantic checks |
|------|---|-----------------|
| `instance_template.map` | `Map` (InstanceType dungeon/raid/scenario) | Map is instanceable |
| `instance_template.ScriptName` | script registry | Instance script exists (e.g. `instance_mogu_shan_vault` is missing) |
| `lfg_dungeon_template.dungeonId` + entrance coords | `LFGDungeons` / map / geometry | Coordinates are inside the right map (log: "contains coordinates for wrong dungeon 200") |
| `access_requirement` | map/difficulty, items, quests | exist |
| `areatrigger_teleport` | `AreaTrigger` + target map/coords | Trigger exists client-side (log: "AreaTrigger (ID: 2200) does not exist"); destination valid |
| Bosses: creatures with `boss_*` / `ScriptName` in the map | `DungeonEncounter` / `JournalEncounter` | Each encounter has a spawned boss with a live script; instance script knows the boss |
| Instance spawns | map difficulty | `spawnMask` matches `MapDifficulty` for that map |

### 4.7 Land (maps, zones, areas, phases, travel)

| From | → | Semantic checks |
|------|---|-----------------|
| every map/zone/area reference in any table | `Map` / `AreaTable` | exists; parent chain valid |
| `phase_area.AreaId/PhaseId` | area / phase | exist; at least one creature/GO uses the phase (otherwise it's an empty phase) |
| `terrain_swap_defaults`, `terrain_worldmap` | map / `WorldMapArea` | exist |
| `graveyard_zone`, `world_safe_locs` | area / coords | Graveyard reachable, on ground, right faction |
| `game_tele` | map / coords | On ground, inside map |
| `taxi_path` / nodes (hotfix) | map / coords | Nodes exist |
| **Phase coverage per starter zone** | creature/GO phases vs quest phase conditions | For every quest with phase conditions: the phases exist *and* contain the NPCs its objectives need (Q2–Q8) |

### 4.8 Player-owned (characters DB)

| From | → | Semantic checks |
|------|---|-----------------|
| `character_pet.entry`, `modelid`, `CreatedBySpell` | creature_template / display / spell | Display exists; summon spell still summons that entry (W3) |
| `character_action.action` (type 0) | spell known or learnable | Flags duplicates of the same spell on multiple buttons (S1) |
| `character_inventory` items, `character_queststatus` quests, `character_spell` | item / quest / spell | exist; not disabled |

---

## 5. Rules

### 5.1 Rule format

Rules live in `tools/stitcher/rules/*.yaml`, one file per domain.

```yaml
- id: NPC-DISPLAY-001
  domain: npc
  title: Creature template display must exist in client data
  edge: creature_template.modelid1..4 -> display
  check: exists
  ignore_when: "value == 0"
  severity: high
  why: Non-existent display IDs can crash the client (DBErrors: 'this can crash the client').
  fix_class: needs_review
  suggest: replace with first valid modelid on the same template, or the family default
```

```yaml
- id: QST-OBJ-REACH-001
  domain: quest
  title: Kill objective target must be reachable
  edge: quest_objectives(Type=0).ObjectID -> creature_template
  check: reachable      # spawn OR summon path OR credit bunny with credit path
  severity: blocker
  context: [quest.level, quest.sort, quest.phase_conditions]
  fix_class: data_missing
```

### 5.2 Check types

| Check | Meaning |
|-------|---------|
| `exists` | Target ID present in the target source (with hotfix overlay) |
| `kind` | Target is the expected type (spell vs quest vs creature — catches N5-style confusion) |
| `enum` | Value within a known enum (class, rank, faction template…) |
| `reachable` | A path exists for the player to meet the target (§6.2) |
| `located` | Coordinates resolve to the claimed map/zone/area and to ground |
| `phase_visible` | Some condition/aura can put a player in the target's phase |
| `reciprocal` | A → B implies B → A (quest prev/next, starter/ender pairs) |
| `acyclic` | No cycles (quest chains, reference loot) |
| `consistent` | Two sources agree (hotfix vs DB2 names; `creature.zoneId` vs geometry) |
| `script_live` | Name is registered by a compiled script **and** appeared in the last run's `server.scripts_loaded` |
| `custom` | Project-specific invariants (§5.4) |

### 5.3 Severity

| Severity | Meaning |
|----------|---------|
| blocker | Player progression stops (quest can't complete, dungeon can't start) |
| high | Visible breakage or crash risk (invalid display, invisible NPC, missing boss script) |
| medium | Wrong but playable (wrong faction on a flavour NPC, orphan loot template) |
| low | Hygiene (unused rows, stale locales) |
| info | Expected-by-design exceptions (credit bunnies, training dummies) — tracked, not failed |

### 5.4 Custom rule pack (project systems)

| Rule | Invariant |
|------|-----------|
| CUS-P05 | Every `legion_quest_item_target` row: creature exists, spawned, has `npc_quest_item_target`; quest exists and objective matches `credit_entry`; item matches `StartItem` |
| CUS-PHASE-SCRIPT | Every quest with `quest_generic_phase` actually has SourceType 26 conditions |

---

## 6. Semantic stitching (does it call what it's supposed to?)

Existence isn't enough: `creature_template:37989` can exist and still never be killable by the player.

### 6.1 Identity checks

- **Name agreement:** server names vs client/hotfix names for quests, NPCs and items. A mismatch usually means an ID was re-used or mis-typed (the "db calls the wrong thing" case).
- **Type agreement:** a column that expects spells gets a spell ID, not a quest or creature ID with the same number.
- **Level-band agreement:** quest level vs objective creature levels vs zone level range; flags objectives 20+ levels away from the quest.
- **Faction agreement:** quest allowed races vs giver faction vs objective creature hostility.

### 6.2 Reachability

A target is **reachable** if any of these hold, checked in order and recorded as the "reach path":

1. Spawned in `creature`/`gameobject`, on a map the quest can be done on, in a phase the player can be in.
2. Summoned by a spell that the quest grants, an item the quest gives, a SmartAI action, or a C++ script (script registry search for the entry ID).
3. Credit bunny: an entry with no spawn that is the `KillCredit1/2` of a spawned creature, the target of a `SPELL_EFFECT_KILL_CREDIT`, or granted by a script/SmartAI kill-credit action.
4. Instance-only: spawned only on instance maps, and the quest's POI/zone points at that instance (legitimate P10).

Unreachable targets become blockers with the evidence of what was searched.

### 6.3 Placement ("land")

For every spawn, look up map/zone/area from coordinates and compare with the row. Flag spawns underground, floating, out of map bounds, or tagged with the wrong zone. This also produces a per-zone census used by the phase coverage checks.

### 6.4 Phase coverage

For each quest with phase conditions, list the phases it switches on/off and the creatures/GOs in those phases. Compare with the objective targets and starter/ender NPCs. Output per starter zone: "quest N expects NPC set {…} in phase P; phase P contains {…}". This turns Q2–Q8 into a concrete worklist.

---

## 7. Restitching (repairs)

The stitcher never writes to the database directly. It produces **reviewable repair patches**.

### 7.1 Fix classes

| Class | Meaning | Output |
|-------|---------|--------|
| `auto_safe` | Deterministic, no gameplay judgement (e.g. drop orphan loot rows, fix `zoneId/areaId` columns from geometry, remove `SmartAI` AIName from templates with no rows) | SQL patch, may be applied in bulk after review |
| `needs_review` | Plausible fix with alternatives (replace invalid display, pick a class for a template) | SQL patch with each change commented and alternatives listed |
| `needs_script` | Only C++ can fix it (missing `ScriptName` implementation, P07 criteria) | Backlog entry with the referencing rows and the expected hook |
| `data_missing` | Required rows don't exist anywhere we have (phase NPC sets, missing spawns) | Worklist with coordinates/phases to source from reference data |
| `accept` | Known-good exception | Added to the exceptions file with reason and reviewer |

### 7.2 Patch format

`sql/stitch/<date>_<rule>_<domain>.sql`:

```sql
-- stitch run 20261001-101500 | rule NPC-DISPLAY-001 | fix_class needs_review
-- entity creature_template:9500090 (Aelindra) modelid2 68486 -> 0
-- evidence: display 68486 missing in CreatureDisplayInfo; DBErrors 'can crash the client'
-- alternatives: 47072 (current modelid1), family default
UPDATE `creature_template` SET `modelid2` = 0 WHERE `entry` = 9500090 AND `modelid2` = 68486;
```

Every statement:

- carries the run ID, rule ID, entity and evidence in a comment;
- is **guarded** by the old value (`AND modelid2 = 68486`) so re-applying is harmless and conflicts are visible;
- has a matching line in `sql/stitch/<date>_..._rollback.sql`.

### 7.3 Restitch loop

```
stitch (full) → report + patches → human review → apply (apply_play_sql -Stitch)
      ▲                                                   │
      └──────────── stitch (affected entities) ◀──────────┘
```

After applying, the stitcher re-runs the rules for every entity touched by the patch **plus everything that references it** (reverse edges). A patch counts as "held" only when its findings are gone and no new findings appeared on neighbours.

---

## 8. Architecture

```
tools/stitcher/
  stitch.py              CLI entry point
  sources/
    mysql_source.py      read-only world/characters/hotfixes snapshot (set-based SELECTs)
    db2_source.py        CSV exports of client DB2 (+ hotfix overlay)
    scripts_source.py    parse core/src/server/scripts for registrations; read last run's scripts_loaded
    geometry_source.py   point -> map/zone/area/height (batch helper)
    runtime_source.py    events_<run>.jsonl ref.miss / ref.fallback / sql.rejected
  graph/
    store.py             SQLite stitch store: entities, edges, findings, runs
    build.py             build edges from the domain maps (§4)
  rules/                 *.yaml rule catalog (§5)
  engine/
    checks.py            exists, kind, enum, reachable, located, phase_visible, ...
    reach.py             reachability search (§6.2)
    phase_coverage.py    §6.4
  repair/
    planners/            one planner per fix class
    patch_writer.py      guarded SQL + rollback
  report/
    markdown.py          docs/stitch/generated/*.md
    passport.py          one page per entity: everything it references and everything referencing it
    csv.py               machine-readable findings
  exceptions.yaml        accepted exceptions with reason + reviewer
```

**Store:** SQLite file `tools/stitcher/stitch.db` (rebuilt each full run). Tables: `run`, `entity(kind, id, source, name, attrs json)`, `edge(from_kind, from_id, role, to_kind, to_id, src_table, src_column, src_key)`, `finding(run, rule, severity, entity, edge, evidence json, fix_class, status)`.

**Scale:** about 380k creature spawns, 158k GO spawns, 110k creature templates, 29k quests, 1M+ locale rows. Loading is set-based (one SELECT per table), edges are built in Python dictionaries, checks run as SQL over the SQLite store. Target: full stitch under 10 minutes on the dev machine; incremental re-stitch of a patch under 30 seconds.

**Language:** Python 3 (matches `tools/legion_db2/`), `pymysql` for MySQL, PowerShell wrapper `tools/stitch.ps1` using the same `setup_tmp/mysql.cnf` as the other tools.

### 8.1 CLI

```powershell
.\tools\stitch.ps1 full                      # everything, all domains
.\tools\stitch.ps1 domain quest              # one domain
.\tools\stitch.ps1 entity quest:24626        # one entity + neighbours (passport)
.\tools\stitch.ps1 zone 6453                 # everything in Echo Isles
.\tools\stitch.ps1 plan --fix-class auto_safe
.\tools\stitch.ps1 verify sql\stitch\2026-10-01_NPC-DISPLAY-001_npc.sql
.\tools\stitch.ps1 diff --since last         # findings added/removed since previous run
```

---

## 9. Integration with the logging system

- `ref.miss` / `ref.fallback` events become findings with `source=runtime` and raise the matching static finding's priority ("seen in play").
- `server.scripts_loaded` is the authority for `script_live`.
- `sql.rejected` groups by table/column so ENV8 (1,917 rejected statements) becomes a concrete finding.
- The stitcher emits its own run summary so `report.py` can show "static findings vs runtime misses" side by side.

---

## 10. Outputs

| Output | Location |
|--------|----------|
| Per-run summary: counts by domain × severity × fix class, trend vs previous run | `docs/stitch/generated/SUMMARY.md` |
| Per-domain reports (quest, item, npc, gameobject, spell, dungeon, land, player) | `docs/stitch/generated/<domain>.md` + `.csv` |
| Per-zone reports (starter zones first) | `docs/stitch/generated/zones/<zoneId>.md` |
| Entity passports on demand | `docs/stitch/passports/<kind>-<id>.md` |
| Repair patches + rollbacks | `sql/stitch/` |
| Exceptions register | `tools/stitcher/exceptions.yaml` |

A passport, for example `quest-24626.md`, lists: its giver and ender (spawned? phase? faction?), each objective with its reach path, start/reward items (client-valid?), phase conditions and what they reveal, script and whether it's live, related runtime misses, and every open finding touching it.

---

## 11. Rollout

| Phase | Deliverable | Done when |
|-------|-------------|-----------|
| D0 | Full DB2 CSV export for the tables in §2 (extend `tools/legion_db2/`) | All referenced DB2 tables available locally with hotfix overlay |
| D1 | Store + sources + `exists`/`kind`/`enum` checks for NPC, item, spell | Reproduces TPL1, TPL3, ENV7, ENV9, N5 automatically |
| D2 | Quest domain + `reachable` + passports | Reproduces Q12 with reach paths; passport for 24626 is correct |
| D3 | Land: geometry, placement, phase coverage | Per-starter-zone phase worklists for maps 0, 1, 530 (Q2–Q8) |
| D4 | Dungeon/raid domain | Every instance has map, script, entrance, bosses status |
| D5 | Repair planners + guarded patches + restitch verify | One `auto_safe` batch applied and verified held |
| D6 | Runtime ingestion from telemetry | `ref.miss` counts appear in reports |
| D7 | Characters domain | Pet display/spell and action-bar duplicate checks (W3, S1) |

---

## 12. Acceptance criteria

1. Every finding in MASTER-INVENTORY that is a reference problem (TPL1-4, ENV7, ENV9, Q2-Q8, Q12, N5, W3, S1) is produced automatically by a named rule.
2. For any quest, item, NPC, dungeon or zone, a passport answers "does everything it needs exist, and can the player reach it?" in one page.
3. No repair is applied without a guarded patch, a rollback file and a passing re-stitch of the affected entities and their neighbours.
4. Running `stitch.ps1 diff --since last` after any database change shows exactly what that change fixed or broke.
