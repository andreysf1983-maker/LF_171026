# FIX 2026-10-14 (раунд 3) — второй («instance») сокет: вход не завершается

Разбор по вашим `server/Server.log` и `server/DBErrors.log` от **2026-10-14 08:56**.

## 0. Что уже починилось

В этом логе **больше нет** `WorldSocket::HandleAuthSession: Authentication failed`
— первопричина «окно входа висит» устранена, клиент доходит до мира, персонаж
`Monstr` реально логинится. `DBErrors.log` сократился до 539 строк.

---

## 1. Главная проблема: отсутствует второй (instance) сокет

### Улика
Лог забит одной строкой (сотни повторов):

```
Prevented sending of [SMSG_AURA_UPDATE ...]        to non existent socket 1 to [Player: Monstr ...]
Prevented sending of [SMSG_UPDATE_TALENT_DATA ...] to non existent socket 1 to [Player: Account: 1]
Prevented sending of [SMSG_SET_PROFICIENCY ...]    to non existent socket 1 to [Player: Account: 1]
```

`socket 1` = `CONNECTION_TYPE_INSTANCE`. Legion-клиент держит **два** TCP-соединения:
realm (0) и instance (1). Пакеты, маршрутизируемые на instance-сокет, просто
выбрасывались — клиент не получал ауры, таланты, владение оружием.

### Почему это и есть «грузит и выкидывает»
```
CMSG_PLAYER_LOGIN
  -> WorldSession::HandlePlayerLoginOpcode
       SendConnectToInstance(WorldAttempt1);   // и ВСЁ, персонаж НЕ грузится
...ждём, пока клиент откроет ВТОРОЙ сокет...
  -> World::ProcessLinkInstanceSocket
       -> session->AddInstanceConnection(sock)
       -> session->HandleContinuePlayerLogin()  // <- вот здесь грузится персонаж
```

`HandlePlayerLoginOpcode` **не загружает персонажа** — он только просит клиент
подключиться вторым сокетом. Загрузка (`LoginQueryHolder` → `HandlePlayerLogin`)
запускается **исключительно** из `ProcessLinkInstanceSocket`. Если кастомный клиент
второй сокет не открыл (или сразу закрыл) — **логин не завершается никогда**:
бесконечный экран загрузки и выброс из игры.

### Почему это было невозможно диагностировать
Все пути отказа второго сокета были **полностью молчаливыми**:

| Путь | Было |
|------|------|
| `_type != CONNECTION_TYPE_INSTANCE` | `SendAuthResponseError(ERROR_DENIED)` без единой строки в лог |
| сессия не найдена | `ERROR_TIMED_OUT`, молча |
| `GetConnectToInstanceKey() != key` | `ERROR_TIMED_OUT`, молча |

### Что исправлено

1. **`WorldSession::SendPacket`** — если instance-сокета нет, пакет уходит по
   realm-сокету (`Network.InstanceSocketFallback = 1`), а не выбрасывается.
   Предупреждение пишется **один раз на сессию**, а не на каждый пакет.
2. **`HandlePlayerLoginOpcode`** — при `Login.RequireInstanceConnection = 0`
   логин продолжается сразу, не дожидаясь второго сокета.
3. **`HandleContinuePlayerLogin`** — защита от повторного вызова
   (`m_loginContinued`): раньше второй вызов приводил к `KickPlayer()`.
   Теперь поздно пришедший instance-сокет просто линкуется.
4. **`World::ProcessLinkInstanceSocket`** — явные логи всех отказов; несовпадение
   64-битного ConnectTo-ключа больше не рвёт логин (кастомный клиент может
   возвращать ключ с другой раскладкой битовых полей).
5. **`WorldSocket::HandleAuthContinuedSession`** — логируется отказ по типу соединения.

---

## 2. Персонаж не создаётся

### Улика
```
Player::Create: Possible hacking-attempt: Account 1 tried creating a character
named 'Монстр' with invalid appearance attributes - refusing to do so
```

### Причина
`Player::Create` → `ValidateAppearance(create = true)` → `IsSectionValid` →
`sDB2Manager.GetCharSectionEntry(race, gender, variation, index, color)`.
Индексы внешности (кожа/лицо/причёска/customDisplay) берутся из **клиентского**
`CharSections.db2`. У кастомного клиента там свои диапазоны и свои расы, которых в
**серверном** официальном `CharSections.db2` нет вообще → `nullptr` → отказ.

Проверка по расе-донору (раунд 2) этого не закрывала: у донора (тролль/человек)
попросту **другие индексы** причёсок и лиц.

### Что исправлено
`Player::ValidateAppearance` переписана: теперь она определяет, **какой именно**
компонент не прошёл, и при `Login.StrictAppearance = 0` принимает внешность,
записав понятный `WARN`:

```
ValidateAppearance: race 35 (sections via race 8) class 1 gender 0: component Hair
(skin 3 face 2 hair 11/4 facial 0, custom 0/0/0) is absent from the SERVER
CharSections.db2 - accepted (Login.StrictAppearance=0, custom client).
```

Это одной правкой закрывает **и** отказ при создании, **и** кик при входе.

---

## 3. Исправлена моя же регрессия в `sql/102_*` (rev.1 → rev.2)

В `DBErrors.log` остались ровно 20 строк:

```
Table 'spell_loot_template' Entry 253113 does not exist but it is used by Spell 253113
... (253116 … 253168)
```

Эта ошибка означает: **спелл существует** и создаёт лут, а строки лут-шаблона нет.
`101_legionforge_dberrors_fixes.sql` вставляет плейсхолдеры для 253113..253159, но мой
`102` rev.1 шёл в манифесте **после** 101 и удалял их обратно — то есть молча отменял 101.

`102` rev.2:
* больше **ничего не удаляет** в диапазоне 253xxx–255xxx;
* **добавляет** валидные плейсхолдеры (Linen Cloth 2589, Chance 100) для всех **35**
  id из обоих прогонов лога, с `WHERE NOT EXISTS` (идемпотентно, не конфликтует со 101);
* дочищает `achievement_reward` (14 строк без награды), `gossip_menu` 11061 →
  несуществующий `TextId` 15442, и флаг `UNIT_NPC_FLAG_SPELLCLICK` у creature 130758.

Имена колонок сверены с запросами ядра (`AchievementMgr.cpp`: `entry, title_A, title_H, item`;
`ObjectMgr.cpp`: `MenuId, TextId`, `npc_text.ID`; `LootMgr.cpp`: `Entry, Item, Reference, …`) —
это защита от `ERROR 1054 Unknown column`, на которой проект уже спотыкался.

---

## 4. Новые опции `worldserver.conf`

```ini
Login.RequireInstanceConnection = 0   # не ждать второй сокет, чтобы завершить логин
Network.InstanceSocketFallback  = 1   # instance-пакеты слать по realm-сокету
Login.StrictAppearance          = 0   # не отклонять внешность кастомного клиента
AuthSession.VerifyDigest        = 0   # не ронять мир-сокет из-за чужого дайджеста
```
Все дефолты заданы в коде — работают даже без строк в вашем `worldserver.conf`.
Для ванильного клиента выставьте всё в `1`/`0` соответственно (строгий режим).

---

## 5. Применение

```bat
build_worldserver.bat     rem обязательно: правки в C++
play.bat                  rem sql/102 rev.2 применится автоматически
```

### Что смотреть в `Server.log`
Хорошо:
```
Instance (second) socket linked for account 1 from 127.0.0.1.
Player login OK: 'Monstr' (account 1) race 1 class 1 ... displayId 49
```
Если второго сокета нет — теперь это видно явно и **не ломает игру**:
```
<Player ...> has no instance (second) socket - routing instance packets over the
realm socket (Network.InstanceSocketFallback=1). Further messages ... suppressed.
```
Флуд `Prevented sending ... to non existent socket 1` должен исчезнуть полностью.

---

## 6. Остаточные сообщения (безопасны, не трогаем)
* `SmartAIMgr: ... Kill Credit / creature summon` — описание нормальных скриптов.
* `WaypointMovementGenerator ... doesn't have waypoint path id` — пара спавнов стоит на месте.
* `areatrigger ... wrong spawn mask` — ядро уже индексирует маски по map id.
* `Received not handled opcode [CMSG_BATTLE_PAY_*]`, `ResourcesService.GetContentHandle` —
  магазин/ресурсы Blizzard, в эмуляторе не реализованы, на игру не влияют.
* `SpellEffect record N: invalid SpellID 304000..305010` — кастомный контент
  LegionForge ссылается на спеллы, которых нет в `Spell.db2` 26124; эффекты
  пропускаются, сервер стартует нормально.

---

## 7. Исправлена ошибка компиляции (обнаружена при вашей сборке)

Ваш `build_log.txt`:

```
D:\legionforge\core\src\server\game\Handlers\CharacterHandler.cpp(935,5):
error C2039: "GetLevel": не является членом "Player".
```

Причина — моя ошибка в диагностической строке `Player login OK`: в этом ядре
аксессор уровня называется **`getLevel()`** (строчная, объявлен в `Unit.h:1043`:
`uint8 getLevel() const { return uint8(GetUInt32Value(UNIT_FIELD_LEVEL)); }`),
а `GetLevel()` не существует.

Исправлено: `uint32(pCurrChar->GetLevel())` → `uint32(pCurrChar->getLevel())`.

Остальные вызовы той же строки сверены с заголовками ядра и валидны:
`GetName()` (`Object.h:445`), `GetZoneId()` (`Object.h:439`),
`GetByteValue()` (`Object.h:149`), `GetMapId()` (`Position.h:280`),
`GetDisplayId()` (`Unit.h:1709`), `GetPositionX/Y/Z()`.

Дополнительно проверено перед повторной сборкой:
* все 4 новых конфига объявлены в `enum BoolConfigs` **до** `BOOL_CONFIG_VALUE_COUNT`
  (иначе массив `m_bool_configs` был бы слишком мал) и имеют `GetBoolDefault`;
* `UI64FMTD` действительно доступен в `World.cpp` (используется там же в оригинале,
  строки 909 и 2136);
* баланс скобок во всех 7 изменённых `.cpp/.h` — нулевой;
* число форматных спецификаторов совпадает с числом аргументов в каждом новом
  `LF_LOG_*`.

---

## 8. Исправлена ошибка SQL: `Table 'world.item_template' doesn't exist`

Ваш лог `play.bat`:

```
[*] applying 102_legionforge_dberrors_final.sql -> world...
    ERROR 1146 (42S02) at line 49: Table 'world.item_template' doesn't exist
[!] FAIL 102_legionforge_dberrors_final.sql (mysql exit 1)
[ОШИБКА] SQL-патчер завершился с ошибкой.
    Сервер не будет запущен до исправления базы.
```

### Причина — снова моя ошибка
В `102` rev.2 я «подстраховался» проверкой существования предмета:

```sql
WHERE EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = 2589)
```

Но это **Legion-ядро**: `ObjectMgr::LoadItemTemplates()` строит шаблоны предметов
из **DB2** (`sItemSparseStore` + `sItemStore`), поэтому таблицы `item_template` в
world-базе **нет вообще** — есть только `item_template_addon`. Проверка обращалась
к несуществующей таблице и валила весь патчер.

### Исправление (rev.3)
Guard удалён — вставка идёт с тем же условием идемпотентности, что и в `101_*`:

```sql
WHERE NOT EXISTS (SELECT 1 FROM `spell_loot_template` t WHERE t.`Entry` = x.`Entry`);
```
Предмет 2589 (Linen Cloth) — предмет Vanilla, присутствующий в `Item.db2` /
`ItemSparse.db2` любого клиента; `101_*` уже вставляет тот же плейсхолдер успешно
(его проверка DBE-15 показывает `0` отсутствующих), поэтому отдельная проверка не нужна.

### Защита от повторения
В проекте уже был `tools/audit_sql_columns.py`, созданный ровно после похожей
ошибки `ERROR 1054 Unknown column` в `101` rev.1. Я обязан был запускать его перед
отправкой SQL — и не запустил. Проверено:

```
$ python3 tools/audit_sql_columns.py sql/103_bad_test.sql   # 102 rev.2 с плохим guard
[STRICT] sql/103_bad_test.sql: 1 unverified
    - table `item_template` is never used by the core        # <-- он ДАЖЕ это поймал
$ echo $?
1
```
Теперь аудит прогнан по **всему** манифесту `apply_play_sql.ps1` — все файлы `OK`,
включая `100_*`, `101_*`, `102_*` (STRICT-режим).

## 9. Косметические патчи больше не блокируют запуск сервера

Даже после исправления осталась архитектурная проблема: **чистка журнала
DBErrors.log не должна останавливать сервер.** `102` rev.2 упал на косметике — и
`play.bat` полностью отказался поднимать worldserver.

В `apply_play_sql.ps1` добавлен флаг `Soft = $true` для патчей-чисток
(`100_*`, `101_*`, `102_*`):

```powershell
@{ Db = "world";  File = "102_legionforge_dberrors_final.sql";  Soft = $true }
```

```powershell
if ($p.ContainsKey("Soft") -and $p.Soft) {
    Write-Host "  [!] SOFT-FAIL $label ... - DBErrors.log cleanup only, server will still start"
    continue          # НЕ увеличивает $fail и НЕ прерывает цикл
}
```

Схема и игровые данные (`playercreateinfo`, `race_unlock_requirement`, инстансы,
квесты, лут-таблицы и т.д.) остаются **жёсткими**: любая ошибка там по-прежнему
останавливает запуск с `exit 1` — там падать надо громко, иначе сервер поднимется
и упадёт позже с крэш-дампом.

## 10. Замечания из того же лога (действия не требуются)

* `Нет файла worldserver.conf` — предупреждение `check_server_runtime.ps1`.
  `play.bat` (строка 209) вызывает `tools\ensure_conf_keys.ps1`, который **сам**
  создаёт `*.conf` из `*.conf.dist` и дописывает недостающие ключи — включая все
  новые (`Login.RequireInstanceConnection`, `Network.InstanceSocketFallback`,
  `Login.StrictAppearance`, `AuthSession.VerifyDigest`).
* `52_custom_races_31_44.sql: startItemRows = 0` — в Legion стартовая экипировка
  приходит из клиентского `CharStartOutfit.db2`, а не из `playercreateinfo_item`;
  в этой базе таблица пуста для рас-доноров. Это ожидаемо, персонажи стартуют
  снаряжёнными.
* `Контроль сборки: EXE и исходники DB2/SpellEffect совпадают` — сборка после
  исправления `C2039` **прошла успешно**, `worldserver.exe` и `bnetserver.exe`
  на месте, `OPENSSL_Applink` в порядке.
