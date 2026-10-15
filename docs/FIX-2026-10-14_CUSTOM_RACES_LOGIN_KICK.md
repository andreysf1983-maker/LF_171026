# FIX 2026-10-14 — кастомные расы без модели + «грузит и выкидывает» при входе

Два симптома одного корня — расхождения **клиентских** и **серверных** DB2
(`CharSections.db2`, `ChrRaces.db2`, `CharStartOutfit.db2`) на кастомном клиенте
7.3.5.26124 с расами из BfA.

---

## Симптом A. Персонаж создан, но при входе «что-то грузит и выкидывает из игры»

### Причина (по коду, подтверждается)
Путь входа в мир:

```
CMSG_PLAYER_LOGIN
  -> WorldSession::HandlePlayerLoginOpcode -> HandlePlayerLogin(holder)
       -> Player::LoadFromDB(...)  == false  ->  KickPlayer()   // клиент выкинут
```

`Player::LoadFromDB` вызывает `Player::ValidateAppearance(..., create = false)`,
а та — `IsSectionFlagValid(entry, class, create)`:

```cpp
if (create)  return ComponentFlagsMatch(entry, GetSelectionFromContext(0, class_)); // создание
             return ComponentFlagsMatch(entry, GetSelectionFromContext(2, class_)); // ВХОД
```

Контексты проверяют **разные биты** `CharSections.Flags`:

| контекст | selection | требование к `Flags` |
|----------|-----------|----------------------|
| создание персонажа | 0 | `(Flags & 1)` и `!(Flags & 0x2C)` |
| **вход в мир** | 4 | `(Flags & 3)` и `!(Flags & 0x2C)` ← дополнительно **бит 0x2** |

У части строк **официального** серверного `CharSections.db2` (ADB_735.10) бита `0x2`
нет, а кастомный клиент такой вариант внешности выбрать и создать **разрешает**.
Итог: персонаж создаётся (проверка контекста 0 прошла), а при входе проверка
контекста 2 не проходит → `LoadFromDB` возвращает `false` → `KickPlayer()` →
клиент «грузит и выкидывает».

Дополнительно `HandleCharEnum` при той же проверке не кикает, а обнуляет внешность
и ставит `AT_LOGIN_CUSTOMIZE` — поэтому в списке персонажей всё выглядит нормально,
а ломается именно вход.

### Что исправлено
1. `IsSectionFlagValid`: при входе, если строгий login-контекст не прошёл,
   принимается вариант, валидный в creation-контексте (под конфигом).
2. `Player::LoadFromDB`: при расхождении внешности **больше не кикает** —
   пишет `WARN` с полными значениями (race/class/gender/skin/face/hair/facial)
   и продолжает загрузку.
3. `WorldSession::HandlePlayerLogin`: добавлены два лога —
   `Player login REJECTED ...` (с указанием смотреть причину строкой выше) и
   `Player login OK: '<имя>' race .. class .. map .. pos .. displayId ..`.
4. В оставшиеся пути кика добавлены подсказки: нет строки `playercreateinfo`
   (→ применить `sql/50_*` и `sql/52_*`) и неверные координаты/нет карты
   (→ проверить `server/data/maps`).

### Конфиг
```ini
#    Login.StrictAppearance
#        0 - принимать внешность, валидную хотя бы в creation-контексте (кастомный клиент)
#        1 - строгая проверка login-контекста (только ванильный клиент)
Login.StrictAppearance = 0
```
Дефолт кода — `false`, поэтому работает даже без строки в `worldserver.conf`.

---

## Симптом B. Кастомные расы видны в окне создания, но модель не отображается

### Причина
Превью в окне создания персонажа рисует **клиент** и **только** из своих DB2:

```
ChrRaces.db2 (раса есть -> поэтому она в списке)
   -> CharBaseSection / CharSections.db2  (компоненты внешности: кожа, лицо, волосы)
   -> CharStartOutfit.db2                 (стартовая экипировка превью)
   -> CreatureDisplayInfo.db2             (MaleDisplayId/FemaleDisplayId расы)
```

Сервер в превью **не участвует** (он не шлёт display id до создания персонажа).
Если в клиентских `CharSections.db2` / `CharStartOutfit.db2` нет строк для расы
31..44, либо `MaleDisplayId` расы в `ChrRaces.db2` указывает на несуществующий
`CreatureDisplayInfo` — модель не отрисуется, хотя раса в списке есть.
**Это данные клиентской сборки, сервером не лечится.**

### Точная диагностика (уже есть в проекте)
```bat
rem по своим клиентским DB2 (путь к клиенту 7.3.5)
python tools\legion_db2\audit_races_forms.py --dbc-dir "D:\WoW_Client\Data\dbc\enUS"

rem по серверным DB2 (что видит worldserver)
python tools\legion_db2\audit_races_forms.py

rem отчёт: logs\race_form_audit.md - таблица "CharSections | CharStartOutfit | Вывод" по каждой расе
```
Если в отчёте для расы 31..44 стоит «нет CharSections» — модель в превью не
появится никогда: нужны строки `CharSections`/`CharStartOutfit` в **клиентских**
DB2 (донорские записи от базовой расы), это правка клиентской сборки.

### Что исправлено на сервере (чтобы расу можно было создать и войти)
Даже при корректном клиенте сервер раньше **отвергал** расы 31..44:
`GetCharSectionEntry(31..44, ...)` возвращал `nullptr` (в серверном официальном
`CharSections.db2` таких рас нет) → `ValidateAppearance` всегда `false` →
персонажа нельзя ни создать, ни загрузить.

`Player::ValidateAppearance` теперь проверяет внешность по **расе-донору** из
реестра `CustomRaces.Definitions` — тому же донору, который уже отдаёт
`FactionID` и `Male/FemaleDisplayId` в `ObjectMgr::LoadPlayerCreateInfo`:

```
31 Зандалары <- 8 (тролль)     35 Вульперы <- 8 (тролль)
32 Кул-тирасцы <- 1 (человек)  36 Маг'хары <- 2 (орк)
34 Дворфы Ч.Ж. <- 3 (дворф)    37 Механогномы <- 7 (гном)
```

Поэтому после пересборки персонаж кастомной расы **создаётся и входит в мир**,
а его модель в мире — донорская (это ожидаемо и безопасно: серверный
`ChrRaces.db2` подменять нельзя без `tools\check_db2_build.ps1`, иначе `ASSERT`
по `LayoutHash`).

---

## Изменённые файлы

| Файл | Изменение |
|------|-----------|
| `core/src/server/game/Entities/Player/Player.cpp` | `ValidateAppearance`: донорская раса для 31..44; `IsSectionFlagValid`: creation-контекст при входе; `LoadFromDB`: без кика + WARN с деталями; подсказки в путях кика (race/class, map coords) |
| `core/src/server/game/Handlers/CharacterHandler.cpp` | `Player login REJECTED ...` / `Player login OK: ...` диагностика |
| `core/src/server/game/World/World.h`, `World.cpp` | `CONFIG_LOGIN_STRICT_APPEARANCE`, дефолт `Login.StrictAppearance = false` |
| `server/worldserver.conf.dist`, `core/src/server/worldserver/worldserver.conf.dist` | документация опции |

---

## Порядок применения

```bat
rem 1. Пересборка ядра (обязательно - правки в C++)
build_worldserver.bat        rem или build_server.bat от имени администратора

rem 2. SQL для кастомных рас (уже в манифесте apply_play_sql.ps1, применится сам)
rem    sql\50_uwow_custom_races.sql, sql\52_custom_races_31_44.sql

rem 3. Запуск
play.bat
```

### Что смотреть в `Server.log`
При старте:
```
>> Registered 14 custom client race(s) (ids 31-44) from CustomRaces.Definitions
```
При входе (успех):
```
Player login OK: '<имя>' (account 1) race 1 class 1 gender 0 level 1 map 0 zone 12 pos ... displayId 49
```
Если всё же кик — теперь причина видна явно:
```
Player::LoadFromDB: Player (<guid>) has wrong race/class (31/1), can't load.
  -> [LEGIONFORGE] There is no `playercreateinfo` row ... apply sql/50_* and sql/52_* ...
Player login REJECTED for guid <guid> (account 1): Player::LoadFromDB returned false -> client kicked.
```

---

## Ограничения (честно)
* Превью в окне создания — целиком клиентские DB2. Сервер не может «дорисовать»
  модель расы, которой нет в `CharSections.db2`/`CharStartOutfit.db2` клиента.
* Маски рас в `INT`-колонках БД (`spell_area.racemask`, `quest_template.AllowableRaces`
  и т.п.) физически не адресуют расы 33..44 — см. `docs/CUSTOM_RACES_31_44.md`.
* `Login.StrictAppearance = 0` ослабляет только сверку **внешности** по серверному
  DB2; все остальные проверки входа (аккаунт, бан, gender, race/class, homebind,
  координаты карты) остаются в силе.
