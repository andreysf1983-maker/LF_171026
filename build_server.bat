@echo off
chcp 866 >nul 2>&1
setlocal EnableExtensions DisableDelayedExpansion

:: ============================================================
::   LEGIONFORGE 7.3.5 - Автоматическая компиляция сервера
::   Файл: build_server.bat   (запускать ОТ ИМЕНИ АДМИНИСТРАТОРА)
::
::   Ничего заранее устанавливать не нужно. Скрипт сам скачает
::   в папку tools\ портативные: 7-Zip, CMake, Boost, OpenSSL,
::   MySQL (заголовки) и официальный компилятор Microsoft
::   (Visual Studio 2022 Build Tools), затем соберёт:
::     worldserver.exe, bnetserver.exe, mapextractor.exe,
::     vmap4extractor.exe, vmap4assembler.exe, mmaps_generator.exe,
::     connection_patcher.exe  -  и положит их в папку server\.
::
::   Параметры (необязательно):
::     /auto      без паузы в конце (используется setup.bat)
::     /clean     удалить папку build\ и собрать с нуля
::     /tools     только подготовить инструменты, без компиляции
::     /nopch     собирать без предкомпилированных заголовков
::     /buildtools  всегда использовать tools\vsbuildtools
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "PS_ARGS="
set "AUTO="

:PARSE_ARGS
if "%~1"=="" goto :ARGS_DONE
if /I "%~1"=="/auto" set "AUTO=1"& set "PS_ARGS=%PS_ARGS% -Auto"
if /I "%~1"=="/clean" set "PS_ARGS=%PS_ARGS% -Clean"
if /I "%~1"=="/tools" set "PS_ARGS=%PS_ARGS% -PrepareOnly"
if /I "%~1"=="/nopch" set "PS_ARGS=%PS_ARGS% -NoPch"
if /I "%~1"=="/buildtools" set "PS_ARGS=%PS_ARGS% -ForceBuildTools"
shift
goto :PARSE_ARGS
:ARGS_DONE

title LEGIONFORGE 7.3.5 - Компиляция сервера
if not defined AUTO color 0B

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - автоматическая компиляция сервера
echo  =========================================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo  [ОШИБКА] Нужны права администратора.
    echo           Нажмите правой кнопкой на build_server.bat и выберите
    echo           "Запуск от имени администратора".
    echo.
    if not defined AUTO pause
    exit /b 1
)

if not defined AUTO (
    echo   Что будет сделано:
    echo     1. Загрузка инструментов в tools\  - около 3 ГБ, один раз
    echo     2. Установка Visual Studio 2022 Build Tools, если компилятора нет
    echo     3. Компиляция ядра - обычно 30-90 минут, зависит от ПК
    echo     4. Копирование готовых .exe и .dll в папку server\
    echo.
    echo   Нужно: интернет, ~30 ГБ свободного места, 8+ ГБ ОЗУ.
    echo   Повторный запуск продолжит с места остановки.
    echo.
    pause
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\build_server.ps1" %PS_ARGS%
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" (
    echo  =========================================================
    echo   Компиляция завершена. Программы лежат в папке server\
    echo  =========================================================
    echo   Дальше: setup.bat - базы данных, карты, учётная запись,
    echo           затем play.bat - запуск сервера и клиента.
) else (
    echo  [ОШИБКА] Компиляция не удалась. Журнал: %ROOT:)=^)%\build_log.txt
    echo           Исправьте причину и запустите build_server.bat снова -
    echo           уже скачанные инструменты повторно не загружаются.
)
echo.
if not defined AUTO pause
exit /b %RESULT%
