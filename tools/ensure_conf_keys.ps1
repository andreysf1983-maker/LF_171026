<#
.SYNOPSIS
    LEGIONFORGE 7.3.5 - синхронизация живых *.conf с *.conf.dist.

.DESCRIPTION
    Устраняет предупреждения вида
        Missing name Guild.SaveInterval in config file ...\worldserver.conf,
        add "Guild.SaveInterval = 15" to this file
    Причина: живой worldserver.conf/bnetserver.conf созданы из более старого
    *.conf.dist (или вручную), и в них нет ключей, которые ядро читает
    обязательно.

    Скрипт:
      * если *.conf отсутствует - копирует его из *.conf.dist;
      * находит ВСЕ ключи, которые есть в .dist, но отсутствуют в .conf, и
        дописывает их в конец файла вместе с значением по умолчанию из .dist;
      * ничего не переписывает и не удаляет: существующие значения остаются;
      * кладёт отчёт в reports\ensure_conf_keys.json.

    Идемпотентен: повторный запуск не добавляет ключи дважды.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1 -WhatIf
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ServerDir = '',
    [string[]]$Confs = @('worldserver', 'bnetserver'),
    [switch]$WhatIfMode
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
$reportDir = Join-Path $Root 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Write-Ok([string]$m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Step([string]$m) { Write-Host "  [*] $m" -ForegroundColor Cyan }

function Get-ConfKeys {
    param([string]$Path)
    $keys = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) { return $keys }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9_.\-]*)\s*=\s*(.*)$') {
            $keys[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $keys
}

$summary = @()
foreach ($name in $Confs) {
    $conf = Join-Path $ServerDir "$name.conf"
    $dist = Join-Path $ServerDir "$name.conf.dist"

    if (-not (Test-Path -LiteralPath $dist)) {
        Write-Warn "$name.conf.dist не найден в $ServerDir - пропускаю."
        continue
    }

    if (-not (Test-Path -LiteralPath $conf)) {
        Write-Step "$name.conf отсутствует - создаю из $name.conf.dist"
        if (-not $WhatIfMode) { Copy-Item -LiteralPath $dist -Destination $conf -Force }
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $true; Added = 0; Keys = @() }
        continue
    }

    $distKeys = Get-ConfKeys -Path $dist
    $liveKeys = Get-ConfKeys -Path $conf

    $missing = @()
    foreach ($k in $distKeys.Keys) {
        if (-not $liveKeys.Contains($k)) { $missing += $k }
    }

    if ($missing.Count -eq 0) {
        Write-Ok "$name.conf содержит все $($distKeys.Count) ключей из $name.conf.dist"
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = 0; Keys = @() }
        continue
    }

    Write-Warn "$name.conf: отсутствует ключей: $($missing.Count) (в т.ч. $(($missing | Select-Object -First 6) -join ', '))"
    if ($WhatIfMode) {
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = $missing.Count; Keys = $missing }
        continue
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item -LiteralPath $conf -Destination "$conf.bak-$stamp" -Force

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('###################################################################################################')
    [void]$sb.AppendLine("# [LEGIONFORGE] Ключи добавлены автоматически tools\ensure_conf_keys.ps1 ($stamp)")
    [void]$sb.AppendLine('# Значения взяты из ' + "$name.conf.dist. Ядро читает их обязательно;")
    [void]$sb.AppendLine('# без них в лог пишется "Missing name <Key> in config file".')
    [void]$sb.AppendLine('###################################################################################################')
    foreach ($k in $missing) {
        [void]$sb.AppendLine("$k = $($distKeys[$k])")
    }

    [System.IO.File]::AppendAllText($conf, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "$name.conf: дописано ключей $($missing.Count), резервная копия $name.conf.bak-$stamp"
    $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = $missing.Count; Keys = $missing }
}

$reportPath = Join-Path $reportDir 'ensure_conf_keys.json'
[pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('s')
    ServerDir   = $ServerDir
    Results     = $summary
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Ok "Отчёт: $reportPath"
exit 0
