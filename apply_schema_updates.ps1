# LEGIONFORGE 7.3.5 - применение обновлений схемы к базам auth / characters.
# Файл хранится в UTF-8 с BOM (кириллица в сообщениях).
#
# ЗАЧЕМ. Базовые схемы sql\base\auth.sql и characters.sql старее ядра: в них нет, например,
# characters.lastLoginBuild, characters.inventorySlots, таблицы character_pvp_talent. Из-за этого worldserver
# не мог подготовить запросы (mysql_stmt_prepare) и не открывал базу персонажей. Встроенный автообновлятель ядра
# эти файлы не находит (каталог sql лежит в корне проекта, а не в core\), а setup.bat очищает таблицы updates*.
# Поэтому обновления применяет этот скрипт: sql\updates\<база>\**\*.sql и sql\legionforge\<база>\*.sql
# в порядке имён файлов (имена начинаются с даты).
#
# Безопасно для повторного запуска: mysql запускается с --force, повторяющиеся ALTER/CREATE дают безвредные
# ошибки "Duplicate column / already exists", которые считаются и пишутся в журнал, но не прерывают установку.
# Один раз выполненная база отмечается флагом setup_tmp\schema_updates_<база>.flag (-Force игнорирует флаг).
param(
    [Parameter(Mandatory = $true)][ValidateSet('auth', 'characters')][string]$Database,
    [string]$Root = '',
    [string]$MysqlExe = '',
    [string]$CnfPath = '',
    [switch]$Force
)
$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $CnfPath) { $CnfPath = Join-Path $Root 'setup_tmp\mysql.cnf' }
if (-not $MysqlExe) { $MysqlExe = & (Join-Path $Root 'find_mysql.ps1') -Port 3306 }
if (-not $MysqlExe -or -not (Test-Path -LiteralPath $MysqlExe)) { Write-Host '  [!] mysql.exe не найден'; exit 1 }
if (-not (Test-Path -LiteralPath $CnfPath)) { Write-Host "  [!] Не найден $CnfPath - сначала запустите setup.bat"; exit 1 }

$flag = Join-Path $Root "setup_tmp\schema_updates_$Database.flag"
if ((Test-Path -LiteralPath $flag) -and -not $Force) {
    Write-Host "      - обновления схемы $Database уже применены ранее - пропуск"
    exit 0
}

$files = @()
$updatesDir = Join-Path $Root "sql\updates\$Database"
$projectDir = Join-Path $Root "sql\legionforge\$Database"
if (Test-Path -LiteralPath $updatesDir) { $files += @(Get-ChildItem -LiteralPath $updatesDir -Filter '*.sql' -File -Recurse) }
if (Test-Path -LiteralPath $projectDir) { $files += @(Get-ChildItem -LiteralPath $projectDir -Filter '*.sql' -File) }
$files = @($files | Sort-Object Name)
if ($files.Count -eq 0) { Write-Host "      - файлы обновлений для $Database не найдены"; exit 0 }

function Invoke-MysqlFile([string]$File) {
    # SQL подаётся в stdin побайтово - без перекодировки PowerShell.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $MysqlExe
    $psi.Arguments = ('--defaults-extra-file="{0}" --default-character-set=utf8mb4 --max_allowed_packet=512M --force {1}' -f $CnfPath, $Database)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $bytes = [System.IO.File]::ReadAllBytes($File)
    try { $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length) } catch { }
    $proc.StandardInput.Close()
    $proc.WaitForExit()
    return $errTask.Result
}

Write-Host "      - обновления схемы $Database`: файлов $($files.Count)"
$errorsTotal = 0
foreach ($file in $files) {
    $err = Invoke-MysqlFile $file.FullName
    $lines = @(($err -split "`r?`n") | Where-Object { $_ -match '^ERROR' })
    $harmless = @($lines | Where-Object { $_ -match 'ERROR (1060|1061|1050|1091|1062)\b' })
    $real = @($lines | Where-Object { $harmless -notcontains $_ })
    $errorsTotal += $real.Count
    if ($real.Count -gt 0) { Write-Host ("        [!] {0}: {1}" -f $file.Name, $real[0]) }
}
if ($errorsTotal -eq 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $flag) | Out-Null
    Set-Content -LiteralPath $flag -Value (Get-Date -Format 's') -Encoding ASCII
    Write-Host "      [OK] схема $Database обновлена"
    exit 0
}
Write-Host "      [!] при обновлении схемы $Database есть ошибки ($errorsTotal) - см. строки выше"
exit 1
