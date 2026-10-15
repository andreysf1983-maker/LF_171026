@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Состояние сервера
::   Файл: server_status.bat
::
::   Показывает:
::     - доступность MySQL
::     - наличие баз данных auth / characters / world / hotfixes
::     - слушаемые порты 1119 (bnet) и 8095 (world)
::     - запущенные процессы сервера
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "TMP_DIR=%ROOT%\setup_tmp"
set "MYSQL_CNF=%TMP_DIR%\mysql.cnf"

title LEGIONFORGE 7.3.5 - Состояние сервера
color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - состояние сервера
echo  =========================================================
echo.

set "MYSQL="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_mysql.ps1" -Port 3306`) do set "MYSQL=%%P"

if exist "%MYSQL%" (
    echo  [OK] MySQL найден: !MYSQL!
) else (
    echo  [ВНИМАНИЕ] MySQL не найден или не запущен.
)

if exist "%MYSQL_CNF%" (
    echo  [OK] Файл подключения к MySQL: !MYSQL_CNF!
) else (
    echo  [ВНИМАНИЕ] Файл подключения не найден, выполните setup.bat.
)

echo.
echo  [*] Порты:
call :SHOWPORT 1119 "bnetserver (вход в игру)"
call :SHOWPORT 8095 "worldserver (мир игры)"
call :SHOWPORT 3306 "MySQL"

echo.
echo  [*] Процессы:
tasklist /FI "IMAGENAME eq worldserver.exe" 2>nul | findstr /I "worldserver.exe" >nul && echo  [OK] worldserver.exe запущен. || echo  [-] worldserver.exe не запущен.
tasklist /FI "IMAGENAME eq bnetserver.exe" 2>nul | findstr /I "bnetserver.exe" >nul && echo  [OK] bnetserver.exe запущен.  || echo  [-] bnetserver.exe не запущен.

echo.
if exist "%MYSQL_CNF%" (
    echo  [*] Подробная информация из баз данных:
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\server_status.ps1" -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
)

echo.
pause
exit /b 0

:SHOWPORT
netstat -ano | findstr "LISTENING" | findstr ":%1 " >nul
if errorlevel 1 (
    echo  [-] Порт %1 свободен - %2
) else (
    echo  [OK] Порт %1 занят   - %2
)
exit /b 0
