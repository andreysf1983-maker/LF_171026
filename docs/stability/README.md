# Stability docs — index and method

These documents are a **discovery inventory**, not a fix log. Every finding is labelled with a status and the evidence it rests on, so we stop repeating fixes that change nothing.

| Doc | What it covers |
|-----|----------------|
| [../PROBLEM-AREAS.md](../PROBLEM-AREAS.md) | Architecture-level overview. Cross-cutting root causes, why previous fixes did not stick, quests/phasing, spells/hotbar. **Read first.** |
| [WARLOCK-PET.md](WARLOCK-PET.md) | Summon Imp / big imp / Soul Leech. Corrects an earlier wrong theory. |
| [MASTER-INVENTORY.md](MASTER-INVENTORY.md) | Flat catalog of every finding with ID, status, evidence and how it was found. |
| [generated/](generated/) | Raw outputs of `tools/scan_stability.ps1`. |
| [../systems/LOGGING-SYSTEM.md](../systems/LOGGING-SYSTEM.md) | Design: structured telemetry so every UNKNOWN above can be answered from logs. |
| [../systems/DB-STITCHER.md](../systems/DB-STITCHER.md) | Design: reference-integrity checker and repair loop across world/characters/hotfixes, client DB2 and the script registry. |

---

## Status labels

| Label | Meaning |
|-------|---------|
| **WORKS** | Proven end to end by data, logs, or a complete code path with no gaps. |
| **SHOULD-WORK** | Implemented and the code path looks correct, but nothing at runtime proves it. Needs an in-game test. |
| **BROKEN** | Proven wrong by data, logs, or code. The doc says exactly how. |
| **BROKEN (inferred)** | Not observed directly, but follows from two or more verified facts. High confidence; still verify. |
| **NOISE** | A log line or audit result that *looks* like a failure but is not one. Listed so nobody chases it. |
| **UNKNOWN** | Not enough evidence either way. The doc says what evidence is missing. |

## Evidence tags

| Tag | Source |
|-----|--------|
| `[LOG]` | `server/Server.log` (last run, Sep 8 2026, overwritten each start) or `server/DBErrors.log` (appends across all runs, 15,260 lines) |
| `[PKT]` | Client packets recorded in `Server.log` (for example `CMSG_SET_ACTION_BUTTON`) |
| `[DB]` | Live MySQL `world` / `characters` queries |
| `[DB2]` | Client data dumps in `tools/legion_db2/*.csv` (Legion 7.3.5.25996) |
| `[CODE]` | Source file and line, for example `Player.cpp:16732` |
| `[INFER]` | Conclusion drawn from the tagged facts next to it |

---

## How this scan was done (Sep 23 2026)

1. **Confirmed what actually ran.** `Server.log` line 14 shows the server loaded `server/worldserver.conf` (not the `.dist`). The live config values for tutorials, ambient NPCs, dungeon fill and start spells match the `.dist`. `server/worldserver.exe` was built Aug 24 07:13, and all 13 modified source files are older than that. **Every fix made so far was compiled in and running during the Sep 8 session.** The problems below happened *with* those fixes active.
2. **Mined the logs.** Grouped `DBErrors.log` and post-startup `Server.log` by message pattern; pulled every line mentioning custom entries (95000xx), custom scripts, pets and action buttons.
3. **Read the live data.** Three test characters: Archmagos (Orc Warlock, level 8, Durotar), Qanath (Blood Elf Priest, level 3, Sunstrider Isle), Ignaias (Human Priest, level 3, Northshire). Their spells, skills, action bars, pets, companions and roster rows. All 36 custom creature templates.
4. **Traced code end to end** for each system, down into the core rules it depends on (faction/attack validity, threat, spell power, pet loading, phasing, chat command parsing, summon timers).
5. **Cross-checked client data** (DB2) for spell levels, skill-line grants and the damage/heal formulas of every class-bot spell.

## What we could not see (observability gap)

- `Logger.root=5` (errors only). All custom-script logging is `LF_LOG_DEBUG`/`LF_LOG_WARN` on the `scripts` channel, so **no companion, bot, or quest-fix activity is ever written anywhere**.
- Spell casts and pet loads are not logged at this level, so the exact reason a warlock summon fails cannot be read from logs.
- `Server.log` is overwritten on every start; `DBErrors.log` has no run separators.

Recommended log settings for the next test session (config only, not applied):

```ini
Logger.scripts=2,Console Server
Logger.entities.pet=2,Console Server
Logger.spells=2,Console Server
Appender.Server=2,2,0,Server_%s.log,w
```

## Re-run the scanners

```powershell
.\tools\scan_stability.ps1
.\tools\generate_quest_audits.ps1 -FullMissingSpawns
python .\tools\legion_db2\scan_levelup_spells.py
```
