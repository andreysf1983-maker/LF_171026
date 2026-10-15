# LEGIONFORGE — фикс «worldserver не подтвердил готовность» + добивка DBErrors.log

Дата: 2026-10-13. Основано на фактических логах этого клона: `ОШИБКИ.txt`,
`DBErrors.log` (628 строк), `Server.log` (1641 строка).

## 1. Корневая причина «сервер не запускается»

**Сервер запускался успешно.** В `Server.log:1178` присутствует строка
`(worldserver-daemon) ready...`, а в `Server.log:1177` — `World initialized in
3 minutes 44 seconds`. Ложный отказ давал лаунчер:

1. `play.bat` запускал `wait_world_ready.ps1` ровно ОДИН раз сразу после
   `start worldserver.exe`. Загрузка 240 DB2-хранилищ + мира занимает 1–4
   минуты, поэтому проверка всегда выполнялась слишком рано.
2. Внутри скрипта использовался битый regex:
   `-match "worldserver-daemon\\) ready"` — это литеральный обратный слэш и
   незакрытая скобка; в .NET такое выбрасывает ArgumentException, скрипт
   завершался с ошибкой до проверки порта. Исключение не перехватывалось.
3. Проверка «хвоста» брала последние 8000 символов лога, но строка `ready...`
   немедленно утопала в флуде `possible cheater` (боты не отвечают на
   CMSG_TIME_SYNC_RESP, строка печаталась каждые 10 с на каждого бота).

### Что сделано

* `wait_world_ready.ps1` переписан: поллинг до `-TimeoutSec` (900 с по
  умолчанию) каждые 3 с; литеральный `.Contains("worldserver-daemon) ready")`
  вместо regex; хвост лога 256 KiB; readiness = строка ready **или** LISTENING
  на 8085; детект падения процесса (`worldserver` отсутствует, ready не
  найден) со статусом `crashed` и выводом последних строк лога; коды выхода
  0/1/2 и совместимый CLI (`-ProgressOnly`) — вызов в `play.bat` не менялся.
* `Player.cpp::SendTimeSync` — предупреждение «possible cheater» теперь
  печатается ОДИН раз на эпизод рассинхронизации (`size() == 4` вместо
  `> 3`), флуд лога устранён. Требуется пересборка: `build_server.bat`.
  Без пересборки сервер полностью работоспособен — меняются только логи.

## 2. DBErrors.log — остаточные ошибки (все построчно закрыты)

Файл `sql/101_legionforge_dberrors_fixes.sql` (подключён в манифест
`apply_play_sql.ps1`, идемпотентен, применяется на каждом старте):

| # | Строка DBErrors.log | Правка |
|---|---------------------|--------|
| DBE-1 | Creature 900100..900103 без display id | `modelid1=11686` |
| DBE-2 | 9500100 unit_class=0 | `unit_class=1` (persist) |
| DBE-3 | 29264 Spell1=58859 | `spell1=0` |
| DBE-4 | CONTROL_VEHICLE 46598 в addon.auras (42010/41366/43273/43279) | удалён из `auras` |
| DBE-5 | idle-креатуры с spawndist≠0 | `spawndist=0` |
| DBE-6 | Quest 24974 RewardSpellCast=73435 | `=0` |
| DBE-7 | Quests 39733/44555 без EXPLORATION_OR_EVENT | `SpecialFlags |= 0x2` |
| DBE-8 | 130758 SPELLCLICK без данных | флаг снят (если строк нет) |
| DBE-9 | AreaTrigger GUID 22 → PortLocID 0 | `DELETE ... PortLocID=0` |
| DBE-10 | spawn_mask 8388870 (BfA-подземелья) | нормализован в 7 |
| DBE-11..13 | creature/gameobject/disenchant loot: «does not exist» | placeholder-строки + удаление обратных сирот |
| DBE-14 | spell_loot_template → несуществующие предметы | удаление осиротевших строк |

Важный организационный дефект: `99_legionforge_error_fixes_26124.sql`
существовал в `sql/`, но НЕ был зарегистрирован в манифесте
`apply_play_sql.ps1` — то есть никогда не применялся автоматически, и
предупреждения возвращались при каждом старте. Часть его операторов была
закомментирована. 101-й патч доводит их до конца (с guard-условиями) и
зарегистрирован; 100_part2 закрывал мёртвые BfA-строки.

## 2b. Второй проход аудита (полные 628 строк DBErrors.log)

| # | Класс | Правка в 101 |
|---|-------|--------------|
| DBE-15 | 15 BfA-спеллов (spell_dbc) без строк в spell_loot_template (следствие SAFE-2) | восстановлены минимальные шаблоны |
| DBE-16 | reference_loot_template 210000-210019 «useless» | удаление нессылаемых строк (derived-table, без 1093) |
| DBE-17 | creature_formations leader/member guid 370509/370510/370570/370571 | чистка висячих строк |
| DBE-18 | «Creature entry is not using SmartAI, skipped loading» | AIName='SmartAI' для 16 entry из списков R-3/лога |
| DBE-19 | ScriptName areatrigger_runic_mark_1..5 не скомпилирован в ядре | отвязка (areatrigger_template + areatrigger) |
| DBE-20 | spell_spawn_flash_N_periodic отсутствует | удаление мёртвых spell_script_names |
| DBE-21 | WaypointMovementGenerator «doesn't have waypoint path id» (Xan'tish, Wretched Ghoul) | patrol без path_id → idle |

Также: `50_uwow_custom_races.sql` (UWOW-расы 31/32/34-37: Зандалари<-Тролль и т.д.)
добавлен в манифест `apply_play_sql.ps1` **до** `52_custom_races_31_44.sql` —
раньше он лежал в репозитории без автоприменения, поэтому кастомный клиент
получал обобщённых доноров вместо клиент-согласованных.

## 2c. Rev.2 патча 101 (после прогона setup.bat 2026-10-13, 22:11)

Прогон пользователя: компиляция 45 мин — OK, все патчи — OK, **101 rev.1 упал**:
`ERROR 1054 (42S22) at line 42: Unknown column 'RewardSpellCast'`.
Причина — имена колонок брались из текста лог-сообщений ядра, а не из его
SELECT-запросов. Исправлено и защищено от повтора:

| Было в rev.1 | Стало в rev.2 | Почему |
|---|---|---|
| `quest_template.RewardSpellCast` | `RewardSpell` | колонка из SELECT `LoadQuests` (ObjectMgr.cpp:3896) |
| `creature_template.unit_npc_flag` | `npcflag` | SELECT `LoadCreatureTemplates` (ObjectMgr.cpp:416) |
| `LEFT JOIN item_template` | удалены точные пары (Entry, Item) из лога | в world-базе 7.x нет `item_template`: предметы в DB2 |
| плейсхолдеры лута `Item=0, MinCount=0, Chance=0` | валидные строки (2589 Linen Cloth ×1, 100 %) или клон соседнего шаблона | `LootStoreItem::IsValid` дал бы по 3 новые ошибки на строку |
| `areatrigger.spawn_mask = 7` | **не трогать** данжи; рейды 1520/1648/1530/1676 → 245760 | 8388870 = normal\|heroic\|**mythic**; 19 строк — ложное срабатывание бага ядра (`spawnMasks[mask]` вместо `spawnMasks[map_id]`), баг исправлен в `AreaTriggerDataStore.cpp` |
| `modelid1 = 11686` для 900100-903 | модель стража Штормграда (entry 68 / 3167) | 11686 — «Invisible Man», торговцы остались бы невидимыми |
| плейсхолдер `creature_loot_template 36756` | `creature_template.lootid = 0` | нет шаблона — существо и так ничего не роняет |
| плейсхолдеры `gameobject_loot_template` | перепривязка ключа 204281→30786, 203751→29946, 203801→29959, 203762→29952 | лут был записан под entry сундука вместо `Data1` |

Источники повторов закрыты: `43_legionforge_upgrade_tokens.sql` пересоздавал
торговцев без `modelid1` — добавлен; `26_welcome_sender.sql` создавал 9500100 c
`unit_class 0` — добавлен `unit_class = 1`.

**Новый инструмент: `tools/audit_sql_columns.py`** — сверяет каждую колонку
каждого применяемого SQL с SELECT/UPDATE/INSERT-запросами ядра (679 таблиц),
`sql/1xx_*.sql` проверяются строго (ненулевой код выхода). Включён в
`tools/audit_readiness.py` (теперь 9 тестов). Правило: **имя колонки берём
только из запроса ядра или CREATE TABLE, никогда — из текста лога.**

Правка ядра `AreaTriggerDataStore.cpp` не входит в фингерпринт
`check_build_freshness.ps1` → `setup.bat` не начнёт принудительную
пересборку; 19 строк «wrong spawn mask» исчезнут после ближайшего
`build_server.bat`, на работу сервера они не влияют.

## 3. Кастомный клиент UWOW (расы 31–44, BfA-модели)

* Запуск сервера от кастомных рас НЕ зависит: `ChrRaces`/`playercreateinfo`
  влияют только на окно создания персонажа. Ядро LEGIONFORGE использует
  расширенную таблицу `playercreateinfo` (9–11 расовых стартовых строки на
  расу из вывода 52-го патча) и `race_unlock_requirement`; `MAX_CREATURE_DISPLAYID`
  / лимиты DB2 проверены `tools/check_db2_build.ps1` (242/242 ok в ОШИБКИ.txt).
* Если раса 31–44 отсутствует в `ChrRaces.db2` клиента — персонаж не создастся,
  но сервер заработает. Для сверки клиента с ядром:
  `tools/check_client_delta.ps1` → `logs/race_form_audit.md`.
* Все предупреждения вида «non-existing display id» для новых расовых моделей
  из БФА (Highmountain/Kul Tiran/Dark Iron) теперь не красят старт: ядро
  агрегирует такие логи (см. `test_log_spam_aggregation_caps`).

## 4. Правила против повторов (добавлены в `tools/audit_readiness.py`)

1. Лаунчер-скрипты готовности обязаны поллить, а не проверять однократно.
2. Никаких `-match` с несгруппированными `(`/`)` в PowerShell — только
   `.Contains()` для литералов.
3. Каждый `sql/*.sql` с фиксами обязан быть зарегистрирован в манифесте
   `apply_play_sql.ps1` (иначе он мёртв) — проверят автоматический тест.
4. `.bat` — CP866+CRLF, `.ps1` — UTF-8 BOM+CRLF (`.gitattributes` дополнен
   `*.bat text eol=crlf`, `*.ps1 text eol=crlf`).
5. После правок ядра обязателен `python tools/audit_regressions.py` (22 теста)
   и `python tools/audit_readiness.py` (новый, 9 проверок, включая колоночный аудит SQL).

## 5. Порядок действий на машине сервера (Windows)

```bat
git clone https://github.com/andreysf1983-maker/LegionForge_141026.git D:\legionforge
cd D:\legionforge
UNBLOCK.bat
build_server.bat        :: пересборка с патчем Player.cpp (опционально, но рекомендуется)
setup.bat               :: администратор; MySQL + БД + данные
play.bat                :: bnetserver -> worldserver (ожидание до 15 мин) -> клиент
```

Если `play.bat` вывел `crashed` — смотреть хвост `server\Server.log`; если
`loading-timeout` — загрузка ещё идёт, `server_status.ps1` покажет прогресс.
