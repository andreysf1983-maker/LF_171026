# Legion telemetry — logging system design

**Status:** session path implemented. Each `play.bat` start creates `server/logs/runs/<run>/`. Character login opens `sessions/<sess>/events.jsonl` and records login, NPC/gossip, item use, vendor buy, loot, gameobject use, spell cast, hotbar changes, quest accept/status/reward/kill credit, zone and map changes, and logout. `python tools/telemetry/story.py` prints the latest run. Companion, pet, bot, phase, and `ref.miss` catalog events are still design-only.
**Why:** every open item in [../stability/MASTER-INVENTORY.md](../stability/MASTER-INVENTORY.md) marked UNKNOWN is unknown because the server records nothing about it (root cause R6). This system makes every custom feature explain itself, so a bug report comes with a server-side trace.

Related: [DB-STITCHER.md](DB-STITCHER.md), which consumes this system's "reference miss" events.

---

## 1. Goals and non-goals

**Goals**

1. Any gameplay report ("my companion vanished", "summon does nothing", "double button") can be answered from logs alone.
2. One event format across C++ core hooks, custom scripts, tools and the launcher.
3. Every event is tied to a **session, character and object** so one player's story can be pulled out of a busy server.
4. Always-on at low cost; detail can be raised per system or per player at runtime without a restart.
5. Runs are never overwritten; each server start is a separate, dated record.

**Non-goals**

- Replacing LEGIONFORGE's existing `LF_LOG_*` logging. We build on it.
- Packet sniffing or client memory inspection.
- Analytics dashboards. A small report generator is enough for now.

---

## 2. What exists today (and why it failed us)

| Piece | Where | Problem found in the Sep 23 scan |
|-------|-------|----------------------------------|
| Loggers (`Logger.<name>=level,appenders`) | `worldserver.conf`, `common/Logging/` | `Logger.root=5` (error only). All custom code logs `DEBUG`/`WARN` on `scripts`, so nothing is written. |
| Levels | `LogCommon.h`: 0 disabled, 1 trace, 2 debug, 3 info, 4 warn, 5 error, 6 fatal | Fine |
| Appenders | Console, File, DB (`APPENDER_DB`, `LogCommon.h:36-39`) | `Server.log` uses mode `w` (overwritten each start); `DBErrors.log` appends with no run markers |
| Async writes | `Log` uses an io strand (`Log.cpp:33`) | Fine — cheap enough for always-on events |
| Custom scripts | `LF_LOG_DEBUG("scripts", ...)` free text | Unstructured, no GUIDs, no correlation, can't be filtered per system |
| Client logs | `client_/…/Logs/*.log` | Never collected alongside server logs |

---

## 3. Architecture

```
 ┌──────────── worldserver ─────────────┐
 │ Custom scripts / core hooks           │
 │   LLOG_EVENT(cat, evt, fields...)     │──┐
 │ LF_LOG_* (existing)                   │  │ same async Log pipeline
 └───────────────────────────────────────┘  │
                                            ▼
       ┌──────────── appenders ────────────────────────────┐
       │ events_<run>.jsonl     (structured, every event)  │
       │ Server_<run>.log       (human text, existing)     │
       │ DBErrors_<run>.log     (startup DB validation)    │
       │ legion_event_log table (optional, filtered subset)│
       └───────────────────────────────────────────────────┘
                                            │
                                            ▼
       ┌──────────── tools/telemetry/ ─────────────────────┐
       │ run_index.py      list runs, sessions, characters │
       │ story.py          one character's timeline        │
       │ report.py         per-run health report (md)      │
       │ repro_bundle.ps1  zip logs+DB snapshot+client logs│
       └───────────────────────────────────────────────────┘
```

Four layers:

| Layer | What | Section |
|-------|------|---------|
| L0 | Fix the existing config so nothing is lost (no code) | §4 |
| L1 | `LegionLog` structured event API | §5–§7 |
| L2 | Instrumentation points in every custom system and key core paths | §8 |
| L3 | Storage, retention, runtime control | §9–§10 |
| L4 | Tools that turn logs into answers | §11 |

---

## 4. L0 — config changes (day one, no code)

```ini
# every run gets its own dated files instead of overwriting
Appender.Server=2,3,0,Server_%s.log,w
Appender.DBErrors=2,2,0,DBErrors_%s.log,w
Appender.Scripts=2,2,7,Scripts_%s.log,w

Logger.scripts=2,Console Scripts
Logger.entities.pet=2,Console Server
Logger.spells=3,Console Server
Logger.entities.player.quest=3,Console Server
Logger.maps=4,Console Server
```

`%s` is replaced with a timestamp by `AppenderFile` (`APPENDER_FLAGS_USE_TIMESTAMP`, `LogCommon.h:48`). Flag `7` prefixes timestamp, level and logger name.

This alone would have answered W2 (warlock summon) and CMP6 (companion despawn) partly, but free text still can't be joined to characters reliably. Hence L1.

---

## 5. L1 — event model

One event = one JSON object per line in `events_<run>.jsonl`.

```json
{"ts":"2026-09-23T07:31:12.481Z","run":"20260923-073004","seq":18231,
 "lvl":"info","cat":"quest","evt":"credit",
 "acct":7,"char":1,"charName":"Archmagos","sess":"s-7-1695474604",
 "map":1,"zone":14,"area":362,"x":-618.4,"y":-4251.1,"z":38.7,"phase":[0],
 "obj":{"guid":"Creature-0-1-1-37989-12345","entry":37989,"name":"Swiftclaw"},
 "data":{"quest":24626,"objective":0},
 "src":"custom_quest_fixes.cpp:1"}
```

| Field | Required | Meaning |
|-------|----------|---------|
| `ts` | yes | UTC, millisecond precision |
| `run` | yes | Server start id (`YYYYMMDD-HHMMSS`); one per process |
| `seq` | yes | Monotonic per run; lets us order events emitted in the same millisecond |
| `lvl` | yes | trace / debug / info / warn / error / fatal |
| `cat` / `evt` | yes | Category and event name from the catalog (§8). Stable identifiers, never free text. |
| `acct`, `char`, `charName`, `sess` | when a player is involved | Session id = account + login time; lets us split two logins of the same character |
| `map`, `zone`, `area`, `x/y/z`, `phase` | when a world object is involved | Where it happened, including the active phase IDs |
| `obj` | when an object is involved | GUID, entry, name of the creature/GO/pet/item |
| `data` | per event | Event-specific fields; schema per event in the catalog |
| `src` | yes | `file:line` of the call site |

Rules:

- **Event names are a contract.** Tools key off `cat.evt`. Renames need a catalog version bump.
- **Reason codes, not prose.** For example `reason:"owner_not_on_map"`, never `"owner seems gone"`.
- **Every "decision" logs its outcome.** Hire attempted → `hire_ok` or `hire_denied{reason}`. No silent early returns in instrumented paths.
- **No secrets.** Never log passwords, session keys, account emails or IPs in events.

---

## 6. L1 — C++ API

New header `core/src/server/game/Telemetry/LegionLog.h`, with an implementation file next to it.

```cpp
LLOG_EVENT(level, "companion", "hire_denied",
    LLOG_PLAYER(player),
    LLOG_OBJECT(creature),
    LLOG_FIELD("reason", "cap_reached"),
    LLOG_FIELD("registryCount", count));
```

| Macro / helper | Purpose |
|----------------|---------|
| `LLOG_EVENT(level, cat, evt, ...)` | Builds the JSON line and hands it to the existing async `Log` pipeline on logger `legion.<cat>` |
| `LLOG_PLAYER(p)` | Adds account, character, session, map/zone/area/position/phases |
| `LLOG_OBJECT(o)` | Adds GUID, entry, name, and position if no player is attached |
| `LLOG_FIELD(k, v)` | Typed field (int, float, bool, string, GUID) |
| `LLOG_ENABLED(level, cat)` | Cheap check so expensive fields are only built when needed |

Implementation notes:

- Reuse `sLog->ShouldLog("legion.<cat>", level)` so `worldserver.conf` controls it like any other logger.
- Serialise with a small hand-written JSON writer (escape `"`, `\`, control characters). Avoid pulling in a new dependency.
- A dedicated appender type is not needed: route logger `legion.*` to a File appender named `Events` whose message is already the JSON line (no prefix flags).
- Session id is created in `WorldSession` at character login and stored on the session.

---

## 7. Levels policy

| Level | Use | Default |
|-------|-----|---------|
| error | Invariant broken, feature cannot continue (e.g. hired companion missing from registry) | on |
| warn | Degraded outcome the player will notice (summon produced no pet; hire denied) | on |
| info | Lifecycle milestones (hire, dismiss, despawn, instance fill summary, pet summon result, quest phase change) | **on** — this is the level that answers bug reports |
| debug | Per-decision detail (target scan results, spell choice) | off; raise per category |
| trace | Per-tick data (AI update loops) | off; only with per-player filter (§10) |

Throttling: any event emitted from an update loop must go through `LLOG_THROTTLED(key, ms, ...)`, which emits once per key per interval plus a `suppressed` count on the next emission.

---

## 8. L2 — event catalog and instrumentation points

Each row names the inventory item it resolves.

### 8.1 Session and environment

| Event | Where | Resolves |
|-------|-------|----------|
| `server.start` {build time, git state, conf path, key conf values, DB versions} | `World::SetInitialWorldSettings` | ENV1, ENV2 |
| `server.scripts_loaded` {count, custom script names} | after `ScriptMgr` load | ENV7, ADV1 |
| `session.login` / `session.logout` {char, level, map, pet, companions} | `WorldSession` | all |
| `session.map_change` {from, to, instanceId} | `Player` map change | CMP9, BOT8 |

### 8.2 Companions (ambient / hire)

| Event | Where | Resolves |
|-------|-------|----------|
| `ambient.spawn_batch` {zone, trigger, requested, spawned, skippedReason} | `TrySpawnAmbient` | AMB1-3 |
| `companion.hire_ok` / `hire_denied` {reason, registryCount, faction, summonType, timerMs} | `HireCompanion` | CMP1, CMP2, CMP7 |
| `companion.engage` {target, path: scan/owner_target/pvp, hostileToMe} | `UpdateAI` engage paths | CMP3, CMP4 |
| `companion.ability` {kind, method: set_health/spell/melee, amount, targetHp} (debug) | `DealScaledDamage`, heals | CMP5, CMP15 |
| `companion.unhire` {reason: owner_dead/owner_not_on_map/dismiss/died} | `UpdateAI`, `DismissCompanion`, `JustDied` | CMP8, CMP9, CMP12 |
| `companion.despawn` {reason: summon_timer_expired/logout/map_change, registryRemoved} | unsummon hook, `DespawnOwnedCompanions` | CMP6 |
| `companion.phase_mismatch` {ownerPhases, myPhases} (throttled) | companion update | CMP10 |
| `companion.persist` {op: save/update/delete, rows} | `DB_*` helpers | CMP11, CMP13 |
| `companion.restore` {dbRows, restored, skipped{reason}} | `RestoreCompanionForPlayer` | CMP13 |
| `companion.command` {cmd, reachedScript} | `OnChat`, plus a probe in the command parser for `.stay`-style commands | CMP17, CMP18 |

### 8.3 Class bots and instance fill

| Event | Where | Resolves |
|-------|-------|----------|
| `instance.fill_plan` {size, realPlayers, tier1, tier2a, needT/H/D} | `HandleInstanceEntry` | INS1, INS2 |
| `instance.fill_result` {spawned per role, failed{entry, reason}} | same | INS3 |
| `bot.hire` {role, level, faction, hp, ap} | `HireBot` | BOT2 |
| `bot.cast` {spell, target, result code, amount} (debug; aggregated per fight at info) | `TryBotSpell` + spell result hook | BOT3, BOT4, BOT6 |
| `bot.fight_summary` {duration, damageDone, healingDone, healTargets, deaths} | combat exit | BOT4-7 |
| `pvp.bot_spawn` {team, level, faction, aiName, reactState} | `SpawnBgBot`, after `AIM_Initialize` | PVP1, PVP2 |

### 8.4 Pets and class mechanics

| Event | Where | Resolves |
|-------|-------|----------|
| `pet.summon_cast` {spell, checkResult} | `Spell::CheckCast` for summon effects | W2 |
| `pet.summon_branch` {branch: teleport_existing/existing_dead/load_saved/create_new, petGuid} | `EffectSummonPet` | W2 (candidate A) |
| `pet.load` {petNumber, entry, displayId, level, result, failReason} | `Pet::LoadPetData` | W2, W3 |
| `pet.temp_unsummon` / `pet.temp_resummon` {cause: vehicle/taxi/mount, result} | `Player.cpp:27224-27258` | W2 (candidate B) |
| `spell.proc_default_no_trigger` {aura, script} (throttled) | proc handler | W6, N6 |

### 8.5 Spells, hotbar, level-up

| Event | Where | Resolves |
|-------|-------|----------|
| `levelup.learned` {level, spells[], source: spec/skill/quest} | `GiveLevel`, `LearnSpell` | S3, S4 |
| `hotbar.set` {button, action, source: client/server/createinfo, duplicateOf} | `HandleSetActionButton`, `AddActionButton` | S1, S2 |
| `hotbar.dedupe` {spell, removedButtons} | `RemoveDuplicateActionBarSpell` | S2 |

### 8.6 Quests and phasing

| Event | Where | Resolves |
|-------|-------|----------|
| `quest.status` {quest, old, new, script} | `Player::SetQuestStatus` / `SendQuestUpdate` | Q1 |
| `phase.change` {added[], removed[], trigger: quest/area/aura} | `PhasingHandler::OnConditionChange` | Q1, Q7, CMP10 |
| `quest.objective_credit` {quest, objective, type, source, amount} | credit functions | Q9-Q11 |
| `quest.objective_repeat` {quest, objective, count} (throttled) | `QuestObjectiveCriteriaMgr` | Q13 |
| `achievement.repeat_complete` {id, count} (throttled) | `PlayerAchievementMgr` | Q14 |

### 8.7 Reference misses (feeds the DB stitcher)

Whenever code looks something up and it isn't there, emit a structured miss instead of (or as well as) the existing text line:

| Event | Example source |
|-------|----------------|
| `ref.miss` {kind: creature_template/item/spell/gossip/text/script/phase/map, id, referencedBy, table} | `sObjectMgr->GetCreatureTemplate` null in scripts; `ScriptName` without script; SmartAI invalid spell |
| `ref.fallback` {kind, id, fallbackTo} | Core substitutes a default (e.g. unit_class 0 → Warrior) |
| `sql.rejected` {errno, statement fingerprint, table, column} | MySQL connection error path (ENV8) |

These are ingested by the stitcher as *runtime evidence* (see [DB-STITCHER.md §9](DB-STITCHER.md)).

---

## 9. L3 — storage and retention

| Store | Content | Retention |
|-------|---------|-----------|
| `server/logs/<run>/events.jsonl` | All enabled events | 14 runs or 2 GB, oldest pruned by launcher |
| `server/logs/<run>/Server.log`, `DBErrors.log`, `Scripts.log` | Existing text logs, per run | same |
| `server/logs/<run>/meta.json` | run id, build time, conf hash, git status, DB row counts | kept with run |
| `characters.legion_event_log` (optional) | `warn`+ events and all `session.*` | 30 days, purged at startup |

Table sketch (optional DB sink):

```sql
CREATE TABLE legion_event_log (
  id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  run_id    CHAR(15) NOT NULL,
  ts        DATETIME(3) NOT NULL,
  lvl       TINYINT UNSIGNED NOT NULL,
  cat       VARCHAR(32) NOT NULL,
  evt       VARCHAR(48) NOT NULL,
  char_guid BIGINT UNSIGNED NULL,
  obj_entry INT UNSIGNED NULL,
  payload   JSON NOT NULL,
  KEY k_char_ts (char_guid, ts),
  KEY k_cat_evt (cat, evt, ts)
);
```

The launcher (`play.bat`) creates `server/logs/<run>/` before starting `worldserver.exe` and writes `meta.json`.

---

## 10. Runtime control

GM commands (new command script `cs_legionlog.cpp`):

| Command | Effect |
|---------|--------|
| `.llog status` | Current level per `legion.*` category, events/sec, file path |
| `.llog level <cat> <level>` | Change a category level live (wraps `sLog->SetLogLevel`) |
| `.llog focus <character>` | Enable debug/trace **only** for events involving that character (filter checked in `LLOG_ENABLED`) |
| `.llog mark <text>` | Writes `session.mark` so a tester can bookmark "I pressed Summon Imp now" |
| `.llog snapshot` | Dumps the target's full state (companion registry entry, pet data, phases, action bar) as one event |

`.llog mark` is the most useful testing tool: testers mark the moment, and `story.py` shows everything around it.

---

## 11. L4 — tools

All under `tools/telemetry/`, Python like the existing DB2 tools.

| Tool | Output |
|------|--------|
| `run_index.py` | Table of runs: start/end, build, characters seen, error/warn counts per category |
| `story.py --char Archmagos [--run latest] [--around-mark]` | Chronological timeline for one character, human-readable, with the events from §8 |
| `report.py --run latest` | Markdown health report: companion lifecycle funnel (spawned → hired → persisted → restored), bot fight summaries, pet summon outcomes, hotbar duplicates, phase changes, top `ref.miss` IDs. Written to `docs/stability/generated/run-<id>.md`. |
| `repro_bundle.ps1` | Zips one run's logs, `meta.json`, a snapshot of the relevant `characters` rows and the client `Logs/` folder for sharing |

---

## 12. Performance budget

- Target: telemetry adds under 2% worldserver CPU at default levels with 1–5 players and full ambient/bot load.
- JSON is built only if `LLOG_ENABLED` passes; the write goes through the existing async strand.
- Update-loop events are throttled (§7). No `trace` without `.llog focus`.
- Measured by comparing tick time (`WorldDiff`) with telemetry on and off during a scripted 10-minute session.

---

## 13. Rollout

| Phase | Deliverable | Done when |
|-------|-------------|-----------|
| T0 | L0 config + launcher run folders | A run produces dated `Server/DBErrors/Scripts` logs that survive restart |
| T1 | `LegionLog.h` + session/server events + `.llog mark` | `story.py` shows login → mark → logout for a character |
| T2 | Pet + hotbar + level-up events | W2 and S1 reproduced and explained from logs alone |
| T3 | Companion + bot + instance + PvP events | Each CMP/BOT/INS/PVP item in MASTER-INVENTORY has a log-backed status |
| T4 | Quest/phase events + `ref.miss` + optional DB sink | Stitcher ingests runtime misses |
| T5 | `report.py` per run | Every test session produces `run-<id>.md` automatically |

---

## 14. Acceptance criteria

1. No UNKNOWN item in MASTER-INVENTORY remains unknown because of missing logs.
2. For any tester report with a `.llog mark`, the cause can be read from `story.py` output without attaching a debugger.
3. Restarting the server never destroys the previous run's logs.
4. Turning every `legion.*` category to `info` keeps the performance budget in §12.
