# Журналы и отчёты о падениях

## Было

`worldserver.conf` / `bnetserver.conf` содержали `LogsDir = ""`, поэтому все
файлы писались в рабочий каталог процесса — то есть прямо в `server\`:

```
server\Server.log
server\DBErrors.log
server\SQLUpdate.log
server\Auth.log
server\<hash>_worldserver_[12-10_22-13-05].txt   (отчёт о падении)
server\<hash>_worldserver_[12-10_22-13-05].dmp   (минидамп)
```

## Стало

```
server\logs\      Server.log, DBErrors.log, SQLUpdate.log, Auth.log, gm\, runs\
server\Crashes\   *.txt (WheatyExceptionReport) и *.dmp (минидампы)
```

Что для этого сделано:

1. `server\worldserver.conf.dist` и `server\bnetserver.conf.dist`:
   `LogsDir = "logs"`.
2. `patch_conf_paths.ps1` при каждом запуске прописывает в рабочие
   `*.conf` абсолютный путь `…\server\logs` и создаёт папки.
3. Новый `tidy_server_dirs.ps1`:
   - создаёт `server\logs`, `server\logs\gm`, `server\Crashes`;
   - переносит туда файлы, которые уже лежат в корне `server`;
   - удаляет журналы и дампы старше `-KeepDays` (по умолчанию 30 суток).
4. `play.bat` вызывает `tidy_server_dirs.ps1` перед стартом процессов,
   поэтому корень `server` остаётся чистым: только exe, dll, conf и `data`.

Отчёты о падениях всегда писались в `server\Crashes` самим ядром
(`core/src/common/Debugging/WheatyExceptionReport.cpp`, `#define CrashFolder
_T("Crashes")`) — папка создаётся рядом с exe. Теперь туда же попадают
старые дампы из корня, а разбор делает `tools\resolve_crash.ps1`.

## Как пользоваться

```bat
rem привести папку в порядок и почистить старое (хранить 14 дней)
powershell -NoProfile -ExecutionPolicy Bypass -File tidy_server_dirs.ps1 -KeepDays 14

rem последний отчёт о падении
dir /b /o-d server\Crashes\*.txt

rem хвост основного журнала
powershell -Command "Get-Content server\logs\Server.log -Tail 100"
```

## Уровни журналирования

Блок `Appender.*` / `Logger.*` в `worldserver.conf` не менялся — изменился
только корень. То есть `Appender.Server=2,2,0,Server.log,w` теперь создаёт
`server\logs\Server.log`, а `Appender.GM=2,2,15,gm/gm_%s.log` —
`server\logs\gm\gm_<имя>.log`.
