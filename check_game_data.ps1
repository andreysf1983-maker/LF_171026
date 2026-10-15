[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerDir,

    # Пропустить сверку DB2 с ядром (нужно только для отладки самой проверки).
    [switch]$SkipDb2Check
)

$ErrorActionPreference = 'SilentlyContinue'
$dataDir = Join-Path $ServerDir 'data'
$mapsDir = Join-Path $dataDir 'maps'
$dbcDir = Join-Path $dataDir 'dbc'
$vmapsDir = Join-Path $dataDir 'vmaps'
$mmapsDir = Join-Path $dataDir 'mmaps'

# Keep these thresholds aligned with extract_maps.ps1: a partial map dump
# must not be mistaken for a complete installation.
$requiredMaps = @(
    @{ Id = 0; Name = 'Eastern Kingdoms'; MinTiles = 80 },
    @{ Id = 1; Name = 'Kalimdor'; MinTiles = 80 },
    @{ Id = 530; Name = 'Outland'; MinTiles = 25 },
    @{ Id = 571; Name = 'Northrend'; MinTiles = 30 },
    @{ Id = 646; Name = 'Deepholm'; MinTiles = 5 },
    @{ Id = 870; Name = 'Pandaria'; MinTiles = 25 },
    @{ Id = 1116; Name = 'Draenor'; MinTiles = 25 },
    @{ Id = 1220; Name = 'Broken Isles'; MinTiles = 40 },
    @{ Id = 1669; Name = 'Argus'; MinTiles = 8 }
)

$mapCount = @(Get-ChildItem -LiteralPath $mapsDir -Filter '*.map' -File -Force -ErrorAction SilentlyContinue).Count
$mapDbCount = @(Get-ChildItem -LiteralPath $dbcDir -Filter 'Map.db2' -File -Recurse -Force -ErrorAction SilentlyContinue).Count
$vmtreeCount = @(Get-ChildItem -LiteralPath $vmapsDir -Filter '*.vmtree' -File -Force -ErrorAction SilentlyContinue).Count
$mmapsCount = @(Get-ChildItem -LiteralPath $mmapsDir -Filter '*.mmtile' -File -Force -ErrorAction SilentlyContinue).Count

$missing = @()
if ($mapCount -lt 200) {
    $missing += "maps/*.map: $mapCount found; at least 200 required"
}
foreach ($map in $requiredMaps) {
    $prefix = '{0:D4}_' -f $map.Id
    $tileCount = @(Get-ChildItem -LiteralPath $mapsDir -Filter ($prefix + '*.map') -File -Force -ErrorAction SilentlyContinue).Count
    if ($tileCount -lt $map.MinTiles) {
        $missing += ("{0}: {1} tiles found; {2} required" -f $map.Name, $tileCount, $map.MinTiles)
    }
}
if ($mapDbCount -lt 1) {
    $missing += 'dbc/Map.db2 not found'
}
if ($vmtreeCount -lt 50) {
    $missing += "vmaps/*.vmtree: $vmtreeCount found; at least 50 required"
}

if ($missing.Count -gt 0) {
    Write-Host '[!] Game data is missing or incomplete:'
    foreach ($item in $missing) { Write-Host "    - $item" }
    Write-Host '    Expected folders: server\data\maps, dbc, vmaps.'
    exit 1
}

# [LEGIONFORGE] Наличие maps/vmaps/Map.db2 ещё не значит, что данные от того же билда клиента.
# worldserver сверяет DB2 со своими константами и падает через ASSERT, например:
#   BATTLE_PET_SPECIES_MAX_ID (2164) must be equal to or greater than 5004
# Поэтому dbc проверяется заранее: сигнатура WDC1, LayoutHash и пределы MaxId.
if (-not $SkipDb2Check) {
    $db2Checker = Join-Path $PSScriptRoot 'tools\check_db2_build.ps1'
    if (Test-Path -LiteralPath $db2Checker) {
        & $db2Checker -DataDir $dataDir
        if ($LASTEXITCODE -eq 2) {
            Write-Host '[!] Проверка DB2 не выполнена: нет папки dbc или файлов ядра.'
            $missing += 'dbc files could not be verified'
        }
        elseif ($LASTEXITCODE -ne 0) {
            Write-Host '[!] DB2 не соответствуют ядру: с такими данными worldserver упадёт при запуске.'
            $missing += 'dbc DB2 build/layout mismatch'
        }
        if ($missing.Count -gt 0) {
            Write-Host '    Игровые данные не пригодны - см. сообщения выше.'
            exit 1
        }
    }
}

Write-Host ("[OK] Game data is ready: {0} map tiles, all required expansion continents, Map.db2, {1} vmtree files." -f $mapCount, $vmtreeCount)
if ($mmapsCount -eq 0) {
    Write-Host '[!] No mmaps tiles found. They are optional but recommended for NPC pathfinding.'
} else {
    Write-Host ("[OK] Mmaps: {0} tiles." -f $mmapsCount)
}
exit 0
