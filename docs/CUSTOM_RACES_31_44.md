# Кастомные расы 31..44: что мешало ядру и что изменено

> Legion 7.3.5 build 26124, кастомный клиент (UWoW-подобная сборка с контентом BfA).
> Патч: `patchkit/patch_core.py`, SQL: `sql/52_custom_races_31_44.sql`.

## 1. Симптом

`check_client_delta.ps1` показывает:

```
кастомные расы: 14 (31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44)
```

В клиенте раса видна в окне создания, но персонаж не создаётся, а в логе
worldserver:

```
Race (31) not found in DBC: wrong DBC files?
Wrong race 31 in `playercreateinfo` table, ignoring.
Account 1 tried to create character with unavailable race 31
```

## 2. Пять независимых блокираторов

| # | Где | Что мешало |
|---|-----|-----------|
| 1 | `SharedDefines.h` | `#define MAX_RACES 31` — расы 31..44 выходили за границу массивов `_playerInfo[MAX_RACES][MAX_CLASSES]` и отсекались проверкой `current_race >= MAX_RACES` |
| 2 | `SharedDefines.h` | `RACEMASK_*` собраны из `(1 << (race-1))` — при race ≥ 33 это сдвиг на величину ≥ ширины `int`, то есть **неопределённое поведение** и молчаливый 0 |
| 3 | `ObjectMgr::LoadPlayerCreateInfo` | обязательный `sChrRacesStore.LookupEntry(race)` — в серверном `ChrRaces.db2` (официальный 7.3.5) записей 31..44 нет, все строки `playercreateinfo` отбрасывались |
| 4 | `ObjectMgr::LoadRaceAndClassExpansionRequirements` | та же проверка → `_raceUnlockRequirementStore` без расы 31..44 → `HandleCharCreateOpcode` отвечает `CHAR_CREATE_FAILED` |
| 5 | `Player::TeamForRace / TeamIdForRace / setFactionForRace` | команда и `FactionID` читаются из `ChrRaces.db2`; для неизвестной расы возвращался `ALLIANCE`/`faction 0` + спам в лог |

## 3. Что сделано в ядре

* `MAX_RACES` поднят **31 → 45**, добавлены константы `RACE_CUSTOM_31..44`,
  `RACE_CUSTOM_FIRST/LAST`.
* Все `RACEMASK_*` переведены на **64 бита** (`UI64LIT(1) << (race-1)`), добавлены
  `RACEMASK_CUSTOM_PLAYABLE`, инлайн-хелпер `RaceMaskForRace(race)` и
  `RACEMASK_DB32_LIMIT` (граница 32 для масок, которые хранятся в `INT`-колонках БД).
  Скобки в `RACEMASK_HORDE` восстановлены (макрос подставляется в `a & RACEMASK_HORDE`).
* Введён **реестр кастомных рас** (`Player.cpp`, namespace `LegionForgeCustomRaces`):
  парсится один раз из `worldserver.conf`.

```ini
CustomRaces.Enable = 1
# raceId:team:baseRace
CustomRaces.Definitions = "31:ALLIANCE:1,32:HORDE:2,33:ALLIANCE:4,34:ALLIANCE:3,35:HORDE:5,36:HORDE:6,37:ALLIANCE:7,38:HORDE:8,39:HORDE:10,40:ALLIANCE:11,41:ALLIANCE:22,42:HORDE:9,43:NEUTRAL:24,44:ALLIANCE:27"
```

  `baseRace` — донор: из его записи `ChrRaces.db2` берутся `FactionID` и
  `MaleDisplayId/FemaleDisplayId`. Команда берётся из реестра, поэтому
  `TeamForRace` больше не гадает и не спамит.

* Новые публичные методы `Player`:
  `IsCustomRace(uint8)`, `GetCustomRaceBase(uint8)`, `GetCustomRaceTeam(uint8)`.
* `Player::IsValidRace` учитывает реестр (иначе `race 31+` считалась невалидной).
* `ObjectMgr`: проверки `LookupEntry` в загрузчиках `playercreateinfo`,
  `race_unlock_requirement` и «заполнение дыр» `player_levelstats` пропускают
  расу, только если её нет **и** в DBC, **и** в реестре. `displayId_m/f` берутся
  у расы-донора (иначе null-deref при старте).
* `racemask` в `playercreateinfo_spell_custom` / `playercreateinfo_cast_spell`
  читается как `uint64` (`GetUInt64`), сдвиг — `UI64LIT(1)`, формат лога —
  `UI64FMTD`.
* `CharacterHandler`: создание персонажа разрешено для рас реестра;
  проверки `raceMaskDisabled` (в т.ч. при смене фракции) переведены на
  `RaceMaskForRace`.
* `CriteriaHandler` / `ConditionMgr`: 64-битные маски, корректный каст в `%u`.

## 4. Что сделано в БД (`sql/52_custom_races_31_44.sql`)

1. `racemask`/`raceMask` → `BIGINT UNSIGNED` (условный `ALTER` через
   `information_schema`, идемпотентно).
2. Клонирование стартовых данных расы-донора: `playercreateinfo`,
   `player_levelstats`, `playercreateinfo_item`, `playercreateinfo_action`,
   `playercreateinfo_spell_custom`, `playercreateinfo_cast_spell`.
3. `race_unlock_requirement.expansion = 6` (Legion) для 31..44.
   Значение 7 (BfA) недопустимо: `GetMaxLevelForExpansion(7)` в этой ветке = 0.
4. Контрольный `SELECT` с числом строк на каждую расу
   (`createInfoRows = 0` ⇒ персонажа создать нельзя).

Откат: `sql/52_custom_races_31_44_rollback.sql`.

## 5. Порядок применения

```bat
rem 1. Пересобрать ядро (MAX_RACES - константа времени компиляции!)
build_server.bat

rem 2. Применить SQL в world
tools\mysql\server\bin\mysql.exe -uroot world < sql\52_custom_races_31_44.sql

rem 3. Проверить, что ключи появились в server\worldserver.conf
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1

rem 4. Запустить
play.bat
```

В логе worldserver после старта должно появиться:

```
>> Registered 14 custom client race(s) (ids 31-44) from CustomRaces.Definitions
```

## 6. Ограничения (честно)

* Маски рас в БД-колонках типа `INT UNSIGNED` (`spell_area.racemask`,
  `mail_level_reward.raceMask`, `quest_template.AllowableRaces`,
  `conditions.ConditionValue1`) физически не могут адресовать расы 33..44.
  Для этих механик расы 33+ ведут себя как «любые» (маска 0) — точечная
  привязка требует перехода колонок на `BIGINT` и правки соответствующих
  загрузчиков. `playercreateinfo_spell_custom` и `playercreateinfo_cast_spell`
  уже переведены на 64 бита этим патчем.
* Отображаемое имя/модель расы берёт **клиент** из своего `ChrRaces.db2`;
  серверный `ChrRaces.db2` подменять нельзя без проверки
  `tools\check_db2_build.ps1` (иначе `ASSERT` по `LayoutHash`).
