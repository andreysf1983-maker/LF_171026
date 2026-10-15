# LegionForge: writes machine-specific paths into worldserver.conf / bnetserver.conf.
#
#   MySQLExecutable = full path to mysql.exe (the bundled tools\mysql\server\bin\mysql.exe
#                     or whatever find_mysql.ps1 detects)
#   SourceDirectory = project root (folder that contains sql\)
#
# Without MySQLExecutable worldserver stopped right after the banner with
#   "Didn't find any executable MySQL binary at '...\server' ... (MySQLExecutable)"
#   "Could not update the Login database, see log for details."
#
# Idempotent, safe to call on every start. ASCII only, UTF-8 with BOM, CRLF.
param(
    [string]$Root = "",
    [string]$MysqlExe = ""
)

$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
$serverDir = Join-Path $Root 'server'

if (-not $MysqlExe -or -not (Test-Path -LiteralPath $MysqlExe)) {
    $candidates = @(
        (Join-Path $Root 'tools\mysql\server\bin\mysql.exe'),
        (Join-Path $Root 'tools\mysql\bin\mysql.exe')
    )
    $MysqlExe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $MysqlExe) {
    try {
        $found = & (Join-Path $Root 'find_mysql.ps1') -Port 3306 2>$null | Select-Object -First 1
        if ($found) { $MysqlExe = $found.ToString().Trim() }
    } catch { }
}
if (-not $MysqlExe) {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $MysqlExe = $cmd.Source }
}

$mysqlValue = ''
if ($MysqlExe -and (Test-Path -LiteralPath $MysqlExe)) {
    $mysqlValue = ((Resolve-Path -LiteralPath $MysqlExe).Path) -replace '\\', '/'
}
$sourceValue = $Root -replace '\\', '/'
$logsDir = Join-Path $serverDir 'logs'
$crashDir = Join-Path $serverDir 'Crashes'
New-Item -ItemType Directory -Force -Path $logsDir, $crashDir, (Join-Path $logsDir 'gm') | Out-Null
$logsValue = $logsDir -replace '\\', '/'

function Set-ConfValue([string[]]$Lines, [string]$Key, [string]$Value) {
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $done = $false
    $out = foreach ($line in $Lines) {
        if (-not $done -and $line -match $pattern) {
            $done = $true
            ('{0} = "{1}"' -f $Key, $Value)
        } else { $line }
    }
    if (-not $done) { $out = @($out) + ('{0} = "{1}"' -f $Key, $Value) }
    return ,$out
}

foreach ($name in @('worldserver.conf', 'bnetserver.conf')) {
    $conf = Join-Path $serverDir $name
    if (-not (Test-Path -LiteralPath $conf)) { continue }
    $lines = [System.IO.File]::ReadAllLines($conf)
    if ($mysqlValue) { $lines = Set-ConfValue $lines 'MySQLExecutable' $mysqlValue }
    $lines = Set-ConfValue $lines 'SourceDirectory' $sourceValue
    # [LEGIONFORGE] Журналы в server\logs, отчёты о падениях ядро пишет в server\Crashes.
    # Без этого Server.log / DBErrors.log / дампы сыпались в корень server.
    $lines = Set-ConfValue $lines 'LogsDir' $logsValue
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($conf, $lines, $utf8NoBom)
    if ($mysqlValue) { Write-Host "  [OK] $name : MySQLExecutable = $mysqlValue" }
    else { Write-Host "  [!] $name : mysql.exe not found, automatic DB updates will be skipped" }
}
exit 0
