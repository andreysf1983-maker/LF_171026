@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Остановка сервера
::   Файл: stop_server.bat
::
::   Корректно завершает ВСЕ процессы платформы:
::     worldserver.exe, bnetserver.exe, mysqld.exe (портативный MySQL),
::     а также mscld.exe / mysqld-nt.exe / mariadbd.exe, если они есть.
::
::   [ИСПРАВЛЕНО 2026-10] Ранее скрипт:
::     * не трогал процесс СУБД (mysqld.exe / mscld.exe) - он оставался
::       висеть, держал порт 3306 и блокировал повторный запуск setup.bat;
::     * вызывал taskkill без /T, поэтому дочерние процессы выживали;
::     * не проверял, что процесс реально завершился, и всегда писал "OK".
::
::   Предупреждение: остановка без сохранения может привести к потере
::   последних изменений персонажей. Желательно сначала выполнить в
::   консоли worldserver команду .saveall
:: ============================================================

title LEGIONFORGE 7.3.5 - Остановка сервера
color 0C

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOGDIR=%ROOT%\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\stop_server.log"

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - остановка сервера
echo  =========================================================
echo.

set "FOUND=0"
set "STUCK=0"

:: ---------------------------------------------------------------- игровые ядра
call :StopProcess "worldserver.exe" "worldserver (мир)"
call :StopProcess "bnetserver.exe"  "bnetserver (авторизация)"

:: ---------------------------------------------------------------- СУБД
:: Сначала пробуем "мягкое" выключение через mysqladmin - это сбрасывает
:: InnoDB-буферы на диск и не повреждает таблицы.
call :ShutdownMySqlGracefully

call :StopProcess "mysqld.exe"     "MySQL (mysqld)"
call :StopProcess "mscld.exe"      "MySQL (mscld)"
call :StopProcess "mysqld-nt.exe"  "MySQL (mysqld-nt)"
call :StopProcess "mariadbd.exe"   "MariaDB (mariadbd)"

echo.
if "!FOUND!"=="0" (
    echo  [OK] Работающих процессов сервера не обнаружено.
) else if "!STUCK!"=="0" (
    echo  [OK] Все процессы LEGIONFORGE остановлены.
) else (
    echo  [ОШИБКА] Не удалось завершить !STUCK! процесс^(ов^).
    echo           Запустите этот файл от имени администратора.
    echo           Журнал: %LOG%
)

echo.
pause
exit /b 0


:: ============================================================
::  :StopProcess <ИмяФайла.exe> <Описание>
::  Останавливает процесс: сначала мягко (WM_CLOSE), затем /F /T.
::  Проверяет результат и ведёт журнал.
:: ============================================================
:StopProcess
set "PROC=%~1"
set "DESC=%~2"

tasklist /FI "IMAGENAME eq %PROC%" /NH 2>nul | findstr /I /C:"%PROC%" >nul
if errorlevel 1 exit /b 0

set "FOUND=1"
echo  [*] Остановка %DESC%...
>>"%LOG%" echo [%DATE% %TIME%] stopping %PROC%

:: 1) мягкая попытка - даём процессу сохраниться
taskkill /IM "%PROC%" /T >nul 2>&1
call :WaitGone "%PROC%" 15
if "!GONE!"=="1" (
    echo  [OK] %DESC% остановлен корректно.
    >>"%LOG%" echo [%DATE% %TIME%] %PROC% stopped gracefully
    exit /b 0
)

:: 2) жёсткая попытка вместе с деревом дочерних процессов
echo  [*] %DESC% не ответил - принудительное завершение...
taskkill /IM "%PROC%" /F /T >nul 2>&1
call :WaitGone "%PROC%" 10
if "!GONE!"=="1" (
    echo  [OK] %DESC% остановлен принудительно.
    >>"%LOG%" echo [%DATE% %TIME%] %PROC% killed
    exit /b 0
)

:: 3) последний шанс - по PID (помогает при нескольких сессиях/службах)
for /f "tokens=2 delims=," %%P in ('tasklist /FI "IMAGENAME eq %PROC%" /NH /FO CSV 2^>nul') do (
    set "PID=%%~P"
    taskkill /PID !PID! /F /T >nul 2>&1
)
call :WaitGone "%PROC%" 10
if "!GONE!"=="1" (
    echo  [OK] %DESC% остановлен ^(по PID^).
    >>"%LOG%" echo [%DATE% %TIME%] %PROC% killed by pid
    exit /b 0
)

set /a STUCK+=1
echo  [ОШИБКА] %DESC% ^(%PROC%^) не удалось завершить.
>>"%LOG%" echo [%DATE% %TIME%] FAILED to stop %PROC%
exit /b 0


:: ============================================================
::  :WaitGone <ИмяФайла.exe> <ПопыткиПо1сек> -> GONE=0|1
:: ============================================================
:WaitGone
set "GONE=0"
set "WP=%~1"
set /a WN=%~2
for /l %%I in (1,1,!WN!) do (
    if "!GONE!"=="0" (
        tasklist /FI "IMAGENAME eq !WP!" /NH 2>nul | findstr /I /C:"!WP!" >nul
        if errorlevel 1 (
            set "GONE=1"
        ) else (
            >nul ping -n 2 127.0.0.1
        )
    )
)
exit /b 0


:: ============================================================
::  :ShutdownMySqlGracefully
::  Пытается закрыть портативный MySQL штатно, чтобы не ломать InnoDB.
:: ============================================================
:ShutdownMySqlGracefully
set "MYSQLADMIN="
if exist "%ROOT%\tools\mysql\server\bin\mysqladmin.exe" set "MYSQLADMIN=%ROOT%\tools\mysql\server\bin\mysqladmin.exe"
if not defined MYSQLADMIN exit /b 0

tasklist /FI "IMAGENAME eq mysqld.exe" /NH 2>nul | findstr /I /C:"mysqld.exe" >nul
if errorlevel 1 (
    tasklist /FI "IMAGENAME eq mscld.exe" /NH 2>nul | findstr /I /C:"mscld.exe" >nul
    if errorlevel 1 exit /b 0
)

set "MYPWD="
if exist "%ROOT%\tools\mysql\mysql_root.txt" (
    for /f "usebackq delims=" %%L in ("%ROOT%\tools\mysql\mysql_root.txt") do if not defined MYPWD set "MYPWD=%%L"
)

echo  [*] Штатное выключение MySQL ^(mysqladmin shutdown^)...
if defined MYPWD (
    "%MYSQLADMIN%" --protocol=TCP -h 127.0.0.1 -P 3306 -u root --password=!MYPWD! shutdown >>"%LOG%" 2>&1
) else (
    "%MYSQLADMIN%" --protocol=TCP -h 127.0.0.1 -P 3306 -u root shutdown >>"%LOG%" 2>&1
)
>nul ping -n 4 127.0.0.1
exit /b 0
