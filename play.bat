@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Запуск сервера и клиента
::   Файл: play.bat
::
::   Что делает:
::     1. Проверяет наличие MySQL и запускает его при необходимости
::     2. Применяет недостающие SQL-патчи (идемпотентные)
::     3. Запускает bnetserver (порт 1119) и ждёт его готовности
::     4. Запускает worldserver (порт 8085) и ждёт его готовности
::     5. Запускает клиент игры с патчем подключения
::
::   Повторный запуск безопасен: работающие процессы не дублируются.
::   Кодировка: OEM CP866, окончания CRLF, кодовая страница 866.
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"
set "SQL_DIR=%ROOT%\sql"
set "TMP_DIR=%ROOT%\setup_tmp"
set "MYSQL_CNF=%TMP_DIR%\mysql.cnf"
set "LOG_FILE=%ROOT%\play_log.txt"

title LEGIONFORGE 7.3.5 - Запуск сервера
color 0A

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - запуск сервера
echo  =========================================================
echo.
echo  [%date% %time%] Запуск > "%LOG_FILE%"

:: ---- Проверка установленного сервера ----
if not exist "%SERVER_DIR%\worldserver.exe" (
    echo  [ВНИМАНИЕ] worldserver.exe не найден в папке server
    echo      Сначала выполните установку: setup.bat
    pause
    exit /b 1
)
if not exist "%SERVER_DIR%\bnetserver.exe" (
    echo  [ВНИМАНИЕ] bnetserver.exe не найден в папке server
    echo      Сначала выполните установку: setup.bat
    pause
    exit /b 1
)

:: ---- Поиск MySQL ----
echo  [*] Проверка MySQL...
set "MYSQL="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_mysql.ps1" -Port 3306`) do set "MYSQL=%%P"
if not exist "%MYSQL%" (
    echo  [ВНИМАНИЕ] MySQL не найден или не запущен.
    echo      Запустите setup.bat для установки и настройки MySQL.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_mysql.ps1" -Port 3306 -EnsureRunning >nul 2>&1
echo  [OK] MySQL доступен: %MYSQL%

:: ---- Проверка баз перед патчами и запуском ----
echo.
echo  [*] Проверка схем world и hotfixes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\check_database_schema.ps1" -Database world -MysqlExe "%MYSQL%" -CnfPath "%MYSQL_CNF%"
if errorlevel 1 (
    echo  [ОШИБКА] База world отсутствует или неполная. Запустите setup.bat и проверьте setup_log.txt.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\check_database_schema.ps1" -Database hotfixes -MysqlExe "%MYSQL%" -CnfPath "%MYSQL_CNF%"
if errorlevel 1 (
    echo  [ОШИБКА] База hotfixes отсутствует или неполная. Запустите setup.bat и проверьте setup_log.txt.
    pause
    exit /b 1
)

:: ---- Порядок в папке server: журналы -> server\logs, падения -> server\Crashes ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tidy_server_dirs.ps1" -Root "%ROOT%" -KeepDays 30

:: ---- Проверка извлечённых игровых данных ----
if not exist "%SERVER_DIR%\data\maps" (
    echo  [ОШИБКА] Нет server\data\maps. Повторно запустите extract_maps.bat.
    pause
    exit /b 1
)
dir /b /a-d "%SERVER_DIR%\data\maps\*.map" >nul 2>&1
if errorlevel 1 (
    echo  [ОШИБКА] В server\data\maps нет файлов .map. Повторно запустите extract_maps.bat.
    pause
    exit /b 1
)
if not exist "%SERVER_DIR%\data\dbc" (
    echo  [ОШИБКА] Нет server\data\dbc. Повторно запустите extract_maps.bat.
    pause
    exit /b 1
)
dir /s /b /a-d "%SERVER_DIR%\data\dbc\Map.db2" >nul 2>&1
if errorlevel 1 (
    echo  [ОШИБКА] Map.db2 не найден. Повторно запустите extract_maps.bat.
    pause
    exit /b 1
)
:: ---- Проверка DB2 на соответствие ядру и билду клиента ----
:: Без неё worldserver падает на ASSERT при загрузке данных, например:
:: BATTLE_PET_SPECIES_MAX_ID (2164) must be equal to or greater than 5004
echo  [*] Проверка DB2 (dbc) на соответствие ядру...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\check_db2_build.ps1" -Root "%ROOT%"
if errorlevel 1 (
    echo  [ОШИБКА] Файлы DB2 в server\data\dbc не подходят к этому ядру.
    echo      Причина и что делать - в сообщениях выше и в docs\CRASH-DIAGNOSIS.md.
    echo      Скорее всего папка data скопирована из другого клиента: извлеките её заново
    echo      из своего клиента 7.3.5 build 26124 через extract_maps.bat.
    pause
    exit /b 1
)
echo  [OK] DB2 соответствуют ядру.

if not exist "%SERVER_DIR%\data\vmaps" (
    echo  [ОШИБКА] Нет server\data\vmaps. Завершите извлечение vmaps через extract_maps.bat.
    pause
    exit /b 1
)
dir /b /a-d "%SERVER_DIR%\data\vmaps\*.vmtree" >nul 2>&1
if errorlevel 1 (
    echo  [ОШИБКА] В server\data\vmaps нет файлов .vmtree. Завершите извлечение vmaps.
    pause
    exit /b 1
)

:: Настройка OpenSSL ДО первой проверки runtime: иначе диагностика ложно
:: предупреждает, что OPENSSL_CONF не задана, хотя play.bat установит её позже.
if not defined OPENSSL_CONF (
    set "OPENSSL_CONF=%~dp0tools\openssl.cnf"
) else (
    if not exist "%OPENSSL_CONF%" set "OPENSSL_CONF=%~dp0tools\openssl.cnf"
)

:: ---- Проверка библиотек (DLL) для запуска exe ----
:: Без DLL (libmysql, OpenSSL, Boost, Visual C++ runtime) процесс закрывается сразу, поэтому проверяем заранее.
echo.
echo  [*] Проверка библиотек worldserver и bnetserver...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\check_server_runtime.ps1" -Root "%ROOT%" -ServerDir "%SERVER_DIR%"
if errorlevel 1 (
    echo  [ОШИБКА] Проверка runtime или версии сборки не пройдена.
    echo      Подробности и список файлов: server\runtime_check.txt
    echo      Выполните build_server.bat (шаг с tools^) или установите Visual C++ Redistributable x64.
    pause
    exit /b 1
)
echo  [OK] Библиотеки на месте.

:: ---- Применение недостающих SQL-патчей ----
echo.
echo  [*] Проверка и применение SQL-патчей LEGIONFORGE...
set "SQL_APPLY_FAILED="
call :APPLY hotfixes   "%SQL_DIR%\40_legionforge_items.sql"
call :APPLY world      "%SQL_DIR%\40_legionforge_items.sql"
call :APPLY world      "%SQL_DIR%\41_legionforge_minibosses.sql"
call :APPLY world      "%SQL_DIR%\42_legionforge_miniboss_loot.sql"
call :APPLY hotfixes   "%SQL_DIR%\43_legionforge_upgrade_tokens.sql"
call :APPLY world      "%SQL_DIR%\43_legionforge_upgrade_tokens.sql"
call :APPLY world      "%SQL_DIR%\44_legionforge_upgrade_limits.sql"
call :APPLY hotfixes   "%SQL_DIR%\44_legionforge_upgrade_limits.sql"
call :APPLY world      "%SQL_DIR%\45_legionforge_ancient_knowledge.sql"
call :APPLY world      "%SQL_DIR%\46_legionforge_playerbots.sql"
call :APPLY auth       "%SQL_DIR%\46_legionforge_playerbots.sql"
if defined SQL_APPLY_FAILED (
    echo  [ОШИБКА] Не удалось применить один или несколько SQL-патчей. Подробности: !LOG_FILE!
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\apply_play_sql.ps1" -Root "%ROOT%" -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
if errorlevel 1 (
    echo  [ОШИБКА] SQL-патчер завершился с ошибкой. Подробности показаны выше.
    echo      Сервер не будет запущен до исправления базы.
    pause
    exit /b 1
)
echo  [OK] SQL-патчи применены.

:: ---- Пути MySQL/исходников в конфигах ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\patch_conf_paths.ps1" -Root "%ROOT%" -MysqlExe "%MYSQL%"
if errorlevel 1 (
    echo  [ОШИБКА] Не удалось исправить пути в конфигурациях.
    pause
    exit /b 1
)

:: ---- [LEGIONFORGE FIX 2026-10] OpenSSL: OPENSSL_Applink / валидный конфиг ----
:: Фатальный выход "OPENSSL_Uplink(...): no OPENSSL_Applink" лечится в исходниках
:: (core\src\server\*\Main.cpp: #include <openssl/applink.c>) и требует пересборки.
:: Здесь - дополнительная диагностика и смягчение без пересборки: валидный
:: OPENSSL_CONF убирает самый частый триггер первой записи в stderr из DLL.
:: check_server_runtime.ps1 уже выполнил диагностику OpenSSL и проверил
:: соответствие бинарников исходникам; второй вызов не нужен.

:: ---- Проверка портов и запуск bnetserver ----
echo.
call :CHECKPORT 1119
if "!PORT_BUSY!"=="1" (
    echo  [OK] bnetserver уже работает, порт 1119 занят.
) else (
    echo  [*] Запуск bnetserver...
rem [LEGIONFORGE PATCH 2026-10] pre-flight: conf keys + SSL cert/key pair
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\ensure_conf_keys.ps1" -ServerDir "%SERVER_DIR%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\ensure_ssl_cert.ps1" -ServerDir "%SERVER_DIR%" >nul 2>&1
    start "LEGIONFORGE bnetserver" /min /D "%SERVER_DIR%" cmd /c "bnetserver.exe -c bnetserver.conf || pause"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\wait_bnet_ready.ps1" -ServerDir "%SERVER_DIR%" -Port 1119 -MaxWaitSec 45
    if errorlevel 1 (
        echo  [ВНИМАНИЕ] bnetserver не запустился за 45 секунд.
        echo      Проверьте файл !SERVER_DIR!\bnetserver.log
        pause
        exit /b 1
    )
    echo  [OK] bnetserver запущен и слушает порт 1119.
)

:: ---- Запуск worldserver ----
call :CHECKPORT 8085
if "!PORT_BUSY!"=="1" (
    echo  [OK] worldserver уже работает, порт 8085 занят.
) else (
    echo  [*] Запуск worldserver, загрузка мира занимает 1-3 минуты...
    start "LEGIONFORGE worldserver" /min /D "%SERVER_DIR%" cmd /c "worldserver.exe -c worldserver.conf || pause"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\wait_world_ready.ps1" -ServerDir "%SERVER_DIR%" -Port 8085
    if errorlevel 1 (
        echo  [ВНИМАНИЕ] worldserver не подтвердил готовность.
        echo      Проверьте журнал: !SERVER_DIR!\Server.log
        pause
        exit /b 1
    )
    echo  [OK] worldserver запущен и готов принимать игроков.
)

:: ---- Состояние сервера ----
echo.
echo  [*] Состояние сервера:
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\server_status.ps1" -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"

:: ---- Запуск клиента ----
echo.
set "CLIENT_EXE="
if exist "%ROOT%\client_path.txt" (
    set /p CLIENT_EXE=<"%ROOT%\client_path.txt"
)
if not exist "!CLIENT_EXE!" (
    for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_client.ps1" -Root "%ROOT%" -SavedPathFile "%ROOT%\client_path.txt"`) do set "CLIENT_EXE=%%P"
)

if exist "!CLIENT_EXE!" (
    for %%I in ("!CLIENT_EXE!") do set "CLIENT_DIR=%%~dpI"
    echo  [*] Применение патча клиента...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\patch_client.ps1" -ClientDir "!CLIENT_DIR!" >nul 2>&1
    echo  [*] Запуск клиента: !CLIENT_EXE!
    start "" /D "!CLIENT_DIR!" "!CLIENT_EXE!"
) else (
    echo  [ВНИМАНИЕ] Клиент игры не найден.
    echo      Запустите Wow-64.exe вручную из папки клиента.
)

echo.
echo  =========================================================
echo   Сервер LEGIONFORGE запущен.
echo  =========================================================
echo.
echo   Вход в игру:
echo     Логин:   admin@legionforge.ru
echo     Пароль:  legionforge
echo.
echo   Остановка сервера: закройте окна bnetserver и worldserver
echo   или используйте файл stop_server.bat.
echo.
echo   Основные консольные команды worldserver:
echo     .server info   - информация о сервере
echo     .gm on         - включить режим мастера игры
echo     .tele          - телепортация по имени точки
echo     .npc           - работа с неигровыми персонажами
echo.
pause
exit /b 0

:: ============================================================
::  Подпрограмма применения SQL-файла: call :APPLY база "файл"
:: ============================================================
:APPLY
if not exist %2 (
    echo  [ОШИБКА] Обязательный SQL-файл не найден: %2
    set "SQL_APPLY_FAILED=1"
    exit /b 1
)
"%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" --max_allowed_packet=512M %1 < %2 >nul 2>&1
set "LF_SQL_EXIT=!errorlevel!"
echo  [%date% %time%] %~nx2 к базе %1, код ошибки !LF_SQL_EXIT! >> "%LOG_FILE%"
if not "!LF_SQL_EXIT!"=="0" set "SQL_APPLY_FAILED=1"
exit /b !LF_SQL_EXIT!

:: ============================================================
::  Подпрограмма проверки порта: call :CHECKPORT порт
::  Результат в переменной PORT_BUSY: 1 - занят, 0 - свободен
:: ============================================================
:CHECKPORT
set "PORT_BUSY=0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr "LISTENING" ^| findstr ":%1 "') do set "PORT_BUSY=1"
exit /b 0
