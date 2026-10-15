# FIX 2026-10-13 — крэш worldserver после «ready…» (ОШИБКИ.txt)

## 1. Что было в ОШИБКИ.txt

```
TC>LEGIONFORGE rev.1 ... (worldserver-daemon) ready...
[1146] Table 'world.scenario_npc_landing' doesn't exist
Your database structure is not up to date. ...
Exception code: 80000003 BREAKPOINT  (abort)
MySQLConnection::_HandleMySQLErrno  MySQLConnection.cpp:585
ScenarioDoorWorldScript::OnStartup  scripts/Custom/scenario_door.cpp:114
ScriptMgr::OnStartup -> main  worldserver/Main.cpp:425
```

Сервер загрузил DB2 вашего кастомного клиента, 33 требования рас, все карты — то есть
**расы BfA+ и DB2 клиента падения НЕ вызывали**. Падение — сразу после `ready...`, в хуке
`WorldScript::OnStartup`.

## 2. Корневая причина

* `scenario_door.cpp` при старте выполняет
  `SELECT ... FROM scenario_npc_landing JOIN scenario_map_landing`.
* Эти таблицы создаёт `sql/stitch/010_scenario_npc_landing.sql`, но в `apply_play_sql.ps1`
  была подключена **только characters-половина** (`010_scenario_return_characters.sql`).
  World-половину не применял ни `setup.bat`, ни `play.bat`.
* `MySQLConnection::_HandleMySQLErrno` на `ER_NO_SUCH_TABLE (1146)` и `ER_BAD_FIELD_ERROR (1054)`
  вызывает `std::abort()` → крэш-дамп `80000003 BREAKPOINT` в `libmysql.dll`.

## 3. Что исправлено

| # | Файл | Исправление |
|---|------|-------------|
| 1 | `apply_play_sql.ps1` | Подключены `stitch\010_scenario_npc_landing.sql` (world), `32_playerbot_auth.sql`, `32_playerbot_world.sql` (таблицы, читаемые ядром при старте) и `100_legionforge_error_fixes_26124_part2.sql` (раньше «применить вручную» — поэтому ошибки из лога повторялись). |
| 2 | `apply_play_sql.ps1` | **Предстартовая проверка** обязательных таблиц ядра через `information_schema`: если таблицы нет — запуск останавливается с понятным сообщением и именем SQL-файла, а не крэшем после 4 минут загрузки. |
| 3 | `scripts/Custom/scenario_door.cpp` | Самовосстановление схемы: `CREATE TABLE IF NOT EXISTS` для 3 таблиц, проверка через `information_schema`, при проблеме функция «дверей сценария» отключается с ошибкой в логе — **без abort()**. Все запросы к `character_scenario_return` защищены флагом. |
| 4 | `scripts/Commands/cs_list.cpp` | `.list mail` обращался к `world.item_template`, которой **нет в Legion 7.x** → тот же abort() + разыменование nullptr. Заменено на `sObjectMgr->GetItemTemplate()`. |
| 5 | `database/MySQLConnection.cpp` | Упавший SQL теперь пишется уровнем ERROR (раньше INFO — не видно в консоли), сообщение о схеме указывает errno и что делать. |
| 6 | `Handlers/CharacterHandler.cpp`, `Globals/ObjectMgr.cpp`, `Entities/Unit/Unit.h` | Кастомный клиент с расами новее BfA (Драктиры 52/70, Земельники 84/85…): ID ≥ `MAX_RACES` (45) отклоняются явно с подсказкой; `getRaceMask()` больше не делает UB-сдвиг > 63 бит. Расы 31–44 (`CustomRaces.Definitions`, `sql/52_custom_races_31_44.sql`) работают как раньше. |
| 7 | `.gitattributes` + все `.bat`/`.ps1` | Все 18 `.bat` и 40 `.ps1` в репозитории были с **LF** (`* text=auto`). cmd.exe с LF неправильно находит метки `call :APPLY`/`goto` — скрипты «мигают и закрываются». Теперь CRLF (`tools/normalize_scripts.py`) и `eol=crlf` в `.gitattributes`. |

## 4. Что делать вам (Windows)

1. Распакуйте архив поверх/рядом со старой папкой (базы MySQL и `server\data` сохраняются).
2. Запустите `UNBLOCK.bat`, затем **`build_server.bat`** (изменены исходники ядра — нужна пересборка).
3. Запустите `play.bat`: он сам применит SQL и проверит обязательные таблицы.
   Без пересборки старый EXE тоже запустится, т.к. таблицы теперь создаёт установщик.

## 5. Аудит против повторения (новое)

* `python tools/audit_sql_schema.py` — статически извлекает **все 1362 SQL-запроса ядра**
  (`PrepareStatement` + прямые `Query/PQuery/Execute/...`) и сверяет таблицы/колонки со схемой:
  `sql/base/auth.sql`, `characters.sql`, ADB world/hotfixes (`sql/base/ADB_*.sql` после setup или
  `--adb-world/--adb-hotfixes`), плюс всё, что реально применяют `apply_play_sql.ps1`,
  `setup.bat`, `play.bat`, `ensure_auth_schema.ps1` (учитываются `CREATE`, `ALTER ADD`, `DROP`).
  Также ловит SQL-файлы с `CREATE TABLE`, не подключённые ни к одному установщику.
  Отчёт: `logs/sql_schema_audit.md`. Результат на ADB_735.10: **0 проблем** (до исправления: 3 таблицы + 1 неподключённый файл).
* `python tools/audit_regressions.py -v` — 22 теста (добавлено 5 на этот класс ошибок; исправлен
  ранее падавший тест окончаний строк).

### Правила для новых изменений
1. Новая таблица, которую читает C++ → SQL с `CREATE TABLE IF NOT EXISTS` **и** строка в `apply_play_sql.ps1`
   **и** (для критичных при старте) строка в блоке `$required`.
2. Запросы к кастомным таблицам из `WorldScript::OnStartup` — только после проверки `information_schema`.
3. Не использовать таблицы WotLK/старых ядер (`item_template`, `creature_movement` …) — в 7.3.5 их нет.
4. Перед коммитом: `python tools/audit_sql_schema.py && python tools/audit_regressions.py`.
5. `.bat` — CP866 + CRLF, `.ps1` — UTF-8 BOM + CRLF (`python tools/normalize_scripts.py`).
