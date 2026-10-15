# Instancing & phasing guide

WoW uses several overlapping ideas. This doc separates them so we apply the **right** fix.

## Three layers

```
┌─────────────────────────────────────────────────────────────┐
│  OPEN WORLD (map 0 / continent)                              │
│  ├─ Normal layer (everyone sees same spawns)                  │
│  ├─ P09-PHASED: personal PhaseId (same XYZ, different layer) │
│  └─ P06-AREATRIGGER: invisible zones that fire scripts       │
├─────────────────────────────────────────────────────────────┤
│  P10-INSTANCE: separate map id (dungeon, scenario, raid)     │
│  └─ Own creature table spawns, instance scripts              │
├─────────────────────────────────────────────────────────────┤
│  P07-SCENARIO: criteria / progress bar (often + phase)       │
│  └─ May never change map — only UI + phased entities         │
└─────────────────────────────────────────────────────────────┘
```

## Decision tree

```
Quest objective mob not visible?
│
├─ Same map as player, Wowhead coords match?
│   ├─ YES → Check P09-PHASED (conditions type 26)
│   │         Check creature PhaseId / addon auras
│   │         Check P05 spawn-on-accept
│   └─ NO coords on different map → P10-INSTANCE (check map id)
│
├─ Quest uses progress bar or “Scenario” UI?
│   └─ P07 / P08 — criteria_tree + often P09 together
│
└─ Must ride NPC / escort to turn-in?
    └─ P12-ESCORT — SmartAI + phase exit on complete
```

## Phasing implementation (this core)

| Component | Table / API |
|-----------|-------------|
| Phase definition | `phase_name` (hotfix) / DB2 |
| Area → phase | `conditions` SourceType **26**, SourceGroup = **area id**, SourceEntry = area or 0 |
| Quest → phase | ConditionValue1 = **quest id**, types 9/28/8 |
| Apply to player | `PhasingHandler::OnConditionChange(player)` |
| Inherit on summon | Automatic on `SummonCreature` from player |

### Accept vs complete vs reward

Retail varies by quest. Document per quest in zone catalog **Notes**:

| Retail timing | Condition type | When to fire `OnConditionChange` |
|---------------|----------------|----------------------------------|
| Content appears on **accept** | 9 (quest taken) | QuestScript `QUEST_STATUS_INCOMPLETE` |
| Content hidden on **complete** | 28 (complete) ElseGroup | `QUEST_STATUS_COMPLETE` |
| Layer reset on **turn-in** | 8 (rewarded) | `QUEST_STATUS_REWARDED` |

**Project rule:** After turn-in, player should not remain stuck in dead phase (can’t see other players/NPCs).

## Instance quests vs phased open world

| | Phased open world (P09) | Instance (P10) |
|--|-------------------------|----------------|
| Map | Same continent map id | Different `map` column in `instance_template` |
| Other players | Often solo layer | Shared or solo instance |
| Fix focus | `conditions`, PhaseId | Map entrance, instance spawn, ScriptName |
| Exit | Phase clear on reward | `instance` exit portal / `instance_script` |

**Young and Vicious (24626)** is **not** an instance quest — it is **P05 + optional P09** on Echo Isles (map 1, zone 6453).

## Batch-fix strategy (avoid case-by-case forever)

### Phase 1 — Starter zones (exported)

For each zone in `docs/quests/zones/`:

1. Run audit: missing creature spawns for MONSTER objectives ([sql/16](../sql/16_quest_audit_queries.sql)).
2. Run audit: quests tagged P09 without matching `conditions` row (data gap).
3. Group by pattern:
   - All **P05** in zone → one QuestScript template parameterised by creature id + coords.
   - All **P09** with same `SourceGroup` phase id → one condition review.

### Phase 2 — Pattern scripts (C++ templates)

| Pattern | Template idea |
|---------|----------------|
| P05 | `QuestScript` base: spawn creature on accept, despawn on reward |
| P09 | QuestScript: `PhasingHandler::OnConditionChange` on accept + reward |
| P07 | Per-expansion criteria scripts (larger effort) |

Register `ScriptName` in SQL only for quests that fail after DB/phase fix.

### Phase 3 — Expansion packs

Add zones to export catalog by `QuestSortID` per leveling zone (BfA, Legion, etc.).

## Audit commands

See `sql/16_quest_audit_queries.sql`. Generated reports: [generated/AUDIT-SUMMARY.md](generated/AUDIT-SUMMARY.md), [generated/INSTANCED-QUESTS.md](generated/INSTANCED-QUESTS.md).

Regenerate:

```powershell
.\tools\generate_quest_audits.ps1
```

## External references

- [Wowhead quest 24626](https://www.wowhead.com/quest=24626/young-and-vicious) — capture / accept-button spawn behavior  
- [Warcraft Wiki — Young and Vicious](https://warcraft.wiki.gg/wiki/Young_and_Vicious) — chain order  

## Next after dungeon and raid scripts

The dungeon and raid script pass is in. Every journal dungeon and raid through Legion has a script name the server loads, on the right map. The check is `python tools/legion_db2/harden_instances.py`, and the result is [generated/INSTANCE-HARDENING.md](generated/INSTANCE-HARDENING.md).

That pass did not fill the instances. Anything that is not a playable dungeon or raid is off the Dungeon Finder and written up in the Empty set below. A map counts as playable when creatures are spawned and the boss scripts the loader calls actually contain the fight. A boss-count shell, an empty boss file, or a boss script that is still commented out does not.

Dungeon and raid placement stays deferred with the Empty set. The current pass is quests and the instances that are not dungeons or raids. Those maps are scenarios. The catalog is [generated/QUEST-INSTANCES.md](generated/QUEST-INSTANCES.md). `sql/stitch/009_scenario_instance_templates.sql` gives each real scenario an `instance_template` row so the map can be created. A scenario with no creature rows still opens empty. The quest link after that is per level, per quest, and per area: the step that pulls the player into the scenario, the moment they return to the open world, and the fight that never changes map.

Where a character can be teleported in, and where the return spell sends them, is [SCENARIO-LANDINGS.md](SCENARIO-LANDINGS.md). Only coordinates already stored in the 7.3.5 data are on that list. The way out is the spot the player was standing on when the enter spell fired. Maps that only have a floor file stay off the list until a square of that floor is chosen and written down. Moonglade (1534) has no floor file.

## Empty set of instances

This is the side list. These dungeons and raids are not offered in the Dungeon Finder. The Adventure Guide still lists them, because that journal is client data this server does not hotfix. Hand placement and the missing boss scripts are not current work.

`sql/stitch/004_hide_empty_instances.sql` removes the maps that have no creatures. `sql/stitch/008_hide_incomplete_instances.sql` removes the rest of this list.

### No creatures

| Map | Instance |
|-----|----------|
| 996 | Terrace of Endless Spring |
| 1001 | Scarlet Halls |
| 1007 | Scholomance |
| 1098 | Throne of Thunder |
| 1136 | Siege of Orgrimmar |
| 1208 | Grimrail Depot |
| 1448 | Hellfire Citadel |
| 1458 | Neltharion's Lair |
| 1493 | Vault of the Wardens |
| 1516 | The Arcway |
| 1530 | The Nighthold |
| 1648 | Trial of Valor |
| 1651 | Return to Karazhan |
| 1677 | Cathedral of Eternal Night |
| 1712 | Antorus |

### Boss-count shell only

Creatures are spawned. The instance script sets the Adventure Guide boss count and does not run the fights. A few councils inside these raids have a short spell timer from `sql/stitch/007_council_makeshift.sql`. That does not make the raid complete. Hans'gar & Franzok and Twin Ogron are in this group because their creatures have no spells.

| Map | Instance |
|-----|----------|
| 1004 | Scarlet Monastery |
| 1008 | Mogu'shan Vaults |
| 1009 | Heart of Fear |
| 1182 | Auchindoun |
| 1195 | Iron Docks |
| 1205 | Blackrock Foundry |
| 1209 | Skyreach |
| 1228 | Highmaul |
| 1358 | Upper Blackrock Spire |
| 1753 | Seat of the Triumvirate |

### Boss scripts missing or empty

The instance script loads, and some creatures are spawned. The boss files the loader calls are empty, or the boss `AddSC` lines are still commented out, so the dungeon is not a finished run.

| Map | Instance | What is already there |
|-----|----------|------------------------|
| 1456 | Eye of Azshara | Warlord Parjesh is scripted. The other bosses are not loaded. |
| 1477 | Halls of Valor | Hymdall is scripted. Odyn, Hyrja, Fenryr, and God-King Skovald are empty files. |
| 1520 | The Emerald Nightmare | Nythendra is scripted. The other loaded boss files are empty. |
| 1544 | Assault on Violet Hold | The boss scripts are not loaded. |
| 1571 | Court of Stars | The three boss files are empty. |
| 1676 | Tomb of Sargeras | Goroth is scripted. The other loaded boss files are empty. |

Maw of Souls, Black Rook Hold, and Darkheart Thicket stay in the finder. Their boss scripts are loaded and the fights are in those files. Older dungeons and raids whose boss scripts are loaded stay listed as well.

Boss-credit rows for a single spawned creature whose name matches the encounter are `sql/stitch/005_instance_encounter_credits.sql` and `sql/stitch/006_instance_encounter_credits_rest.sql`.

## See also

- [TAXONOMY.md](TAXONOMY.md) — pattern codes  
- [zones/6453-echo-isles-durotar.md](zones/6453-echo-isles-durotar.md) — full Echo Isles chain with tags  
