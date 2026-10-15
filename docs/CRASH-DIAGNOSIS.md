# Падение worldserver: причина и диагностика

## Подтверждённая причина (лог запуска от 10.10.2026)

```
Initialize data stores...
D:\legionforge\core\src\server\game\DataStores\DB2Stores.cpp:746 in DB2Manager::LoadStores ASSERTION FAILED:
  BATTLE_PET_SPECIES_MAX_ID >= sBattlePetSpeciesStore.GetNumRows()
  BATTLE_PET_SPECIES_MAX_ID (2164) must be equal to or greater than 5004
  breadcrumb: none
```

Это **не случайный сбой, а намеренная остановка**. Ядро сравнивает данные клиента со своими
константами и, если клиентские данные больше, аварийно завершается, чтобы не получить
переполнение массива.

### Что означают числа

- `GetNumRows()` возвращает `_indexTableSize`, то есть **MaxId + 1**
  (`core/src/server/shared/DataStores/DB2Store.h:100`).
- Значит в вашем `server\data\dbc\enUS\BattlePetSpecies.db2` **MaxId = 5003**.
- Константа ядра: `#define BATTLE_PET_SPECIES_MAX_ID 2164`
  (`core/src/server/game/DataStores/DBCEnums.h:166`) — это предел для чистого 7.3.5 build 26124.
- Константа задаёт размер битового массива `KnownPets` во входящем пакете аукциона
  (`AuctionHousePackets.h:280`, чтение на стороне сервера). При ID > 2163 массив был бы
  перезаписан — ASSERT защищает именно от этого.

### Вывод о ваших игровых данных

`dbc` извлекается **из клиента**, поэтому MaxId 5003 означает, что папка `server\data`
(или сам клиент) не от чистого 7.3.5 build 26124: в ней больше видов боевых питомцев,
чем в официальном Legion. Типичный случай — data скопирована из чужой сборки/репака
или клиент модифицирован (питомцы из более новых дополнений).

Косвенное подтверждение: `LayoutHash` всех DB2 совпал с ядром (иначе загрузка прервалась бы
раньше — `DB2FileLoader.cpp:1408` возвращает false при чужом хэше, и сервер сообщил бы
«ALL required *.db2 files not found»). То есть формат Legion, но **состав данных расширен**.

### Раньше это выглядело как ACCESS_VIOLATION

Дамп от 10.10.2026 (`C0000005 ACCESS_VIOLATION`, `RAX=0`, `Last breadcrumb: none`, та же
ревизия `rev.1 2026-10-08 22:19:50`) — это и есть данный ASSERT: `LegionForge::Assert()`
печатает текст в stderr и затем **намеренно** пишет в нулевой указатель
(`core/src/common/Debugging/Errors.cpp`: `*((volatile int*)NULL) = 0;`), чтобы крэш-репортер
WheatyExceptionReport зафиксировал падение. В крэш-файл текст ASSERT не попадал, поэтому
причина была не видна. Теперь исправлено (см. ниже).

## Как исправить

### Шаг 1. Узнать, что именно не так (без запуска сервера)

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_db2_build.ps1
```

Скрипт читает заголовки всех 242 DB2 из `server\data\dbc\<локаль>` и сверяет с ядром:
сигнатуру (WDC1), `LayoutHash` против `DB2Metadata.h`, и пределы по данным для трёх таблиц,
на которые в ядре стоят ASSERT: `BattlePetSpecies`, `Difficulty`, `TaxiNodes`.
Коды выхода: 0 — подходит, 1 — найдены несоответствия, 2 — нет папки dbc.

Тот же запуск встроен в `play.bat` (перед стартом серверов) и в `check_game_data.ps1`
(используется `setup.bat` и `extract_maps.bat`), поэтому с неподходящими данными сервер
больше не запускается «вслепую».

### Шаг 2а. Если клиент на самом деле чистый 7.3.5 build 26124

Папка `server\data` попала туда из другого источника. Извлеките данные заново из своего клиента:

```bat
extract_maps.bat
```

`mapextractor` напишет `dbc` из CASC клиента. После этого `BattlePetSpecies` будет в пределах
2164, и ASSERT не сработает. Заодно пересоздадутся `maps`/`vmaps` — если data была чужой,
карты тоже могли не соответствовать вашему клиенту.

### Шаг 2б. Если клиент действительно расширенный (MaxId 5003)

Поднимите константу под свои данные и пересоберите ядро:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\set_pet_species_max_id.ps1 -Value 5004
build_worldserver.bat
```

Скрипт правит одну строку `DBCEnums.h`, делает резервную копию `DBCEnums.h.orig`,
проверяет результат и отказывается ставить значение меньше 2164. Откат: `-Restore`.
Протокольно правка безопасна: константа влияет только на ASSERT и на ёмкость **входящего**
буфера `KnownPets` (271 → 626 байт), формат исходящих пакетов не меняется.

Если после этого worldserver упадёт на следующем ASSERT (например `MAX_DIFFICULTY` или
`TaxiMaskSize`), `tools\check_db2_build.ps1` покажет это заранее — все три таблицы он
проверяет сразу. Значит, данные клиента расходятся с Legion дальше, чем по питомцам,
и правильнее вернуться к варианту 2а.

## Что изменено в ядре для диагностики

| Изменение | Файл | Эффект |
|---|---|---|
| ASSERT/FATAL/ERROR/ABORT записывают свой текст в breadcrumb перед падением | `core/src/common/Debugging/Errors.cpp` | в `server\Crashes\*.txt` строка `Last breadcrumb:` теперь содержит причину, например `ASSERT …DB2Stores.cpp:745 …`, а не `none` |
| PDB-символы для Release (`/Zi`, `/DEBUG /OPT:REF /OPT:ICF`) | `core/cmake/compiler/msvc/settings.cmake` | крэш-лог показывает имена функций и строки вместо `01:OFFSET`; `worldserver.pdb` кладётся в `server\` |
| Breadcrumb в горячих путях: `World::Update`, `Map::Update map N`, имя опкода на каждый пакет | `World.cpp`, `Map.cpp`, `WorldSession.cpp` | при падении во время игры видно карту и последний опкод |
| Проверка DB2 до запуска | `tools\check_db2_build.ps1`, `check_game_data.ps1`, `play.bat` | неподходящий dbc отклоняется с объяснением, а не крэшем |
| Подбор константы под данные клиента | `tools\set_pet_species_max_id.ps1` | вариант 2б одной командой, с резервной копией и откатом |
| Расшифровка старых адресов `01:OFFSET` | `tools\resolve_crash.ps1` | по PDB превращает адреса крэш-лога в `Функция+смещение [файл:строка]` |
| Удалены отладочные записи прежнего автора на каждый пакет | `WorldSession.cpp`, `WorldSocket.cpp`, `HotfixHandler.cpp` | убраны 6 файлов `dbg_*.txt` и 5 записей по зашитому пути `C:\Users\donav\...` |

Замечание: PDB подходит только к exe из той же сборки, поэтому дамп от 08.10 расшифровать
задним числом нельзя — но теперь в нём и не нужно: причина известна из текста ASSERT.
