@echo off
REM ============================================================
REM   LEGIONFORGE 7.3.5 - Remove Mark of the Web
REM   File: UNBLOCK.bat   (ASCII only on purpose - must run before
REM   any chcp/encoding setup and on every codepage)
REM
REM   [FIX 2026-10] setup.bat "does not start" on a fresh download.
REM   A ZIP downloaded from the internet carries the Zone.Identifier
REM   alternate data stream. Every file extracted from it inherits it,
REM   and Windows then blocks the bundled PowerShell scripts with
REM     "File ... cannot be loaded because running scripts is disabled"
REM   or SmartScreen's "Windows protected your PC". This file clears
REM   that flag recursively. Run it once right after extracting.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5 - unblocking files
echo  =========================================================
echo.
echo  [*] Removing Mark of the Web from every file in:
echo      %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=(Get-Location).ProviderPath; if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root -PathType Container)) { Write-Error 'Project folder could not be determined'; exit 1 }; $n=0; Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { try { Unblock-File -LiteralPath $_.FullName -ErrorAction Stop; $n++ } catch {} }; Write-Host ('  [OK] Files checked: ' + $n)"
if errorlevel 1 (
    echo  [WARN] Unblock-File reported an error - continuing anyway.
)

echo.
echo  [OK] Done. Now right-click setup.bat and choose
echo       "Run as administrator".
echo.
echo  If Windows still shows a SmartScreen warning, press
echo  "More info" -^> "Run anyway".
echo.
pause
endlocal
exit /b 0
