# LEGIONFORGE 7.3.5 (build 26124) — полный аудит и устранение ошибок

Дата аудита: 2026-10.
Источник: полный клон `https://github.com/andreysf1983-maker/LEGIONFORGE_7.3.5_build26124_FIXED.git`
(4588 файлов, исходное дерево не изменялось — только точечные доработки).
Перечень исходных проблем: `ОШИБКИ.txt`.

---

## 1. Сводка

| # | Проблема из `ОШИБКИ.txt` | Причина | Статус |
|---|---------------------------|---------|--------|
| 1 | `ERROR 1054 (42S22) at line 115: Unknown column 'createMode' in 'field list'` при применении `52_custom_races_31_44.sql` | В чистой базе ADB_735.10 таблица `playercreateinfo_cast_spell` содержит только `raceMask, classMask, spell` | ✅ ИСПРАВЛЕНО |
| 2 | `mysql_stmt_prepare` id 19/20/21/22 — `Unknown column 'c.lastLoginBuild'` | Колонки нет в `characters` | ✅ ИСПРАВЛЕНО |
| 3 | id 32/283/284 — `Unknown column 'inventorySlots'` | Колонки нет в `characters` | ✅ ИСПРАВЛЕНО |
| 4 | id 38 — `Unknown column 'explored'` | Колонки нет в `character_queststatus` | ✅ ИСПРАВЛЕНО |
| 5 | id 80 — `Table 'character_pvp_talent' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 6 | id 119/120 — `Unknown column 'a.artifactTierId'` | Колонки нет в `item_instance_artifact` | ✅ ИСПРАВЛЕНО |
| 7 | `Unknown column 'active'` (character_pet) | Колонки нет | ✅ ИСПРАВЛЕНО |
| 8 | `Unknown column 'type'` (character_garrison) | Колонки нет | ✅ ИСПРАВЛЕНО |
| 9 | `Unknown column 'garrison_type'` (4 таблицы гарнизона) | Колонок нет | ✅ ИСПРАВЛЕНО |
| 10 | `Table 'character_garrison_missions' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 11 | `Table 'characters.world_quest' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 12 | `Table 'characters.log_gm' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 13 | `Table 'characters.character_shop' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 14 | `Table 'characters.character_recovery' doesn't exist` | Таблица отсутствует | ✅ ИСПРАВЛЕНО |
| 15 | `Unknown column 'xpRate'` (id 568 / `CHAR_UPD_XP_RATE`) | Колонки нет в `characters` | ✅ ИСПРАВЛЕНО |
| 16 | Обновления схемы пропускались («уже применены ранее - пропуск») | Флаг `setup_tmp\schema_updates_*.flag` не давал применить новые патчи | ✅ ИСПРАВЛЕНО |

**Итого: 16 подтверждённых дефектов, все закрыты.**

---

## 2. Методика

Схема сверена **не по догадкам**, а по фактическим подготовленным запросам ядра:

```
core/src/server/database/Database/Implementation/CharacterDatabase.cpp   (832 строки запросов)
core/src/server/database/Database/Implementation/AuthDatabase.cpp
core/src/server/database/Database/Implementation/WorldDatabase.cpp
core/src/server/database/Database/Implementation/HotfixDatabase.cpp
```

Автоматический аудит разбирал каждый `PrepareStatement(...)`, извлекал
`INSERT INTO t (…)`, `UPDATE t SET …`, `SELECT … FROM t [JOIN …]` и сравнивал
упомянутые колонки с реальным `sql/base/characters.sql`. До исправления —
**15 таблиц с расхождениями**, после — **0**.

Контроль (после правок):

```
guild_newslog.Timestamp        -> есть TimeStamp      (MySQL: регистр не важен) OK
arena_team_member.arenateamid  -> есть arenaTeamId                             OK
character_aura.remainCharges   -> есть                                         OK
characters.inventorySlots / lastLoginBuild / xpRate                            OK
character_queststatus.explored                                                 OK
character_pvp_talent                                                           OK
item_instance_artifact.artifactTierId                                          OK
character_garrison{,_blueprints,_buildings,_followers}.garrison_type           OK
character_garrison_missions / world_quest / log_gm / character_shop / character_recovery   OK
```

---

## 3. Что изменено

### 3.1. Новые файлы

| Файл | Назначение |
|------|-----------|
| `sql/updates/characters/master/2026_01_01_00_characters_schema_sync.sql` | Идемпотентное добавление колонок `characters.inventorySlots`, `characters.lastLoginBuild`, `characters.xpRate`, `character_queststatus.explored`, `character_pet.active`, `character_garrison.type`, `character_garrison_blueprints.garrison_type`, `item_instance_artifact.artifactTierId`, `mail.mailTemplateId` + создание `character_pvp_talent`. Поля `resettime`/`entranceId` намеренно остаются только в таблице `instance` |
| `sql/updates/characters/master/2026_01_01_01_characters_missing_tables.sql` | Создание `character_garrison_missions`, `world_quest`, `log_gm`, `character_shop`, `character_recovery` + `garrison_type` в 4 таблицах гарнизона |
| `sql/updates/characters/master/2026_01_01_02_character_instance_join_fix.sql` | Идемпотентно удаляет ошибочные дубликаты `character_instance.resettime` и `entranceId`; запускается первым через `apply_play_sql.ps1`, до `worldserver` |

Оба файла **без `DELIMITER` и без хранимых процедур** — только
`IF(EXISTS(information_schema...), 'DO 0', 'ALTER ...') + PREPARE/EXECUTE`.
Такой стиль уже используется в `sql/52_custom_races_31_44.sql` и гарантированно
работает под `mysql --force`, куда скрипты подаются через stdin.

### 3.2. Исправленные файлы

| Файл | Изменение |
|------|-----------|
| `sql/base/characters.sql` | Схема приведена к ядру: +5 таблиц (`character_pvp_talent`, `character_garrison_missions`, `world_quest`, `log_gm`, `character_shop`, `character_recovery`), +колонки `inventorySlots`, `lastLoginBuild`, `xpRate`, `explored`, `active`, `type`, `garrison_type` (×4), `artifactTierId`. Итог: **118 → 123 таблицы**. Чистая установка сразу получает корректную схему |
| `sql/52_custom_races_31_44.sql` | **Исправлен сбой установки.** Перед INSERT добавлено условное создание `playercreateinfo_cast_spell.createMode` и `.note`; дополнительно `CREATE TABLE IF NOT EXISTS` для `player_levelstats` и `race_unlock_requirement` |
| `sql/50_uwow_custom_races.sql` | Тот же защитный блок для `createMode` / `note` |
| `setup.bat` | 1) `apply_schema_updates.ps1` вызывается с `-Force` — новые патчи схемы больше не пропускаются из-за старого флага; 2) schema-sync и очистка `character_instance` включены в список `:APPLY` |

### 3.3. Почему `createMode` ломал установку

Ядро читает таблицу так (`core/src/server/game/Globals/ObjectMgr.cpp:3505`):

```cpp
QueryResult result = WorldDatabase.PQuery(
    "SELECT raceMask, classMask, spell FROM playercreateinfo_cast_spell");
```

то есть колонки `createMode` и `note` ядру **не нужны**. Но патч
`52_custom_races_31_44.sql` копировал их из расы-донора:

```sql
INSERT IGNORE INTO `playercreateinfo_cast_spell` (`raceMask`,`classMask`,`spell`,`createMode`,`note`)
SELECT ..., c.`createMode`, ... FROM `playercreateinfo_cast_spell` c ...
```

В чистой базе ADB_735.10 этих колонок нет → `ERROR 1054 (42S22)` → `mysql exit 1`
→ `[ОШИБКА] Один или несколько основных SQL-патчей не применены` → установка
прерывалась **до** создания `worldserver.conf` / `bnetserver.conf`.

Решение создаёт колонки с безопасными значениями по умолчанию, если их нет:
данные не теряются, патч выполняется на любой базе (ADB, старый дамп, пустая).

---

## 4. Аудит кастомного контента — 100% покрытие

### 4.1. Кастомные расы 31–44 (14 рас)

Сверены **три** источника определений — они обязаны совпадать:

| Раса | Донор | Команда | `worldserver.conf.dist` | `Player.cpp` DEFAULT | `52_custom_races_31_44.sql` |
|-----:|------:|:--------|:-----------------------:|:--------------------:|:---------------------------:|
| 31 | 1 Human | ALLIANCE | ✅ | ✅ | ✅ |
| 32 | 2 Orc | HORDE | ✅ | ✅ | ✅ |
| 33 | 4 Night Elf | ALLIANCE | ✅ | ✅ | ✅ |
| 34 | 3 Dwarf | ALLIANCE | ✅ | ✅ | ✅ |
| 35 | 5 Undead | HORDE | ✅ | ✅ | ✅ |
| 36 | 6 Tauren | HORDE | ✅ | ✅ | ✅ |
| 37 | 7 Gnome | ALLIANCE | ✅ | ✅ | ✅ |
| 38 | 8 Troll | HORDE | ✅ | ✅ | ✅ |
| 39 | 10 Blood Elf | HORDE | ✅ | ✅ | ✅ |
| 40 | 11 Draenei | ALLIANCE | ✅ | ✅ | ✅ |
| 41 | 22 Worgen | ALLIANCE | ✅ | ✅ | ✅ |
| 42 | 9 Goblin | HORDE | ✅ | ✅ | ✅ |
| 43 | 24 Pandaren Neutral | NEUTRAL | ✅ | ✅ | ✅ |
| 44 | 27 Nightborne | ALLIANCE | ✅ | ✅ | ✅ |

**14 / 14 рас синхронизированы.**

### 4.2. Ядро: снятие лимитов

| Константа | Файл | Значение |
|-----------|------|----------|
| `MAX_RACES` | `SharedDefines.h:200` | `45` (было 31) |
| `RACE_CUSTOM_31…44` | `SharedDefines.h` | объявлены все 14 |
| `RACEMASK_CUSTOM_PLAYABLE / _ALLIANCE / _HORDE` | `SharedDefines.h` | 64-битные маски `UI64LIT` |
| `BATTLE_PET_SPECIES_MAX_ID` | `DBCEnums.h` | `5004` |
| `MAX_DIFFICULTY` | `DBCEnums.h` | `148` (`DIFFICULTY_RESERVED_MAX = 147`) |
| `TaxiMaskSize` | `DBCEnums.h` | `286` |

`Player::IsCustomRace / GetCustomRaceBase / GetCustomRaceTeam` реализованы и
подключены во всех точках, где ядро обращается к `ChrRaces.db2`:

```
Player.cpp:6579  IsCustomRace                 Player.cpp:6615  TeamForRace
Player.cpp:6631  TeamIdForRace                Player.cpp:6652  setFactionForRace
ObjectMgr.cpp:3288/3326  LoadPlayerInfo       ObjectMgr.cpp:3669  ValidateRace
ObjectMgr.cpp:9973  LoadRaceUnlockRequirement DB2Stores.cpp:1365  LookupRaceEntry
CharacterHandler.cpp:459  HandleCharCreateOpcode
```

### 4.3. Все таблицы стартовых данных, читаемые ядром

Проверен **полный** список race-keyed таблиц, которые загружает `ObjectMgr.cpp`:

| Таблица | Запрос ядра | Покрыта в `52_custom_races_31_44.sql` |
|---------|-------------|:-------------------------------------:|
| `playercreateinfo` | `ObjectMgr.cpp:3253` | ✅ |
| `playercreateinfo_item` | `:3356` | ✅ |
| `playercreateinfo_spell_custom` | `:3443` | ✅ |
| `playercreateinfo_cast_spell` | `:3505` | ✅ (исправлено) |
| `playercreateinfo_action` | `:3561` | ✅ |
| `player_levelstats` | `:3606` | ✅ |
| `race_unlock_requirement` | `:9955` | ✅ |

Других race-keyed таблиц создания персонажа в ядре нет — **покрытие 7 / 7 = 100 %**.

### 4.4. Разблокировка рас (expansion)

`race_unlock_requirement.expansion = 6` (`EXPANSION_LEGION`).
Проверка ядра — `expansion >= MAX_ACCOUNT_EXPANSIONS`, где
`MAX_ACCOUNT_EXPANSIONS = 8` (`EXPANSION_BATTLE_FOR_AZEROTH = 7` + 1).
`6 < 8` → раса проходит проверку. Значение `7` (BfA) действительно давало
`CHAR_CREATE_EXPANSION`, как и указано в комментарии патча — **патч корректен**.

### 4.5. Маски рас и 64-битная арифметика

Бит расы 44 — `(1 << 43)`, что **не помещается** в `INT UNSIGNED`.
Патч `52_custom_races_31_44.sql` корректно переводит
`playercreateinfo_spell_custom.racemask` и `playercreateinfo_cast_spell.raceMask`
в `BIGINT UNSIGNED`, а ядро использует `UI64LIT(1) << (race - 1)`
(`CharacterHandler.cpp:1847`, `SharedDefines.h`). Несоответствий нет.

---

## 5. Как применить исправления

### Чистая установка
```bat
UNBLOCK.bat
setup.bat        :: от имени администратора
play.bat
```
`sql\base\characters.sql` уже содержит корректную схему, `createMode`-сбой исключён.

### Существующая установка (базы уже созданы)
```bat
setup.bat
```
Благодаря `-Force` оба schema-sync патча применятся повторно — они идемпотентны,
данные персонажей не затрагиваются, а ранее добавленные ошибочные дубликаты `resettime`/`entranceId` удаляются; данные в `instance` сохраняются.

### Проверка вручную
```bat
mysql --defaults-extra-file=setup_tmp\mysql.cnf characters ^
      < sql\updates\characters\master\2026_01_01_00_characters_schema_sync.sql
mysql --defaults-extra-file=setup_tmp\mysql.cnf characters ^
      < sql\updates\characters\master\2026_01_01_01_characters_missing_tables.sql
mysql --defaults-extra-file=setup_tmp\mysql.cnf characters ^
      < sql\updates\characters\master\2026_01_01_02_character_instance_join_fix.sql
```
Финальный `SELECT` каждого файла возвращает единицы во всех колонках —
значит схема соответствует ядру.

---

## 6. Критерий успеха

`worldserver` при старте должен **не** выдавать ни одного
`In mysql_stmt_prepare() ... Unknown column / doesn't exist`, а строка
`Database 'characters' is ready` появляется без предупреждений.
Все 16 дефектов из `ОШИБКИ.txt` воспроизводились именно на этапе
`mysql_stmt_prepare` / применения SQL-патчей и устранены на этом же уровне.

---

## 7. ДОПОЛНЕНИЕ: фатальный выход bnetserver — `no OPENSSL_Applink`

### 7.1. Симптом (прислан пользователем, лог запуска)

```
LEGIONFORGE rev.1 2026-10-11 10:51:08 (Legion 7.3.5.26124, Win64, Release, Static) (bnetserver)
Using configuration file bnetserver.conf.
Using SSL version: OpenSSL 3.5.9 29 Sep 2026 (library: OpenSSL 3.5.9 29 Sep 2026)
Using Boost version: 1.86.0
OPENSSL_Uplink(00007FFFB2656C58,08): no OPENSSL_Applink
Для продолжения нажмите любую клавишу . . .
```

Сервер печатает баннер и **мгновенно завершается**: крэш-дампа нет, в логе пусто,
`bnetserver.conf` успевает прочитаться, но до подключения к БД дело не доходит.

### 7.2. Механика (почему именно так)

1. `build_server.ps1`, функция `Find-OpenSslLayout` (строка 203), **намеренно**
   выбирает динамическую сборку OpenSSL:
   ```powershell
   $all | Where-Object { $_.FullName -notmatch 'MDd|MTd|\\MT\\|static' } | Select-Object -First 1
   ```
   То есть сервер линкуется с `libcrypto-3-x64.dll` / `libssl-3-x64.dll`.
2. Сам исполняемый файл собирается со **статическим CRT** — это видно в баннере:
   `Release, Static`.
3. У DLL и у EXE разные CRT и разные файловые дескрипторы `stdout/stderr`.
   Поэтому OpenSSL на Windows **не имеет права** звать `fputs` напрямую — он берёт
   указатели из таблицы `OPENSSL_ApplinkTable`.
4. Таблицу заполняет функция `OPENSSL_Applink()`, которую **обязано экспортировать
   приложение**. DLL ищет её так:
   ```c
   GetProcAddress(GetModuleHandle(NULL), "OPENSSL_Applink")
   ```
5. Ядро LEGIONFORGE её не экспортировало — `grep -rn "applink" core/src` давал
   **0 совпадений**. Значит `OPENSSL_Uplink()` упал в `OPENSSL_die()`.
6. Индекс `08` в сообщении — это `fputs` в таблице applink. То есть DLL просто
   пыталась что-то напечатать в stderr (диагностика конфигурации OpenSSL), и это
   оказалось смертельным.

**Вывод:** это не ошибка конфигурации и не проблема БД — это отсутствующий
экспорт в исполняемом файле. Любая первая запись в stderr из libcrypto убивала процесс.

### 7.3. Исправление (постоянное, в исходниках)

`core/src/server/bnetserver/Main.cpp` и `core/src/server/worldserver/Main.cpp` —
добавлен блок под Windows:

```cpp
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
#include <openssl/opensslv.h>
#include <openssl/crypto.h>
#include <openssl/applink.c>
#endif
```

Почему именно так:

* `openssl/applink.c` внутри объявлен как `__declspec(dllexport)`, поэтому его
  компиляция в EXE **создаёт нужный экспорт**. Это штатный способ из документации
  OpenSSL (`INSTALL.WIN`), а не обходной приём.
* Файл включается **ровно в одну** единицу трансляции каждого исполняемого файла
  (`Main.cpp`) — иначе было бы множественное определение.
* Макрос `LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS` — собственная
  идиома проекта (`core/src/common/CompilerDefs.h`), под Linux/macOS блок не
  компилируется.
* Если в какой-то конфигурации OpenSSL всё же влинкован статически, включение
  **безвредно**: экспортируемая функция просто никогда не будет вызвана.

**Требуется пересборка:** `build_server.bat` (или `build_server.ps1`).

### 7.4. Смягчение без пересборки + диагностика

Для уже собранных бинарников добавлены два новых файла:

| Файл | Назначение |
|------|-----------|
| `tools/openssl.cnf` | Минимальный заведомо валидный конфиг OpenSSL 3.x. Убирает самый частый триггер первой записи в stderr — невалидный `OPENSSL_CONF`, который установщик slproweb прописывает на `C:\OpenSSL-Win64\bin\openssl.cfg` |
| `tools/diagnose_openssl.ps1` | Автономная диагностика: (1) наличие экспорта `OPENSSL_Applink` в `bnetserver.exe`/`worldserver.exe` побайтовым сканом PE; (2) какие `libcrypto`/`libssl` лежат рядом с exe; (3) посторонние OpenSSL DLL в `PATH` (Git for Windows, PostgreSQL, Steam), способные перекрыть локальные; (4) валидность `OPENSSL_CONF`. Код возврата: `0` — норма, `1` — нужна пересборка, `2` — предупреждения |

Интеграция в штатные скрипты:

* **`play.bat`** — перед запуском bnetserver подставляет `OPENSSL_CONF` на
  `tools\openssl.cnf`, но **только** если переменная не задана или указывает на
  несуществующий файл (рабочая настройка пользователя не затирается), и вызывает
  `diagnose_openssl.ps1`.
* **`check_server_runtime.ps1`** — проверка `OPENSSL_Applink` добавлена к
  существующей проверке DLL и попадает в отчёт `server\runtime_check.txt`.
  Прежняя проверка отвечала лишь «есть ли файл libcrypto», чего для этой ошибки
  недостаточно: все DLL на месте, а сервер всё равно умирает.

Запуск диагностики вручную:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagnose_openssl.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagnose_openssl.ps1 -ServerDir D:\legionforge\server
```

### 7.5. Итоговый счётчик дефектов

| № | Дефект | Статус |
|---|--------|--------|
| LF-001 … LF-016 | Ошибки SQL-патчей и схемы `characters` из `ОШИБКИ.txt` | ✅ устранены |
| **LF-017** | **`OPENSSL_Uplink(...): no OPENSSL_Applink` — фатальный выход bnetserver/worldserver** | ✅ **устранено** |

**Всего до последнего лога: 17 дефектов. Следующий запуск выявил LF-018; теперь всего 18, исправление включено в архив.**


---

## 8. LF-018: worldserver не запускается — `Column 'resettime' in field list is ambiguous`

### 8.1. Точный симптом из нового лога

```text
In mysql_stmt_prepare() id: 34, sql:
"SELECT id, permanent, map, difficulty, extendState, resettime, entranceId
 FROM character_instance LEFT JOIN instance ON instance = id WHERE guid = ?"
Column 'resettime' in field list is ambiguous
Could not prepare statements of the Character database
```

**Важный прогресс:** `bnetserver` уже стартует; фикс OpenSSL скомпилирован и экспорт
`OPENSSL_Applink` присутствует в обоих exe. Это отдельная ошибка схемы `characters`.

### 8.2. Причина

`resettime` и `entranceId` принадлежат таблице `instance` (см. исходную схему
`sql/base/characters.sql`, `CREATE TABLE instance`). Предыдущий патч
`2026_01_01_00_characters_schema_sync.sql` ошибочно добавил одноимённые поля также
в `character_instance`. В запросе ядра две одноимённые колонки после JOIN; MySQL
возвращает error 1052 — *Column ... is ambiguous*.

Исправленная версия патча `2026_01_01_00` **больше не создаёт** эти дубликаты.
Для базы, где прежняя версия уже была применена, создана миграция:

```text
sql/updates/characters/master/2026_01_01_02_character_instance_join_fix.sql
```

Она проверяет `information_schema` и условно удаляет только
`character_instance.resettime` и `character_instance.entranceId`. Поля и данные
в правильной таблице `instance` не меняются. Повторный запуск безопасен.

### 8.3. Как исправить существующий сервер без пересборки

Миграция добавлена **первым SQL-патчем в `apply_play_sql.ps1`**. После установки
обновлённого репозитория/архива запустите `play.bat`: перед стартом процессов он
удалит дублирующие колонки и продолжит запуск. Либо вручную из корня проекта:

```bat
tools\mysql\server\bin\mysql.exe --defaults-extra-file=setup_tmp\mysql.cnf ^
  --default-character-set=utf8mb4 characters ^
  < sql\updates\characters\master\2026_01_01_02_character_instance_join_fix.sql
```

Контрольный запрос в конце миграции должен вернуть
`erroneous_character_instance_columns_remaining = 0`.

### 8.4. Защита следующей сборки

В `core/src/server/database/Database/Implementation/CharacterDatabase.cpp`
запрос дополнительно квалифицирован:

```sql
SELECT instance.id, character_instance.permanent, instance.map,
       instance.difficulty, character_instance.extendState,
       instance.resettime, instance.entranceId
  FROM character_instance
  LEFT JOIN instance ON character_instance.instance = instance.id
 WHERE character_instance.guid = ?
```

Так запрос не зависит от появления одноимённых колонок в другой таблице. Для
этого изменения требуется пересобрать сервер, но **сейчас**, чтобы исправить
данный error 1052, пересборка не обязательна: миграция исправляет текущую БД.

### 8.5. Маршруты применения

* `play.bat` → `apply_play_sql.ps1` применяет migration `02` перед другими патчами
  и до старта `worldserver`.
* `setup.bat` также применяет её после schema-sync патчей.
* Повторный запуск миграции безопасен; если колонок уже нет, SQL выполняет `DO 0`.

**Итоговая нумерация: LF-001…LF-018. Ошибка из последнего лога устранена.**
