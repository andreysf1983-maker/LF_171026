@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

title LEGIONFORGE - Запуск MySQL
echo.
echo  [*] Проверка MySQL на порту 3306...

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "MYSQL="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_mysql.ps1" -Port 3306 -EnsureRunning 2^>nul`) do set "MYSQL=%%P"

if not defined MYSQL (
    echo  [ВНИМАНИЕ] MySQL не найден или не смог запуститься.
    echo      Сначала запустите upload_tools.bat или setup.bat.
    echo      Журнал: !ROOT!\tools\mysql\logs\mysql-error.log
    pause
    exit /b 1
)
if not exist "%MYSQL%" (
    echo  [ВНИМАНИЕ] mysql.exe не найден: !MYSQL!
    pause
    exit /b 1
)

set "MYSQL_CNF=%ROOT%\setup_tmp\mysql.cnf"
if exist "%MYSQL_CNF%" (
    "%MYSQL%" --defaults-extra-file="%MYSQL_CNF%" -Nse "SELECT 1" >nul 2>&1
    if errorlevel 1 (
        echo  [ВНИМАНИЕ] MySQL запущен, но проверка root-подключения не прошла.
        echo      Проверьте setup_tmp\mysql.cnf.
        pause
        exit /b 1
    )
)

echo  [OK] MySQL работает на 127.0.0.1:3306.
echo      Клиент: %MYSQL%
echo.
pause
exit /b 0
