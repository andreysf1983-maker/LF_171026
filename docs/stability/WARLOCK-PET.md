# Warlock pet — end-to-end analysis

Status labels and evidence tags: [README.md](README.md). Overview: [../PROBLEM-AREAS.md](../PROBLEM-AREAS.md).

## Correction to the previous version of this doc

The earlier version concluded "Summon Imp (688) isn't taught until level 5, so the warlock can't summon". **For the test character, that was wrong.**

- Archmagos (Orc Warlock) is **level 8** and has the Warlock skill line (849) at 40/40 `[DB character_skills]`.
- Summon Imp is granted by that skill line to any warlock at `SpellLevel` 5 or higher (`SkillLineAbility` 24651: skill 849, `AcquireMethod` 2 "learned on skill learn", `MinSkillLineRank` 1, class mask 256) `[DB2]`.
- The core learns it as a *dependent* spell (`Player::LearnSkillRewardedSpells`, `Player.cpp:24860-24901`). Dependent spells are **deliberately never written** to `character_spell` (`Player::_SaveSpells`, `Player.cpp:21621-21622`) and are relearned on every login (`UpdateSkillsForLevel` at load, `Player.cpp:18636`). So "688 isn't in `character_spell`" proves nothing.
- The saved pet proves it: `character_pet` row 1 is entry 416 "Azrai", **created by spell 688**, level 7 `[DB]`. Summon Imp was known and cast successfully at level 7.

The level-5 gate *is* real for **new warlocks at levels 1–4**: they have no pet at all since `sql/13_warlock_starter_pet.sql` removed the level-1 create-cast. That's a separate problem (W4 below).

---

## Pipeline: from "press Summon Imp" to a visible imp

| Stage | Code | Status | Notes |
|-------|------|--------|-------|
| 1. Spell known | skill 849 → `LearnSkillRewardedSpells` | WORKS for level 5+ | proved above |
| 2. Spell reachable | action bar / spellbook | **UNKNOWN** | Archmagos' saved bar: Shadow Bolt (232670), Corruption (172), Blood Fury (33702), Life Tap (1454). **No Summon Imp button** `[DB character_action]`. It should still be in the spellbook. |
| 3. Cast checks | `Spell::CheckCast`, `case SPELL_EFFECT_SUMMON_PET` (`Spell.cpp:5614-5631`) | SHOULD-WORK | If a pet already exists, a warlock is allowed to replace it (stuns the old pet first). Fails only if the player has a charm. |
| 4. Summon effect | `Spell::EffectSummonPet` (`SpellEffects.cpp:2747-2826`), `MiscValue` 416 `[DB2 SpellEffect]` | see §2 | Contains two **silent no-op branches** |
| 5. Load saved pet | `Player::SummonPet` → `Pet::LoadPetData` (`Player.cpp:28808-28894`, `Pet.cpp:103-340`) | SHOULD-WORK | Loads "Azrai" from `character_pet` because it matches creature 416 |
| 6. Appearance | `SetDisplayId(playerPetData->DisplayId)` (`Pet.cpp:194-195`) | **BROKEN** | Saved display 64799 is reused every summon (§3) |
| 7. Level/stats | Summon pets take the owner's level (`Pet.cpp:200-203`), `InitStatsForLevel` | SHOULD-WORK | |
| 8. Phase | `InheritPhaseShift` at load; later phase changes are propagated to controlled units (`PhasingHandler.cpp:382-385`) | WORKS | Pets, unlike companions, *do* follow phase changes |

---

## 1. "I can't summon" — status: BROKEN, cause UNKNOWN

The server log does not record spell casts or pet loads at the configured level, so the Sep 8 session has **no trace** of the failed summon `[LOG]`. These are the candidates, ranked by how well they match "nothing happens, no error".

### Candidate A — the game thinks the imp already exists (silent no-op)

`EffectSummonPet` does this when a pet is already out (`SpellEffects.cpp:2773-2800`):

- If the existing pet has the same entry (416), it **teleports the existing pet next to you and returns**. No new summon, no message.
- If the existing pet is dead, it **returns without doing anything** ("pet in corpse state can't be summoned").

If the imp object exists but you can't see it (behind you in terrain, stuck, or left in a bad state by a vehicle or phase transition), pressing Summon Imp appears to do nothing. **Best match to the symptom.**

### Candidate B — pet state left behind by a vehicle

Archmagos was in Durotar (zone 14, which includes the Echo Isles). The log shows the client querying the Swiftclaw vehicle (entry 37989) 15 times `[LOG]`, the Young and Vicious raptor. Entering a vehicle temporarily unsummons the pet and stores its number (`Player::UnsummonPetTemporaryIfAny`, `Player.cpp:27224`). Leaving should resummon it (`ResummonPetTemporaryUnSummonedIfAny`, `:27239-27258`). Our `quest_young_and_vicious` script summons Swiftclaw as a temporary creature (`custom_npcs.cpp:93`). If the vehicle exit or despawn path skips the resummon, the pet stays in a half-unsummoned state. **Plausible; needs a repro.**

### Candidate C — spell not found by the player

There's no Summon Imp button on the saved bar `[DB]`. After the first summon at level 7, a lost button looks like "can't summon". **Easy to rule out:** open the spellbook.

### Candidate D — level 1–4 warlocks (new characters)

For any *new* warlock below level 5, there is no Summon Imp anywhere: create-cast removed by `sql/13` (0 rows for spell 688 in `playercreateinfo_cast_spell` `[DB]`), and the skill grant waits for `SpellLevel` 5 `[DB2]`. **BROKEN, proven**, but it isn't what happened to Archmagos.

### How to settle it in one session

1. Enable `Logger.spells=2,Console Server` and `Logger.entities.pet=2,Console Server`.
2. On Archmagos: open the spellbook and confirm Summon Imp is there (rules out C).
3. Type `/dump UnitExists("pet")` in chat. If it returns true while no imp is visible, **Candidate A** is confirmed.
4. Cast Summon Imp and capture the client error text plus the new `Server.log` lines.
5. Ride Swiftclaw, dismount, then try again (Candidate B).

---

## 2. The big imp — status: BROKEN

| Fact | Evidence |
|------|----------|
| Template 416 (Imp) uses `modelid1 = 64799` (Legion model), level 5–5, class 8, HealthScalingExpansion 4 | `[DB world.creature_template]` |
| The classic small imp model 4449 exists in `creature_model_info` | `[DB]` |
| Saved pet Azrai stores `modelid = 64799` | `[DB characters.character_pet]` |
| Loading a saved pet always applies the saved display | `Pet.cpp:194-195` `[CODE]` |
| A brand-new pet (no saved row) takes the template display | `Player::SummonPet` → `Pet::Create` (`Player.cpp:28828-28836`) |

Both paths produce 64799. Changing only the template would not affect Azrai, and changing only the saved row would not affect new warlocks. Summon pets don't scale by level (family scaling only applies to hunter pets, `Pet.cpp:835-848`), so what you see is the model itself.

"It just procs" matches the summon being replayed automatically: saved pets are reloaded as the current pet on login, after taxis, and after vehicles (`Pet::LoadPetData` with `current = true`, `Player.cpp:27239-27258`). Nothing else casts or grants 688: there are no `spell_script_names`, `smart_scripts` cast actions, `spell_area` rows or quest `RewardSpell` entries for 688 or 112866 `[DB]`.

---

## 3. Soul Leech — status: SHOULD-WORK (log line is NOISE)

- `Server.log` from Sep 8 has **429** lines "HandleProcTriggerSpellAuraProc: Could not trigger spell 0 from aura 228974 proc" `[LOG]`. Spell 228974 is Soul Leech `[DB2]`.
- The aura has a script, `spell_warl_soul_leech_aura` (assigned in `spell_script_names` `[DB]`, `spell_warlock.cpp:876-915`).
- The script does the real work (computes the absorb and casts Soul Leech Absorb 108366) **inside `OnCheckProc`**, then returns `true`. The core then runs its default proc handler for the effect, which has no trigger spell, and logs the error.
- So the shield should apply. The error is a byproduct of doing work in a check hook without preventing the default action. Verify by watching for the absorb buff while fighting.

---

## 4. Summary of findings

| ID | Finding | Status |
|----|---------|--------|
| W1 | Summon Imp known at level 5+ (skill grant, not saved by design) | WORKS |
| W2 | Summon press does nothing on Archmagos | BROKEN, cause UNKNOWN (candidates A–C) |
| W3 | Big imp: display 64799 in template and saved pet row | BROKEN |
| W4 | New warlocks level 1–4 have no demon (create-cast removed, grant at 5) | BROKEN |
| W5 | No Summon Imp button on the saved action bar | UNKNOWN (possible cause of W2) |
| W6 | Soul Leech error spam; absorb likely applies | NOISE / SHOULD-WORK |
| W7 | Pet phase follows the owner | WORKS |
| W8 | No `pet_levelstats` table; pet stats come from class-level stats and game tables | Works as designed in this core |
| W9 | Deprecated warlock-pet teaching quests are disabled (e.g. 25137 "Warlock Pet Imp") | Info; `disables` entry 688 is a **quest** ID, not the spell |
