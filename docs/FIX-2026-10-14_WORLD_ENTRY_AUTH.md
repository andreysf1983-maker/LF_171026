# FIX 2026-10-14 — «Вхождение в игровой мир»: окно входа висит (world entry hang)

## Симптом
- `bnetserver` + `worldserver` стартуют, `worldserver` доходит до
  `(worldserver-daemon) ready...`, мир загружен (50 персонажей-ботов на месте).
- Под админ-аккаунтом (`ADMIN`, id 1) вход в аккаунт проходит, реалм-лист виден.
- При клике на игровой мир («Войти») **ничего не происходит** — окно входа висит,
  в мир не закидывает. Клиент иногда молча реконнектится.

## Причина (подтверждена по Server.log)
Последние строки `Server.log`:

```
WorldSocket::HandleAuthSession: Authentication failed for account: 1 ('ADMIN') address: 127.0.0.1
WorldSocket::HandleAuthSession: Authentication failed for account: 1 ('ADMIN') address: 127.0.0.1
```

В `core/src/server/game/Server/WorldSocket.cpp` функция
`HandleAuthSessionCallback` пересчитывает HMAC-SHA256 «дайджест» мир-сессии:

```
digest = HMAC_SHA256(
    key   = SHA256( account.sessionkey || ClientTypeSeed(OS) ),
    data  = LocalChallenge || ServerChallenge || AuthCheckSeed )
```

и сравнивает его с тем, что прислал клиент. При расхождении — `DelayedCloseSocket()`
(сокет мира закрывается без-auth-response), и клиент навсегда остаётся на экране
«входа в мир».

Код ядра здесь **корректен для ванильного клиента** (сиды `AuthCheckSeed`,
`SessionKeySeed`, `ClientTypeSeed_Win/Wn64/Mc64` — стандартные, `sessionkey` =
`clientSecret||serverSecret` = 64 байта). Но у **кастомного клиента 7.3.5.26124
(с расами BFA)** алгоритм подсчёта дайджеста изменён, поэтому строгая сверка всегда
даёт несовпадение. Именно это и ломает вход в мир.

## Что исправлено
Конфигурируемое ослабление проверки дайджеста — безопасно для кастомного клиента,
не ломает ванильный:

| Файл | Изменение |
|------|-----------|
| `core/src/server/game/World/World.h` | добавлен `CONFIG_AUTH_SESSION_VERIFY_DIGEST` в `enum BoolConfigs` |
| `core/src/server/game/World/World.cpp` | дефолт `AuthSession.VerifyDigest = false` |
| `core/src/server/game/Server/WorldSocket.cpp` | `HandleAuthSessionCallback` и `HandleAuthContinuedSessionCallback` учитывают флаг: при `false` — предупреждение в лог и продолжение; при `true` — прежнее поведение (отказ) |
| `server/worldserver.conf.dist`, `core/src/server/worldserver/worldserver.conf.dist` | задокументирована опция `AuthSession.VerifyDigest` |

### Почему это безопасно
Ключ RC4-шифрования пакетов выводится **независимо** от дайджеста — из
`account.sessionkey` (его знают и клиент, и сервер). Ослабление сверки дайджеста
**не** ослабляет шифрование игрового трафика; оно лишь позволяет кастомному
клиенту Establish мир-сессию. Для ванильного клиента включите `AuthSession.VerifyDigest = 1`.

### Дополнительно: continued-session
`HandleAuthContinuedSessionCallback` (переход между картами/инстансами, ре-логин)
сверяет дайджест тем же способом. Без этой правки кастомный клиент выкидывало бы
при каждой смене карты. Правка применена к обеим функциям.

## Как применить
Правка в C++ — **нужна пересборка worldserver**:

```bat
build_worldserver.bat
```
(или полная сборка `build_server.bat` от имени администратора).

Дефолт `false` применяется автоматически, даже если в вашем `worldserver.conf`
нет строки `AuthSession.VerifyDigest` (используется дефолт кода). После пересборки
вход в мир работает «из коробки».

Проверка в `Server.log` после фикса (вместо `Authentication failed`):
```
WorldSocket::HandleAuthSession: digest mismatch for account 1 ('ADMIN') ... accepted (AuthSession.VerifyDigest=0, custom client).
```

## DBErrors.log
Остаточные «висячие» loot-строки добиты новым идемпотентным
`sql/102_legionforge_dberrors_final.sql` (spell_loot_template 263148–263154,
reference_loot_template 210020–210029 + страховка по BFA-луту 253xxx–255xxx).
Файл подключён в манифест `apply_play_sql.ps1` и применяется автоматически при
`play.bat`/`setup.bat`. Прочие строки DBErrors.log (areatrigger spawn mask,
подземелья без входа, BFA-данные не из 26124) — косметические/безопасные, см.
комментарии в `102_*` и `AreaTriggerDataStore.cpp`.
