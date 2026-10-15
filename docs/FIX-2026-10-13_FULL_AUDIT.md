# LegionForge 7.3.5.26124 — Полный аудит и исправления 2026-10-13

Источник: полный клон `https://github.com/andreysf1983-maker/LF_131026.git` (4603 файла, ветка main, коммит 5bff0cc «Initial commit») + корневой `ОШИБКИ.txt` — лог worldserver rev.1 от 2026-10-12 21:23, **2293 строки**. Сервер в этом логе **не падает**: загрузка проходит критерии и сценарии, ошибки — данные и шум лога. Это отличает его от старых логов в `docs/FIX-2026-10-12.md` и `docs/AUDIT_LF_735_01.md`.

## Что было в логе (подсчитано построчно, не «на глаз»)

| Категория | Кол-во | Тип | Решение |
|---|---:|---|---|
| `spell_loot_template Entry N does not exist` (BFA-спеллы 253xxx–280xxx) | 227 | данные | SQL-100 SAFE-2 DELETE |
| `spell (Id: N) does not exist` привязки spell_script_names | 69 | данные | SQL-100 SAFE-3 |
| `_SpellScript::ValidateSpellInfo: Spell N does not exist` | 25 уникальных / 59 строк | данные | SQL-100 SAFE-4 |
| Condition Terrain Swap: карты нет в Map.db2 | 51 | данные | SQL-100 SAFE-5 |
| `item_loot_template ... useless` | 30 | данные | SQL-100 SAFE-9 |
| AreaTrigger нет в AreaTrigger.db2 | 21 | данные | SQL-100 SAFE-6 |
| SpellEffect invalid SpellID (304000–305010) | 20 подробно + итог 1609 | DB2 чужого билда | уже log+skip в ядре; лечить только чистым клиентом 26124 |
| Criteria unsupported type 213 | 20 подробно + пропуск | DB2 чужого билда | уже log+skip в ядре; не расширять enum фиктивно |
| SmartAI: существо не на SmartAI | 48 строк / 16 существ | данные+шум | агрегация в коде (10) + SQL-100 REVIEW-3 |
| ScriptName без C++-скрипта, Validate()/Effect mismatch спеллов | ~300 | контент/бэклог | НЕ удалять массово: сломает контент; разбор по одному (см. docs/audit/*_2026-10-12.csv) |
| criteria_data, gameobject_template_addon, disenchant, creature_formations, achievement_reward и др. | 2–19 каждая | данные | SQL-100 SAFE-7/8 + REVIEW-4 |

## Исправлено в коде (тот же класс, что краш Criteria 213: ASSERT на внешних данных)

Принцип проекта, теперь закреплён тестами: **любое значение из DB2/SQL/клиента как индекс или размер — проверка `if + LF_LOG_ERROR + continue/skip` ДО использования. ASSERT — только инварианты своего кода.**

| Файл | Было | Стало |
|---|---|---|
| `DataStores/DB2Stores.cpp` | `ASSERT(BATTLE_PET_SPECIES_MAX_ID >= rows)` — известный краш из CRASH-DIAGNOSIS | LF_LOG_ERROR + продолжение |
| `DB2Stores.cpp` | `ASSERT(MAX_DIFFICULTY >= rows)` | log + продолжение |
| `DB2Stores.cpp` | `ASSERT(NamesProfanity.Language < TOTAL_LOCALES)`, `ASSERT(Utf8toWStr(...))` x3 | проверка + skip записи |
| `DB2Stores.cpp` | `ASSERT(!(LocaleMask & ~mask))` | log + маскирование битов |
| `DB2Stores.cpp` | `ASSERT(PvPDifficulty.RangeIndex >= BG_BRACKET_ID_FIRST)` | log + skip (верхняя граница уже была исправлена ранее) |
| `DB2Stores.cpp` | `ASSERT(TaxiMaskSize >= ...)` и запись `sTaxiNodesMask[(ID-1)/8]` без проверки | log + guard `(!ID \|\| (ID-1)/8 >= TaxiMaskSize) continue;` — устранён потенциальный OOB-write |
| `Loot/LootMgr.cpp` | каждая сирота лута = строка ERROR (227+) | первые 20 + summary, ссылка на SQL-100 |
| `AI/SmartScripts/SmartScriptMgr.cpp` | «is not using SmartAI» x48 | первые 10 + suppressed-notice |
| `Conditions/ConditionMgr.cpp` | Terrain Swap/Map x51 | первые 10 + suppressed-notice |
| `.gitattributes` | только `* text=auto`, тест падал 1/13, после clone скрипты с LF | `*.bat/*.cmd/*.ps1 eol=crlf`, `normalize_scripts.py`: 54 файла -> CP866/CRLF и UTF-8-BOM/CRLF |
| `tools/check_build_freshness.ps1` | не включал новые файлы | добавлены LootMgr/SmartScriptMgr/ConditionMgr — старый EXE будет отклонён, нужна пересборка |
| `tools/audit_regressions.py` | 13 тестов | +4 теста (DB2 ASSERT, агрегация, SQL-100, fingerprint). Итого **17/17** |
| `sql/100_legionforge_error_fixes_26124_part2.sql` | в 99_* удаления были закомментированы — поэтому ошибки повторялись при каждом старте | SAFE-1..9 активны (идемпотентно), рискованное — в REVIEW с SELECT |

## Аудит похожих мест (проверено, исправления не требуются / уже сделано ранее)
- CriteriaHandler (type 213, таймеры), ScenarioMgr (sparse POI, глубина 41), DB2Stores FIX#5 (ChrClasses/CharSections/PowerType/PvpTalent/Talent), SpellMgr (SpellEffect индексы до resize), LFGMgr (агрегация LFG), ObjectMgr QUEST_OBJECTIVE_PROGRESS_BAR — присутствуют в коде и покрыты тестами.
- Оставшиеся ASSERT в game/ — в основном инварианты своего кода (тип объекта, grid state), не индексы из DB2. Полный список стоит перепроверять при каждом добавлении загрузки DB2/SQL.

## Что НЕ исправлено автоматически и почему
- DB2/ADB от другого билда (1609 SpellEffect, тип 213, BFA-подземелья): нельзя выдумывать спеллы/предметы/механики. Только извлечение из **своего чистого клиента 7.3.5 build 26124** (`extract_maps.bat`, `tools/check_db2_build.ps1`, `tools/legion_db2/audit_criteria_db2.py`).
- 280 ScriptName без скриптов и ~207 рассинхронов эффектов: это недостающий контент, а не мусор. Массовый DELETE сломает боссов/квесты.
- Безопасность: в репозитории публичный `server/bnetserver.key.pem` и GM-пароль по умолчанию из setup. Для продакшна: свой TLS (`tools/ensure_ssl_cert.ps1 -Force`), смена пароля после последнего setup, MySQL не наружу. Архив — не production-релиз.
- В Linux-сандбоксе нет Windows/MSVC, MySQL с игровыми базами, клиента и DB2/карт: **C++ не компилировался, вход в игру не доказан**. Обязательный шаг на Windows: `build_server.bat` -> `setup.bat` (применит SQL) -> `play.bat`, сверка что в логе нет ASSERT и остались только REVIEW/контентные предупреждения.

## Как не допускать впредь
1. Новое поле DB2/SQL как индекс массива — только с guard до первого чтения, тестом в `audit_regressions.py` и записью файла в `check_build_freshness.ps1`.
2. Цикл загрузки не логирует каждую плохую строку без лимита: first-N (10/20) + summary/suppressed.
3. Ошибка в логе = либо код-guard, либо строка в очередном `sql/NNN_*.sql` в том же коммите; закомментированные DELETE без применения запрещены (именно так 99_* не убрал шум).
4. Перед релизом: `python tools/audit_regressions.py -v` (17/17), `python -m unittest discover -s tools/legion_db2 -p test_audit_criteria_db2.py -v`, `git diff --check`, свежая сборка и smoke-test (вход, создание персонажа, достижения, сценарий, лут).
