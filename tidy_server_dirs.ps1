[CmdletBinding()]
param(
    [string]$Root = '',
    # Сколько суток хранить журналы и отчёты о падениях (0 - хранить всё).
    [int]$KeepDays = 30
)

# ===========================================================================
#  LEGIONFORGE 7.3.5 - порядок в папке server.
#
#  РАНЬШЕ: worldserver.conf содержал LogsDir = "", поэтому Server.log,
#  DBErrors.log, SQLUpdate.log, Auth.log и дампы падений сыпались прямо в
#  корень server\ вперемешку с exe и dll.
#
#  ТЕПЕРЬ:
#    server\logs     - все журналы (Server.log, DBErrors.log, gm\, runs\ ...)
#    server\Crashes  - отчёты WheatyExceptionReport (*.txt) и минидампы (*.dmp)
#
#  Скрипт идемпотентен: создаёт папки, прописывает LogsDir в conf-файлы,
#  переносит уже лежащие в корне файлы и чистит старьё (KeepDays).
#  Вызывается из play.bat, setup.bat и build_server.ps1.
# ===========================================================================

$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
$serverDir = Join-Path $Root 'server'
if (-not (Test-Path -LiteralPath $serverDir)) { Write-Host "  [!] Нет папки server: $serverDir"; exit 1 }

$logsDir = Join-Path $serverDir 'logs'
$crashDir = Join-Path $serverDir 'Crashes'
New-Item -ItemType Directory -Force -Path $logsDir, $crashDir, (Join-Path $logsDir 'gm') | Out-Null

# ---------- 1. LogsDir в conf-файлах ----------
function Set-ConfKey([string]$confPath, [string]$key, [string]$value) {
    if (-not (Test-Path -LiteralPath $confPath)) { return $false }
    $lines = Get-Content -LiteralPath $confPath
    $pattern = '^\s*' + [regex]::Escape($key) + '\s*='
    $done = $false
    $out = foreach ($line in $lines) {
        if (-not $done -and $line -match $pattern) { $done = $true; ('{0} = "{1}"' -f $key, $value) }
        else { $line }
    }
    if (-not $done) { $out = @($out) + ('{0} = "{1}"' -f $key, $value) }
    Set-Content -LiteralPath $confPath -Value $out -Encoding UTF8
    return $true
}

$logsValue = ($logsDir -replace '\\', '/')
foreach ($name in @('worldserver.conf', 'bnetserver.conf', 'worldserver.conf.dist', 'bnetserver.conf.dist')) {
    $conf = Join-Path $serverDir $name
    if (Test-Path -LiteralPath $conf) {
        $v = if ($name -like '*.dist') { 'logs' } else { $logsValue }
        [void](Set-ConfKey $conf 'LogsDir' $v)
    }
}

# ---------- 2. Перенос файлов из корня server ----------
$movedLogs = 0
$movedCrashes = 0
foreach ($f in Get-ChildItem -LiteralPath $serverDir -File -ErrorAction SilentlyContinue) {
    $name = $f.Name
    $isCrash = ($name -match '^[0-9a-f]{6,}\+?_(worldserver|bnetserver)[^\\]*\.(txt|dmp)$') -or ($f.Extension -ieq '.dmp')
    $isLog = ($f.Extension -ieq '.log')
    if ($isCrash) {
        Move-Item -LiteralPath $f.FullName -Destination (Join-Path $crashDir $name) -Force -ErrorAction SilentlyContinue
        if ($?) { $movedCrashes++ }
    }
    elseif ($isLog) {
        Move-Item -LiteralPath $f.FullName -Destination (Join-Path $logsDir $name) -Force -ErrorAction SilentlyContinue
        if ($?) { $movedLogs++ }
    }
}

# ---------- 3. Чистка старья ----------
$removed = 0
if ($KeepDays -gt 0) {
    $limit = (Get-Date).AddDays(-$KeepDays)
    foreach ($dir in @($logsDir, $crashDir)) {
        foreach ($f in Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue) {
            if ($f.LastWriteTime -lt $limit) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                if ($?) { $removed++ }
            }
        }
    }
}

Write-Host ("  [OK] server\logs и server\Crashes готовы (перенесено журналов: {0}, отчётов о падениях: {1}, удалено старых: {2})" -f $movedLogs, $movedCrashes, $removed) -ForegroundColor Green
exit 0
