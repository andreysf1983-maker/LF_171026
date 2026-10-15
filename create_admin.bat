@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Учётная запись администратора
::   Файл: create_admin.bat
::
::   Создаёт или сбрасывает администраторский аккаунт:
::     Логин (Battle.net): admin@legionforge.ru
::     Пароль:             legionforge
::     Уровень доступа:    3 (администратор)
::
::   Скрипт безопасен для повторного запуска: существующая
::   запись будет обновлена, а не продублирована.
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "TMP_DIR=%ROOT%\setup_tmp"
set "MYSQL_CNF=%TMP_DIR%\mysql.cnf"

title LEGIONFORGE 7.3.5 - Администратор сервера
color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE - создание администратора
echo  =========================================================
echo.

if not exist "%MYSQL_CNF%" (
    echo  [ВНИМАНИЕ] Не найден файл подключения к MySQL: !MYSQL_CNF!
    echo      Сначала выполните установку сервера: setup.bat
    pause
    exit /b 1
)

set "MYSQL="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\find_mysql.ps1" -Port 3306`) do set "MYSQL=%%P"
if not exist "%MYSQL%" (
    echo  [ВНИМАНИЕ] MySQL не найден. Запустите setup.bat.
    pause
    exit /b 1
)

echo  [*] Создание учётной записи администратора...
echo      Логин:  admin@legionforge.ru
echo      Пароль: legionforge
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\update_local_account.ps1" -Username "admin" -Password "legionforge" -Email "admin@legionforge.ru" -GmLevel 3 -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
if errorlevel 1 (
    echo  [*] Обновление не удалось, пробуем создать запись заново...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\create_local_account.ps1" -Username "admin" -Password "legionforge" -Email "admin@legionforge.ru" -GmLevel 3 -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
    if errorlevel 1 (
        echo  [ВНИМАНИЕ] Не удалось создать учётную запись администратора.
        pause
        exit /b 1
    )
)

echo.
echo  =========================================================
echo   Готово.
echo  =========================================================
echo.
echo   Вход в игру:
echo     Логин:  admin@legionforge.ru
echo     Пароль: legionforge
echo.
echo   Для входа требуется работающий bnetserver и worldserver.
echo   Запуск сервера: play.bat
echo.
pause
exit /b 0
