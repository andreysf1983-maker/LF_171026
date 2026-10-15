@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Создание игровой учётной записи
::   Файл: create_account.bat
::
::   Вход в игру осуществляется по адресу электронной почты
::   и паролю (протокол Battle.net). Имя игрового аккаунта
::   используется только внутри сервера.
::
::   Использование:
::     create_account.bat                       - интерактивный режим
::     create_admin.bat                         - администратор LEGIONFORGE
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "TMP_DIR=%ROOT%\setup_tmp"
set "MYSQL_CNF=%TMP_DIR%\mysql.cnf"

title LEGIONFORGE 7.3.5 - Создание учётной записи
color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - создание учётной записи
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

:: ---- Режим командной строки с параметрами ----
if not "%~1"=="" (
    set "ACCT_USER=%~1"
    set "ACCT_PASS=%~2"
    set "ACCT_EMAIL=%~3"
    set "GM_LEVEL=%~4"
    if "!GM_LEVEL!"=="" set "GM_LEVEL=0"
    goto :CREATE
)

:: ---- Интерактивный режим ----
echo  Введите данные новой учётной записи.
echo.
set /p "ACCT_USER=  Имя игрового аккаунта (латиница, без пробелов): "
set /p "ACCT_PASS=  Пароль: "
set /p "ACCT_EMAIL= Электронная почта для входа в игру: "
echo.
echo  Уровень доступа:
echo    0 - обычный игрок
echo    1 - модератор
echo    2 - гейм-мастер
echo    3 - администратор
set /p "GM_LEVEL=  Уровень доступа (0-3) [0]: "

if "!GM_LEVEL!"=="" set "GM_LEVEL=0"
if "!ACCT_USER!"=="" (
    echo.
    echo  [ВНИМАНИЕ] Имя аккаунта не может быть пустым.
    pause
    exit /b 1
)
if "!ACCT_PASS!"=="" (
    echo.
    echo  [ВНИМАНИЕ] Пароль не может быть пустым.
    pause
    exit /b 1
)
if "!ACCT_EMAIL!"=="" (
    echo.
    echo  [ВНИМАНИЕ] Адрес электронной почты обязателен для входа в игру.
    pause
    exit /b 1
)

:CREATE
echo.
echo  [*] Создание учётной записи...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\create_local_account.ps1" -Username "!ACCT_USER!" -Password "!ACCT_PASS!" -Email "!ACCT_EMAIL!" -GmLevel !GM_LEVEL! -CnfPath "%MYSQL_CNF%" -MysqlExe "%MYSQL%"
if errorlevel 1 (
    echo.
    echo  [ВНИМАНИЕ] Не удалось создать учётную запись. Проверьте сообщения выше.
    pause
    exit /b 1
)

echo.
echo  =========================================================
echo   Учётная запись создана.
echo  =========================================================
echo.
echo   Вход в игру:
echo     Логин:  !ACCT_EMAIL!
echo     Пароль: !ACCT_PASS!
echo.
echo   Уровень доступа: !GM_LEVEL!
echo.
pause
exit /b 0
