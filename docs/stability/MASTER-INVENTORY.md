# Master inventory

Flat catalog of every finding from the Sep 23 2026 scan. Status labels and evidence tags: [README.md](README.md).
Narrative and root causes: [../PROBLEM-AREAS.md](../PROBLEM-AREAS.md). Details: [WARLOCK-PET.md](WARLOCK-PET.md).

Rows prefixed AMB, CMP, BOT, INS, and PVP describe the NPC bot system that has been removed. They are kept as a record of why that approach was dropped.

**How to use:** file every player report against an ID. The root-cause column (R1–R6, defined in PROBLEM-AREAS) groups findings that one change would fix together.

---

## ENV — Environment and observability

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| ENV1 | Server runs `server/worldserver.conf`; key values match `.dist` | WORKS | — | `Server.log:14` "Using configuration file"; key-by-key comparison `[LOG, conf]` |
| ENV2 | All 13 modified source files are older than the running binary (Aug 24 07:13), so every fix was live on Sep 8 | WORKS | — | file timestamps vs `worldserver.exe` |
| ENV3 | Quest/companion SQL patches are live (53 item-target rows, 35 scripted creatures, 24 phase-script quests, 24626 scripted, no 688 create-cast) | WORKS | — | `[DB]` counts |
| ENV4 | Custom scripts log below the configured level; nothing they do is recorded | BROKEN | R6 | `Logger.root=5`; scripts use `LF_LOG_DEBUG/WARN` `[conf, CODE]` |
| ENV5 | Spell casts and pet loads aren't logged | BROKEN | R6 | No cast/pet lines in Sep 8 `Server.log` despite a warlock session `[LOG]` |
| ENV6 | `Server.log` overwritten each start; `DBErrors.log` appends with no run markers | BROKEN | R6 | Appender modes `w` / append `[conf]` |
| ENV7 | 295 database `ScriptName`s have no C++ script (e.g. `instance_mogu_shan_vault`) | BROKEN | — | `DBErrors.log` "exists in database, but no core script found" `[LOG]` |
| ENV8 | 1,917 SQL statements rejected: empty string written into integer column `difficulty` | UNKNOWN | — | "Unhandled MySQL errno 1366" `[LOG]`; source statement not yet identified |
| ENV9 | `spell_gen_dungeon_credit` bound to spell 58630, which doesn't exist | BROKEN | — | 130 lines `[LOG]` |

## TPL — Custom creature templates (affects every AI system)

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| TPL1 | All 36 custom templates have `unit_class=0`, forced to Warrior at load (0 base mana) | BROKEN | R1 | 504 lines naming all 36 entries `[LOG]`; `creature_classlevelstats` class 1 mana 0 `[DB]` |
| TPL2 | All 36 use faction 35 (neutral to everything) | BROKEN | R1 | `[DB]` |
| TPL3 | `modelid2=68486` doesn't exist on 9500022, 9500038, 9500090 ("can crash the client") | BROKEN | R1 | 42 lines `[LOG]`; `[DB]` |
| TPL4 | Zero world spawns of any custom entry; captain and class bots unreachable outside instances | BROKEN | R1 | `creature` count 0 `[DB]` |
| TPL5 | `ScriptName`s correctly assigned | WORKS | — | `[DB]` |

## AMB — Ambient world NPCs

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| AMB1 | Spawn only on a real zone change; never at login | SHOULD-WORK (but surprising) | — | `npc_ambient_spawn.cpp:174-199` `[CODE]` |
| AMB2 | Once per zone per session, 120 s throttle | SHOULD-WORK | — | `:505-520`, `:680-684` |
| AMB3 | Placement avoids cliffs and water; faction-appropriate displays | SHOULD-WORK | — | `:62-105`, `:640-671` |
| AMB4 | 30-minute timed despawn | Works as designed for flavour NPCs; see CMP6 | R4 | `:630` |

## CMP — Hireable companions

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| CMP1 | Hire writes `character_companion` and registers in memory | SHOULD-WORK | — | `npc_ambient_ai.cpp:933`, `:1020` |
| CMP2 | Faction not changed on hire (stays 35) | BROKEN | R1 | no `setFaction` in ambient AI; class bots do it at `npc_class_bot.cpp:426` `[CODE]` |
| CMP3 | Target scans require `IsHostileTo(me)` → always empty | BROKEN | R1/R2 | `:351, 418, 541, 606, 709, 726` `[CODE]` + faction 35 |
| CMP4 | Only engages the owner's current target once the owner is in combat | SHOULD-WORK | — | `:756-765`; `Unit::Attack` has no faction check (`Unit.cpp:5582-5640`) |
| CMP5 | Role abilities use `SetHealth` damage that can't kill, adds no threat, and in the open world is scaled on the companion's own HP | BROKEN | R2 | `:81-97` `[CODE]` |
| CMP6 | 30-minute out-of-combat despawn of hired companions; in-memory entry left behind | BROKEN | R4 | `TemporarySummon.cpp:147-165`; summon type `npc_ambient_spawn.cpp:436,630` |
| CMP7 | Ghost entries count toward the 4-companion cap | BROKEN (inferred) | R4 | cap counts `s_companions` (`:911-925`) + CMP6 |
| CMP8 | Owner death permanently un-hires the companion for the session | BROKEN | R4 | `:170-178` |
| CMP9 | Owner map change un-hires; old-map companions orphaned; restore depends on DB | BROKEN | R4 | same-map owner lookup; `npc_ambient_spawn.cpp:134-158` |
| CMP10 | Companions don't follow the owner's phase changes | BROKEN (inferred) | R4 | `PhasingHandler.cpp:382-385` only updates controlled units; `ThreatManager.cpp:78` |
| CMP11 | Logout saves nothing (despawn happens before save) | BROKEN | R4 | `npc_ambient_spawn.cpp:160-172`, `:470-492` |
| CMP12 | Companion death deletes its DB row | Works as written (harsh) | — | `:1064-1065` |
| CMP13 | `character_companion` and `character_raid_roster` both empty | BROKEN (outcome) | R4 | `[DB]` 0 rows |
| CMP14 | Mobs never attack companions (tank can't tank; companions unkillable outdoors) | BROKEN | R1/R2 | `Creature.cpp:2282-2287` + `Unit.cpp:8063-8065` |
| CMP15 | Healing works numerically (`SetHealth`) | WORKS (limited) | R2 | `:100-105`, `:768-802` |
| CMP16 | Hire creates a party containing only the player | UNKNOWN impact | — | `:1010-1017` |
| CMP17 | Dot-commands may be swallowed by the core command parser | UNKNOWN (account permission not checked) | — | `Chat.cpp:466-474` |
| CMP18 | `.recall` collides with the core GM command (permission 520) | BROKEN for GM accounts | — | `[DB world.command]` |
| CMP19 | XP on kills; level-ups rescale stats | SHOULD-WORK | — | `npc_ambient_spawn.cpp:307-343`; `npc_ambient_ai.cpp:1079-1155` |

## BOT — Class bots

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| BOT1 | Only reachable through instance auto-fill | BROKEN (for world hiring) | R1 | TPL4 |
| BOT2 | Hire sets faction/level/gear/follow | SHOULD-WORK | — | `npc_class_bot.cpp:403-454` |
| BOT3 | Casting passes power checks (percent-of-base-mana cost becomes 0) | SHOULD-WORK (likely) | R1 | `Spell.cpp:6300-6336`, `Unit.cpp:9583-9590` |
| BOT4 | 47/50 direct damage/heal kit effects scale only on SP/AP; creature SP/heal power is aura-only, so ~1 per cast | BROKEN | R3 | DB2 SpellEffect scan of all 163 kit IDs `[DB2]`; `Unit.cpp:6801-6839, 7219-7259` |
| BOT5 | Attack-power abilities use creature AP (tanks/melee do damage) | SHOULD-WORK | R3 | `Unit.cpp:7061-7065` |
| BOT6 | Healers heal only the owner, never the tank bot or others | BROKEN (design) | R3 | `:561-568`, `:600-609`, `:772-781` |
| BOT7 | Casters and healers never melee, so BOT4 leaves them with no output | BROKEN (combined) | R3 | `:626-627`, `:718-719` |
| BOT8 | Owner on another map → bot dismissed/despawned | Works as written | — | `:684-688`, `:740-751` |
| BOT9 | Resurrects owner directly | WORKS | — | `:514-529` |

## INS — Instance auto-fill

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| INS1 | Seat math, leader-only fill, role minimums, raid DPS ratio | SHOULD-WORK | — | `npc_ambient_instance.cpp:83-103`, `:213-272` |
| INS2 | Tier 1 (companion replicas) and Tier 2a (roster) always empty | BROKEN (outcome) | R4 | CMP13 |
| INS3 | Summary line counts planned bots, not bots actually spawned | BROKEN (cosmetic) | — | `:274-290` |
| INS4 | Replica progress flushed on exit | SHOULD-WORK | — | `:20-41` |

## PVP — Battleground bots

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| PVP1 | `npc_bg_bot_AI` defined but never created | BROKEN | — | only occurrence is its definition, `npc_ambient_pvp.cpp:46-48` |
| PVP2 | `AIM_Initialize()` rebuilds the passive ambient AI (`REACT_PASSIVE`), undoing aggressive setup | BROKEN | — | `npc_ambient_pvp.cpp:234-237`; `npc_ambient_ai.cpp:56` |
| PVP3 | PvP faction and flags applied | WORKS | — | `:231-233` |

## ADV — Adventurer bot

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| ADV1 | Compiled and registered; no template uses it | BROKEN (dead code) | — | "does not have a script name assigned" `[LOG]`; `[DB]` |

## W — Warlock / pets

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| W1 | Summon Imp known at level 5+ via skill 849; never saved by design | WORKS | — | `[DB character_skills, DB2 SkillLineAbility]`; `Player.cpp:21621-21622` |
| W2 | Summon press does nothing on the level 8 warlock | BROKEN, cause UNKNOWN | R6 | player report; no cast logging; candidates in WARLOCK-PET §1 |
| W3 | Big imp: display 64799 in template 416 and in the saved pet row | BROKEN | — | `[DB]`; `Pet.cpp:194-195` |
| W4 | New warlocks level 1–4 have no demon | BROKEN | — | `sql/13` removed create-cast; `SpellLevel` 5 `[DB, DB2]` |
| W5 | No Summon Imp button on the saved bar | UNKNOWN | — | `[DB character_action]` |
| W6 | Soul Leech "could not trigger spell 0" (429 lines); absorb cast inside proc check | NOISE / SHOULD-WORK | — | `[LOG]`; `spell_warlock.cpp:886-908` |
| W7 | Pets follow owner phase changes | WORKS | — | `PhasingHandler.cpp:382-385` |
| W8 | Nothing auto-casts or grants 688 (SmartAI, spell_area, quest rewards, spell scripts) | WORKS (ruled out) | — | `[DB]` |

## S — Spells / hotbar / level-up

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| S1 | Client places a newly learned spell on a second button; server accepts | BROKEN | R5 | `CMSG_SET_ACTION_BUTTON` 589 → buttons 1 and 72 `[PKT]`; both priests have 589 on 1 and 72 `[DB]`; `MiscHandler.cpp:652` |
| S2 | Server dedupe runs inside `LearnSpell`, before the client's placement | BROKEN (wrong layer) | R5 | `Player.cpp:3405-3453` |
| S3 | Level-up learns only that level's spec spells | SHOULD-WORK | — | `LearnSpecializationSpellsForLevel` diff |
| S4 | GM multi-level jumps skip intermediate spec spells until relog | Risk | — | exact `SpellLevel == level` match |
| S5 | Override pairs (old + new spell on bar) at levels 10–14 | UNKNOWN | — | `scan_levelup_spells.py` `[DB2]`; no character that high |
| S6 | Tutorials suppressed when `Tutorial.AutoComplete=1` | SHOULD-WORK | — | `WorldSession.cpp` diff; live conf |

## Q — Quests and phasing

| ID | Finding | Status | Root | Evidence / how found |
|----|---------|--------|------|----------------------|
| Q1 | Phase refresh on every quest status change | WORKS | — | `Player.cpp:16732` |
| Q2 | Kalimdor: 6 of 60,691 creatures phased | BROKEN | data | `[DB]` |
| Q3 | Eastern Kingdoms: 422 of 70,065 phased | BROKEN | data | `[DB]` |
| Q4 | Outland/BE-Draenei starts (map 530): 0 phased | BROKEN | data | `[DB]` |
| Q5 | Pandaria (map 870): 0 phased | BROKEN | data | `[DB]` |
| Q6 | Lost Isles / Gilneas fully phased (reference) | WORKS | — | `[DB]` |
| Q7 | 87 phase areas, ~107 phase conditions, ~27–42 quests | BROKEN (coverage) | data | `Server.log:418` `[LOG, DB]` |
| Q8 | Both priests stalled at level 3 in unphased starters | BROKEN (outcome) | data | `[DB characters]` |
| Q9 | P05 item-use table + script (53 rows / 35 creatures) | SHOULD-WORK | — | `[DB]` |
| Q10 | Young and Vicious script assigned; Swiftclaw vehicle seen in log | SHOULD-WORK | — | `[DB, LOG]` |
| Q11 | Lazy Peons covers 5441 / 25134 / 37446 | SHOULD-WORK | — | `zone_durotar.cpp` |
| Q12 | ~1,750 kill objectives without world spawns after removing credit bunnies/dummies | BROKEN (candidates) | data | `docs/quests/generated/AUDIT-SUMMARY.md` |
| Q13 | Objective 279097 (quest 39242) "completed" 35× by each priest who doesn't have the quest | UNKNOWN | — | `[LOG]` |
| Q14 | Achievement 522 "completed" 23× by each priest in one session | UNKNOWN | — | `[LOG]` |

## N — Noise (looks broken, isn't)

| ID | Log / audit line | Why it's noise | Evidence |
|----|------------------|----------------|----------|
| N1 | "Quest N objective M has unhandled type 15" (2,834 lines) | Startup validator lacks a case; runtime handles progress bars | `ObjectMgr.cpp:4408` vs `Player.cpp:17592` |
| N2 | "Could not load MMAP …" (73 lines) | Tile was already loaded; files and headers are valid | `MMapManager.cpp:147-149`; tile headers checked |
| N3 | "Missing base stats for creature class 1 level 220" | Startup check over core templates, not our creatures | `ObjectMgr.cpp:9428-9435` |
| N4 | "Script named 'npc_ambient_ai' does not have a script name assigned" | From runs before the SQL patch; live DB is assigned | `[DB]` |
| N5 | `disables` row with entry 688 | It's a **quest** ID ("Myzrael's Allies"), not the Summon Imp spell | `[DB]` sourceType 1 |
| N6 | Soul Leech "could not trigger spell 0" | See W6 | |
| N7 | 1,774 "missing spawn" credit bunnies / script-only targets | Designed to have no world spawn | quest audits |

## X — Not yet scanned

| ID | Area | What evidence is needed |
|----|------|-------------------------|
| X1 | Other class pets (hunter, DK, mage water elemental) | pet/spell logging during a hunter session |
| X2 | Level 10+ spell overrides on the bar | a character at 10–14 |
| X3 | Dungeon boss scripts vs ENV7 missing scripts | map ScriptName list to instances |
| X4 | Battleground/arena queue flow without bots | test session |
| X5 | Garrison / class hall flow | test session |
| X6 | World quests, emissaries, Broken Shore / Argus | test session |
| X7 | Economy, mail, AH, guild | test session |
| X8 | Client-side Lua errors (`client_/…/Logs/FrameXML.log`) | read client logs after a session |
