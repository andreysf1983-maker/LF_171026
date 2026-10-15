@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions DisableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Подготовка дистрибутива
::   Файл: prepare_release.bat
::
::   ВАЖНО: этот скрипт НЕ компилирует сервер. Он упаковывает
::   УЖЕ готовую установку, чтобы перенести её на другой ПК
::   без компиляции. Порядок: build_server.bat - setup.bat -
::   и только потом prepare_release.bat.
::
::   Создаёт в папке release\:
::     server_binaries.zip - программы сервера .exe/.dll + конфиги-шаблоны
::     databases.zip       - дампы world и hotfixes через mysqldump
::
::   Параметры:
::     /source  дополнительно release\legionforge_source.zip
::              только для публикации исходников
::     /full    добавить в databases.zip базы auth и characters
::     /pdb     добавить отладочные символы .pdb
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "PS_ARGS="

:PARSE_ARGS
if "%~1"=="" goto :ARGS_DONE
if /I "%~1"=="/source" set "PS_ARGS=%PS_ARGS% -Source"
if /I "%~1"=="/full" set "PS_ARGS=%PS_ARGS% -Full"
if /I "%~1"=="/pdb" set "PS_ARGS=%PS_ARGS% -WithPdb"
shift
goto :PARSE_ARGS
:ARGS_DONE

title LEGIONFORGE 7.3.5 - Подготовка дистрибутива
color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - подготовка дистрибутива
echo  =========================================================
echo.

if not exist "%ROOT%\server\worldserver.exe" (
    echo  [ВНИМАНИЕ] Сервер ещё не скомпилирован - упаковывать программы нечего.
    echo             Компиляция выполняется скриптом build_server.bat
    echo             или автоматически внутри setup.bat.
    echo.
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\prepare_release.ps1" %PS_ARGS%
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" (
    echo   Перенос на другой ПК: скопируйте файлы из release\ в папку
    echo   setup_tmp\ нового проекта и запустите там setup.bat.
) else (
    echo  [ОШИБКА] Часть архивов не создана - смотрите ИТОГ выше
    echo           и журнал logs\prepare_release.log
)
echo.
pause
exit /b %RESULT%
