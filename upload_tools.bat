@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions

title LEGIONFORGE - Подготовка инструментов
color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - подготовка MySQL и инструментов
echo  =========================================================
echo.
echo  MySQL Community Server будет распакован в tools\mysql.
echo  Загрузка около 237 МБ; нужен интернет и порт 3306.
echo.

if /I "%~1"=="/prepare-only" goto :RUN_PREPARE

net session >nul 2>&1
if errorlevel 1 (
    echo  [ВНИМАНИЕ] Требуются права администратора.
    echo      Нажмите правой кнопкой на upload_tools.bat и выберите
    echo      "Запуск от имени администратора".
    echo.
    pause
    exit /b 1
)

:RUN_PREPARE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0upload_tools.ps1"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
    echo.
    echo  [ВНИМАНИЕ] Подготовка инструментов завершилась с ошибкой.
    if /I not "%~1"=="/prepare-only" pause
    exit /b %RESULT%
)

if /I "%~1"=="/prepare-only" exit /b 0

echo.
echo  =========================================================
echo   MySQL запущен. Запустите setup.bat для продолжения.
echo  =========================================================
echo.
pause
exit /b 0
