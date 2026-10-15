# Сервер собран, но не запускается

## Что проверяет play.bat
Перед запуском `bnetserver.exe` и `worldserver.exe` скрипт `check_server_runtime.ps1` проверяет,
что рядом с exe есть все нужные библиотеки (DLL), и копирует недостающие:

- `libmysql.dll` (из `tools\mysql`);
- `libssl-3-x64.dll`, `libcrypto-3-x64.dll` (из `tools\openssl`);
- `boost_*-vc143-*.dll` (из `tools\boost_*`, если Boost подключён динамически);
- `vcruntime140.dll`, `msvcp140.dll` и др. (из папки Redistributable установленной Visual Studio / Build Tools).

Если какой-то библиотеки нет нигде, `play.bat` остановится с сообщением, а не закроет окно.
Подробный отчёт записывается в `server\runtime_check.txt`.

## Почему раньше exe «открывался и закрывался»
Процесс без нужной DLL завершается сразу. Окно `bnetserver` и `worldserver` запускалось свёрнутым,
поэтому системное сообщение «не найден VCRUNTIME140.dll» было не видно. Сборка копировала
в `server\` только DLL из `build\bin\Release`, но не библиотеки из `tools\` и не runtime Visual C++.

## Если всё равно не запускается
1. Откройте `server\runtime_check.txt` и пришлите его содержимое.
2. Запустите сервер вручную из консоли, чтобы увидеть ошибку:
   ```bat
   cd server
   worldserver.exe -c worldserver.conf
   ```
3. Если Windows показывает «VCRUNTIME140.dll не найден», установите
   Microsoft Visual C++ Redistributable x64: https://aka.ms/vs/17/release/vc_redist.x64.exe
4. Проверьте, что `server\data\maps`, `server\data\vmaps` и `server\data\dbc\Map.db2` на месте
   (проверка выполняется в play.bat).

## Ручной запуск проверки
```bat
powershell -NoProfile -ExecutionPolicy Bypass -File check_server_runtime.ps1
```
Режим только проверки, без копирования файлов: добавьте `-CheckOnly`.
