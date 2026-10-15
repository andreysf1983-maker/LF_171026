# Quest pattern taxonomy

Every quest in the directory is tagged with one or more **pattern codes**. Fix the **pattern**, not just the quest — dozens of quests share the same implementation shape.

## How to use this

1. Player reports broken quest → look up quest ID in a [zone catalog](zones/README.md).
2. Read the **pattern tags** on that row.
3. Open the matching section below → follow the **fix recipe**.
4. If the pattern is missing from DB (spawn, phase, script), apply the recipe once; tag similar quests in the same zone.

## Pattern codes

| Code | Name | What the player does | Server depends on | Typical break |
|------|------|----------------------|-------------------|---------------|
| **P01-KILL** | Kill credit | Kill NPCs | `creature` spawn + loot/ kill credit | Mob not spawned, wrong phase, wrong faction |
| **P02-COLLECT** | Collect item | Loot or gather items | drop tables, GO spawn, item flags | Zero drop rate, missing GO |
| **P03-GAMEOBJECT** | Interact object | Click object | `gameobject` + script | Missing GO, wrong phase |
| **P04-TALKTO** | Speak to NPC | Gossip / talk objective | creature spawn + quest giver flag | NPC missing, wrong chain prev quest |
| **P05-ITEM-USE-CAPTURE** | Use item on target | Quest item on creature (lasso, leash) | `StartItem` + item script + creature SmartAI | **Target never spawns on accept**, item does nothing |
| **P06-AREATRIGGER** | Enter area | Walk into trigger zone | `areatrigger` + script / phase | AT missing, phase not applied |
| **P07-CRITERIA-SCRIPTED** | Scripted criteria | Scenario UI / hidden steps | `criteria_tree`, C++ script, scene | Script not implemented on core |
| **P08-PROGRESS-BAR** | Progress bar | Bar fills from kills/events | criteria + kill credit | Same as P07 |
| **P09-PHASED** | Personal phase | Same coords, different layer | `conditions` type **26**, `PhasingHandler` | Phase never applied on accept/complete |
| **P10-INSTANCE** | Dungeon map | Objectives inside instance | `instance_template`, map scripts | Wrong entrance, missing instance spawn |
| **P11-CUSTOM-SCRIPT** | Custom QuestScript | Accept/complete hooks | `quest_template_addon.ScriptName` | Script missing or not registered |
| **P12-ESCORT** | Escort / ride | NPC follows or player vehicle | EscortAI, vehicle spells | Path broken, dismiss on phase exit |

## Fix recipes (by pattern)

### P05-ITEM-USE-CAPTURE (e.g. Young and Vicious 24626)

**Symptoms:** Quest item works but target never appears; comments say “abandon and accept again.”

**Checklist:**

1. `quest_template.StartItem` → item exists in hotfix/DB.
2. Objective creature (`quest_objectives` type MONSTER) → template + **spawn OR summon on accept**.
3. `creature_template_addon.auras` → remove invisibility/blocking auras if always-on.
4. SmartAI on creature for spell click / item use (`event_type` 73, spell cast actions).
5. Add `QuestScript` on accept → personal `SummonCreature` if retail uses accept-gated spawn.

**Reference implementation:** `quest_young_and_vicious` in `custom_npcs.cpp`, SQL `15_young_and_vicious.sql`.

---

### P09-PHASED (personal layer, not a dungeon)

**Symptoms:** NPCs/objects visible on Wowhead coordinates but invisible in-game; works after certain quest step.

**Checklist:**

1. `conditions` where `SourceTypeOrReferenceId = 26` (phase area) and `ConditionTypeOrReference`:
   - **9** = quest taken (accepted)
   - **28** = quest complete
   - **8** = quest rewarded
2. Creature/GO `PhaseId` / `PhaseGroup` matches condition `SourceGroup`.
3. On accept/complete: `PhasingHandler::OnConditionChange(player)` from QuestScript if phase doesn’t auto-apply.
4. **Exit phase** on reward (condition ElseGroup or swapped phase id) — player should return to normal world after turn-in.

**Policy (project):**

| Event | Phase action |
|-------|----------------|
| Accept (if retail gates content) | Enter quest phase |
| Objective complete (if retail releases early) | Optional early exit |
| Turn-in / reward | Leave quest phase |

---

### P07-CRITERIA-SCRIPTED / P08-PROGRESS-BAR

**Symptoms:** Quest log updates but nothing happens in world; Legion+ starter zones often use this.

**Checklist:**

1. `quest_objectives.Type = 14` → find criteria id in `ObjectID`.
2. Search core scripts for criteria / scene id.
3. If no script: classify as **needs implementation** in [generated/backlog.md](generated/backlog.md), link Wowhead video/comments.

Often bundled with **P09-PHASED** — fix phase first, then criteria script.

---

### P10-INSTANCE

**Symptoms:** Quest marker points to area but instance entrance doesn’t work or mobs only inside dungeon.

**Checklist:**

1. `lfg_dungeon` / `instance_template` for map id.
2. Objectives: which steps are **inside** vs **outside** map.
3. Group policy: solo player should still enter via normal portal (project LFG bots separate).

---

### P01-KILL / P04-TALKTO (baseline)

**Checklist:**

1. Objective `ObjectID` → creature entry has row in `creature` table **or** is summoned by script.
2. `creature_queststarter` / `creature_questender` for chain.
3. `PrevQuestID` / `NextQuestID` in `quest_template_addon` for flow.
4. Faction / team flags on quest template.

---

## Objective type → DB enum

| Type | Enum | Pattern |
|------|------|---------|
| 0 | MONSTER | P01 |
| 1 | ITEM | P02 |
| 2 | GAMEOBJECT | P03 |
| 3 | TALKTO | P04 |
| 10 | AREATRIGGER | P06 |
| 14 | CRITERIA_TREE | P07 |
| 15 | PROGRESS_BAR | P08 |

Full enum: `QuestDef.h` → `QuestObjectiveType`.

## Tagging rules (export script)

The export tool (`tools/export_quest_catalog.ps1`) assigns tags automatically:

- Multiple tags allowed (e.g. `P05` + `P09` + `P11`).
- **P09-PHASED** if any `conditions` row links phase area to this quest id.
- **P11-CUSTOM-SCRIPT** if `quest_template_addon.ScriptName` is set.

Manual overrides: add a `## Notes` section at the bottom of a zone file after export.
