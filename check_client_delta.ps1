[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ClientDir = '',
    [string]$ServerDir = '',
    # Повторно извлечь db2 клиента, даже если кэш уже есть.
    [switch]$Refresh,
    # Не запускать mapextractor, работать только по уже снятому кэшу.
    [switch]$NoExtract
)

# ===========================================================================
#  LEGIONFORGE 7.3.5 - сверка КЛИЕНТА и server\data (дельта-проверка).
#
#  ЗАЧЕМ. check_game_data.ps1 отвечает только на вопрос "данных достаточно,
#  чтобы worldserver стартовал". Если вы положили maps/dbc/vmaps из другой
#  сборки, extract_maps.bat писал "[OK] ... Извлечение пропущено" и КАСТОМНЫЙ
#  контент вашего клиента (UWoW: новые расы, карты BfA/SL, свои db2) на сервер
#  не попадал никогда.
#
#  ЧТО ДЕЛАЕТ ЭТОТ СКРИПТ.
#    1. Снимает из клиента ТОЛЬКО db2 (mapextractor -e 2, несколько минут)
#       в кэш setup_tmp\client_scan\dbc.
#    2. Сравнивает набор db2 клиента с server\data\dbc:
#         - файлы, которых на сервере нет вообще;
#         - файлы, у которых отличается размер / RecordCount / MaxId
#           (значит, клиент содержит свои правки).
#    3. По ChrRaces.db2 / ChrClasses.db2 определяет кастомные расы и классы:
#       сравнивает MaxId клиента с enum Races ядра (SharedDefines.h).
#    4. По Map.db2 определяет, есть ли в клиенте карты, которых нет в
#       server\data\maps.
#    5. Пишет отчёт reports\client_delta.json (+ .md) и возвращает код:
#         0 - различий нет, данные сервера соответствуют клиенту;
#         3 - найдена дельта, нужно доизвлечение (extract_delta.ps1);
#         2 - проверку выполнить не удалось (нет клиента/инструментов).
# ===========================================================================

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
. (Join-Path $Root 'tools\lf_db2.ps1')

$dataDir = Join-Path $ServerDir 'data'
$serverDbc = Join-Path $dataDir 'dbc'
$mapsDir = Join-Path $dataDir 'maps'
$cacheRoot = Join-Path $Root 'setup_tmp\client_scan'
$cacheDbc = Join-Path $cacheRoot 'dbc'
$reportDir = Join-Path $Root 'reports'
$coreDir = Join-Path $Root 'core'

function Write-Line([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

# ---------- 0. Клиент ----------
if (-not $ClientDir) {
    $saved = Join-Path $Root 'client_path.txt'
    if (Test-Path -LiteralPath $saved) {
        $exe = (Get-Content -LiteralPath $saved -TotalCount 1).Trim()
        if ($exe -and (Test-Path -LiteralPath $exe)) { $ClientDir = Split-Path -Parent $exe }
    }
}
if ((-not $ClientDir) -or (-not (Test-Path -LiteralPath $ClientDir))) {
    Write-Line '  [!] Клиент не найден: укажите -ClientDir или заполните client_path.txt' 'Yellow'
    exit 2
}
$ClientDir = (Resolve-Path -LiteralPath $ClientDir).Path.TrimEnd('\')

# ---------- 1. Кэш db2 клиента ----------
$needExtract = $Refresh -or -not (Test-Path -LiteralPath $cacheDbc) -or
               (@(Get-ChildItem -LiteralPath $cacheDbc -Filter '*.db2' -Recurse -File -ErrorAction SilentlyContinue).Count -lt 50)
if ($needExtract -and -not $NoExtract) {
    $mapextractor = Join-Path $ServerDir 'mapextractor.exe'
    if (-not (Test-Path -LiteralPath $mapextractor)) {
        Write-Line '  [!] Нет server\mapextractor.exe - сначала выполните setup.bat / build_server.bat' 'Yellow'
        exit 2
    }
    New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
    Write-Line '  [*] Снимаю db2 из клиента (только dbc, обычно 2-5 минут)...' 'Cyan'
    & $mapextractor -i $ClientDir -o $cacheRoot -e 2 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Line "  [!] mapextractor завершился с кодом $LASTEXITCODE" 'Yellow'
        exit 2
    }
}
if (-not (Test-Path -LiteralPath $cacheDbc)) {
    # mapextractor кладёт dbc в <out>\dbc или <out>\dbc\<locale>
    $alt = Get-ChildItem -LiteralPath $cacheRoot -Directory -Filter 'dbc' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($alt) { $cacheDbc = $alt.FullName } else { Write-Line '  [!] Кэш db2 не создан' 'Yellow'; exit 2 }
}

function Get-Db2Map([string]$dir) {
    $map = @{}
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.db2' -File -Recurse -ErrorAction SilentlyContinue) {
        if (-not $map.ContainsKey($f.Name)) { $map[$f.Name] = Read-LfDb2Header $f.FullName }
    }
    return $map
}

$clientDb2 = Get-Db2Map $cacheDbc
$serverDb2 = Get-Db2Map $serverDbc
Write-Line ("  [*] db2: в клиенте {0}, на сервере {1}" -f $clientDb2.Count, $serverDb2.Count) 'Cyan'

# ---------- 2. Дельта по db2 ----------
$missing = @()
$changed = @()
foreach ($name in ($clientDb2.Keys | Sort-Object)) {
    $c = $clientDb2[$name]
    if (-not $serverDb2.ContainsKey($name)) {
        $missing += [pscustomobject]@{ File = $name; RecordCount = $c.RecordCount; MaxId = $c.MaxId; Magic = $c.Magic }
        continue
    }
    $s = $serverDb2[$name]
    if ($c.Length -ne $s.Length -or $c.RecordCount -ne $s.RecordCount -or $c.MaxId -ne $s.MaxId -or $c.LayoutHash -ne $s.LayoutHash) {
        $changed += [pscustomobject]@{
            File = $name
            ClientRecords = $c.RecordCount; ServerRecords = $s.RecordCount
            ClientMaxId = $c.MaxId; ServerMaxId = $s.MaxId
            ClientBytes = $c.Length; ServerBytes = $s.Length
            LayoutDiff = ($c.LayoutHash -ne $s.LayoutHash)
        }
    }
}

# ---------- 3. Кастомные расы и классы ----------
$coreRaces = Get-LfCoreRaceIds $coreDir
$coreMaxRace = 0
if ($coreRaces.Count -gt 0) { $coreMaxRace = ($coreRaces.Keys | Measure-Object -Maximum).Maximum }
$customRaces = @()
$racesClient = $clientDb2['ChrRaces.db2']
if ($racesClient) {
    for ($id = 1; $id -le $racesClient.MaxId; $id++) {
        if ($coreRaces.ContainsKey($id)) { continue }
        $known = Get-LfKnownRace $id
        $customRaces += [pscustomobject]@{
            Id = $id; Name = $known.Name; Expansion = $known.Expansion
            Faction = $known.Faction; BaseRace = $known.Base
            Source = 'ChrRaces.db2'
        }
    }
}
$classesClient = $clientDb2['ChrClasses.db2']
$customClasses = @()
if ($classesClient -and $classesClient.MaxId -gt 12) {
    for ($id = 13; $id -le $classesClient.MaxId; $id++) {
        $customClasses += [pscustomobject]@{ Id = $id; Name = ("Custom class #{0}" -f $id) }
    }
}

# ---------- 4. Карты ----------
$serverMapIds = @{}
foreach ($f in Get-ChildItem -LiteralPath $mapsDir -Filter '*.map' -File -ErrorAction SilentlyContinue) {
    $idPart = $f.Name.Substring(0, 4)
    $n = 0
    if ([int]::TryParse($idPart, [ref]$n)) { $serverMapIds[$n] = $true }
}
$mapDb2Client = $clientDb2['Map.db2']
$mapDb2Server = $serverDb2['Map.db2']
$mapsDelta = $false
if ($mapDb2Client -and $mapDb2Server) {
    $mapsDelta = ($mapDb2Client.MaxId -ne $mapDb2Server.MaxId) -or ($mapDb2Client.RecordCount -ne $mapDb2Server.RecordCount)
}
elseif ($mapDb2Client) { $mapsDelta = $true }

$report = [pscustomobject]@{
    GeneratedAt    = (Get-Date).ToString('s')
    ClientDir      = $ClientDir
    ServerDataDir  = $dataDir
    ClientDb2Count = $clientDb2.Count
    ServerDb2Count = $serverDb2.Count
    ServerMapIds   = $serverMapIds.Count
    ServerMapTiles = @(Get-ChildItem -LiteralPath $mapsDir -Filter '*.map' -File -ErrorAction SilentlyContinue).Count
    ClientMapMaxId = if ($mapDb2Client) { $mapDb2Client.MaxId } else { 0 }
    ServerMapMaxId = if ($mapDb2Server) { $mapDb2Server.MaxId } else { 0 }
    MapsDelta      = $mapsDelta
    CoreMaxRaceId  = $coreMaxRace
    ClientMaxRaceId = if ($racesClient) { $racesClient.MaxId } else { 0 }
    MissingDb2     = $missing
    ChangedDb2     = $changed
    CustomRaces    = $customRaces
    CustomClasses  = $customClasses
}

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$jsonPath = Join-Path $reportDir 'client_delta.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Дельта клиента и server\data')
[void]$md.AppendLine('')
[void]$md.AppendLine(('Снято: {0}' -f $report.GeneratedAt))
[void]$md.AppendLine(('Клиент: `{0}`' -f $ClientDir))
[void]$md.AppendLine('')
[void]$md.AppendLine(('- db2 в клиенте: {0}, на сервере: {1}' -f $clientDb2.Count, $serverDb2.Count))
[void]$md.AppendLine(('- db2 отсутствуют на сервере: {0}' -f $missing.Count))
[void]$md.AppendLine(('- db2 отличаются содержимым: {0}' -f $changed.Count))
[void]$md.AppendLine(('- кастомные расы: {0}' -f $customRaces.Count))
[void]$md.AppendLine(('- кастомные классы: {0}' -f $customClasses.Count))
[void]$md.AppendLine(('- Map.db2 различается: {0}' -f $mapsDelta))
if ($customRaces.Count -gt 0) {
    [void]$md.AppendLine('')
    [void]$md.AppendLine('## Кастомные расы клиента')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| ID | Раса | Дополнение | Фракция | База для стартовых данных |')
    [void]$md.AppendLine('|---:|------|-----------|---------|---------------------------|')
    foreach ($r in $customRaces) {
        [void]$md.AppendLine(('| {0} | {1} | {2} | {3} | {4} |' -f $r.Id, $r.Name, $r.Expansion, $r.Faction, $r.BaseRace))
    }
}
if ($missing.Count -gt 0) {
    [void]$md.AppendLine('')
    [void]$md.AppendLine('## db2, которых нет в server\data\dbc')
    [void]$md.AppendLine('')
    foreach ($m in ($missing | Select-Object -First 200)) {
        [void]$md.AppendLine(('- {0} (записей {1}, MaxId {2})' -f $m.File, $m.RecordCount, $m.MaxId))
    }
}
$md.ToString() | Set-Content -LiteralPath (Join-Path $reportDir 'client_delta.md') -Encoding UTF8

Write-Line ''
Write-Line ("  Отчёт: {0}" -f $jsonPath) 'Gray'
$hasDelta = ($missing.Count -gt 0 -or $changed.Count -gt 0 -or $customRaces.Count -gt 0 -or $mapsDelta)
if ($hasDelta) {
    Write-Line '  [!] Клиент содержит данные, которых нет на сервере:' 'Yellow'
    if ($missing.Count)     { Write-Line ("      db2 отсутствуют: {0}" -f $missing.Count) 'Yellow' }
    if ($changed.Count)     { Write-Line ("      db2 отличаются:  {0}" -f $changed.Count) 'Yellow' }
    if ($customRaces.Count) { Write-Line ("      кастомные расы:  {0} ({1})" -f $customRaces.Count, (($customRaces | ForEach-Object { $_.Id }) -join ', ')) 'Yellow' }
    if ($mapsDelta)         { Write-Line  '      Map.db2 клиента не совпадает с серверным - есть новые карты' 'Yellow' }
    Write-Line '      Запустите: extract_maps.bat -> пункт 2 (доизвлечь недостающее)' 'Yellow'
    exit 3
}
Write-Line '  [OK] Данные сервера полностью соответствуют клиенту - доизвлекать нечего.' 'Green'
exit 0
