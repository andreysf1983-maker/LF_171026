# Извлечение карт и запуск сервера: разбор трёх ошибок

> Legion 7.3.5 build 26124. Патчи: `patchkit/patch_core.py`, `patchkit/patch_scripts.py`.

## 1. `extract_maps.bat` → пункт 2 обрывается на шаге vmaps

### Симптом

```
  [*] Шаг 2/4: vmaps (может занять десятки минут)...
vmap4extractor.exe : Can't open World\Maps\test\test.wdt: FILE_NOT_FOUND
D:\legionforge\extract_delta.ps1:119 знак:9
+         & $tools.vmap4extractor -d $ClientDir 2>&1 | Out-Null
    + CategoryInfo          : NotSpecified: (Can't open Worl... FILE_NOT_FOUND:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
```

### Причина (две независимые)

1. **PowerShell.** `extract_delta.ps1` работает с `$ErrorActionPreference = 'Stop'`.
   В Windows PowerShell 5.1 любая строка, которую внешняя программа пишет в
   **stderr**, при перенаправлении `2>&1` в конвейер превращается в
   `NativeCommandError` — то есть в *исключение*. Первое же предупреждение
   экстрактора убивало скрипт, и vmaps/mmaps не извлекались вовсе.
2. **Экстрактор.** `World\Maps\test\test.wdt` — dev/test-карта: она есть в
   `Map.db2` клиента, но файлов геометрии в CASC не имеет. `vmap4extractor`
   писал об этом в **stderr**, хотя это штатная ситуация.

### Исправление

* `core/src/tools/vmap4_extractor/wdtfile.cpp`
  * `CASCFile` открывается с `warnNoExist = false` — отсутствие WDT больше не
    попадает в stderr;
  * диагностика выведена в **stdout**: `Skipping map 'test': no WDT in the client storage (dev/test map)`.
* `core/src/tools/vmap4_extractor/vmapexport.cpp`
  * счётчик пропущенных карт и итоговая сводка `[INFO] Skipped N map(s) without WDT ...`;
  * извлечение продолжается по остальным картам.
* `extract_delta.ps1`
  * новая функция `Invoke-LfTool` — временно переключает `EAP` на `Continue`,
    разворачивает `ErrorRecord` в текст, фильтрует штатные сообщения
    (`FILE_NOT_FOUND`, `Can't open *.wdt`, `Skipping map`), пишет вывод в
    `server\logs\extract_delta_*.log` и **возвращает код возврата**
    (`$LASTEXITCODE` из функции наружу не виден);
  * все четыре вызова (`mapextractor`, `vmap4extractor`, `vmap4assembler`,
    `mmaps_generator`) переведены на неё;
  * подкаталоги staging (`maps/dbc/Cameras/gt/Buildings/vmaps/mmaps`) создаются
    **до** запуска инструментов;
  * шаг vmaps обёрнут в `try/catch`: сбой не отменяет уже скопированные
    maps/dbc;
  * `mmaps` считаются только при нулевом коде возврата, список неудачных карт
    попадает в `reports\extract_delta.json` (`FailedMmaps`);
  * туда же пишется `IgnoredToolLines` — сколько штатных сообщений отфильтровано.
* `extract_maps.ps1` — та же защита `EAP = 'Continue'` внутри обёртки запуска
  инструментов.

### Как проверить

```bat
extract_maps.bat
rem -> 2 (доизвлечь ТОЛЬКО недостающее)
type reports\extract_delta.json
```

Ожидаемо: шаг 2/4 проходит, в логе строки `Skipping map 'test' ...`,
в отчёте `FailedMmaps` пуст или содержит только реально проблемные карты.

## 2. `bnetserver`: Failed to initialize SSL context

### Симптом

```
Using configuration file bnetserver.conf.
Using SSL version: OpenSSL 3.5.9 ...
Failed to initialize SSL context
```

и **ни одной** подробности.

### Причина

`Battlenet::SslContext::Initialize()` писал настоящую причину в категорию
`server.ssl`, которой нет в `bnetserver.conf` → в консоль уходила только общая
строка из `Main.cpp`. Содержательно причины три:

1. `CertificatesFile = "./bnetserver.cert.pem"` — путь **относительно текущего
   каталога процесса**. При запуске через ярлык/планировщик/`start /D` из другой
   папки файлы не находятся.
2. `.pem` не скопированы в каталог сборки.
3. Сертификат и ключ от **разных** пар (обновили один файл).

### Исправление

* `core/src/server/bnetserver/Server/SslContext.cpp` — переписан:
  * поиск `.pem` по цепочке каталогов: как задано в конфиге → имя файла в CWD →
    каталог `bnetserver.exe` → `..` → `../server`;
  * проверка соответствия пары через `X509_check_private_key`;
  * при отсутствии/рассинхроне — **автогенерация** самоподписанной пары
    (RSA-2048, SHA-256, 10 лет) через `EVP_RSA_gen` (OpenSSL 3.x) с fallback на
    `RSA_generate_key` для 1.1.x;
  * вывод очереди ошибок OpenSSL (`ERR_error_string_n`) в лог;
  * ключ `SSLCertAutoGenerate` (по умолчанию 1) — при 0 ядро падает, как раньше;
  * итоговая строка `SSL context initialized (cert=..., key=..., auto-generated=...)`.
* `core/src/server/bnetserver/Main.cpp` — к общей ошибке добавлена подсказка,
  что смотреть и где включить подробный лог.
* `server/bnetserver.conf.dist` — добавлены `SSLCertAutoGenerate = 1`,
  `Logger.server.ssl=3,Console Bnet`, `Logger.server.bnetserver=3,Console Bnet`.
* `tools\ensure_ssl_cert.ps1` (новый) — префлайт на стороне окружения:
  наличие, **соответствие пары** (сравнение публичных ключей), алгоритм подписи
  (SHA-1/MD5 отклоняются OpenSSL 3.x при SECLEVEL≥1), срок действия;
  при проблеме делает `*.bak-<дата>` и генерирует новую пару.
* `play.bat` — вызывает `ensure_conf_keys.ps1` и `ensure_ssl_cert.ps1` перед
  стартом `bnetserver.exe`.

Пара из репозитория (`server/bnetserver.cert.pem` + `bnetserver.key.pem`)
проверена: RSA-2048, `sha256WithRSAEncryption`, срок 2016→2036, публичные ключи
совпадают. Значит у вас сработал пункт 1 или 2 — патч закрывает оба.

## 3. `Missing name Guild.SaveInterval in config file`

### Причина

`server/worldserver.conf.dist` ключ **содержит** (`Guild.SaveInterval = 15`),
а живой `D:\legionforge\server\worldserver.conf` создан из более старого
дистрибутива — ключа в нём нет. Ядро читает его обязательно и пишет
предупреждение.

### Исправление

`tools\ensure_conf_keys.ps1` (новый):

* если `*.conf` отсутствует — создаёт его из `*.conf.dist`;
* сравнивает наборы ключей `.dist` и живого `.conf` и **дописывает все
  отсутствующие** (значение по умолчанию берётся из `.dist`);
* существующие значения не трогает, делает `*.conf.bak-<дата>`;
* отчёт: `reports\ensure_conf_keys.json`;
* режим `-WhatIfMode` — показать, ничего не меняя.

Вызов встроен в `play.bat` (до старта серверов), поэтому предупреждение больше
не появляется и после обновления дистрибутива.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1 -WhatIfMode
```

## 4. Что осталось сделать руками

1. Пересобрать ядро (`MAX_RACES` — константа времени компиляции): `build_server.bat`.
2. Пересобрать `vmap4extractor.exe` (патч stderr) и заменить его в `server\`.
3. Применить `sql\52_custom_races_31_44.sql` к базе `world`.
4. Запустить `play.bat` и проверить строку
   `>> Registered 14 custom client race(s) (ids 31-44)` в логе worldserver.
