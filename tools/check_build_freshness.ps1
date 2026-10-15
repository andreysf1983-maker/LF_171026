<#
.SYNOPSIS
    Verify that the running worldserver/bnetserver were built from these sources.
.DESCRIPTION
    An old EXE can still contain SpellMgr::LoadSpellInfoStore's fatal assertion
    even when SharedDefines.h already says TOTAL_SPELL_EFFECTS = 262.
    -Update is reserved for build_server.ps1 AFTER a successful compilation.
    Without -Update this script fails closed if the manifest is missing or stale.
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ServerDir = '',
    [switch]$Update,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
$manifestPath = Join-Path $ServerDir 'build_sources.json'

# These files directly define the DB2/spell loader, handler bounds and startup.
# Include both executables so a replaced prebuilt binary is detected as well.
$sourcePaths = @(
    'core/src/server/game/DataStores/DB2Stores.cpp',
    'core/src/server/game/Conditions/ConditionMgr.cpp',
    'core/src/server/game/AI/SmartScripts/SmartScriptMgr.cpp',
    'core/src/server/game/Loot/LootMgr.cpp',
    'core/src/server/game/DataStores/DB2Metadata.h',
    'core/src/server/game/DataStores/DB2Structure.h',
    'core/src/server/game/DataStores/DBCEnums.h',
    'core/src/server/game/Achievements/CriteriaHandler.cpp',
    'core/src/server/game/Achievements/CriteriaHandler.h',
    'core/src/server/game/Scenarios/ScenarioMgr.cpp',
    'core/src/server/game/Miscellaneous/SharedDefines.h',
    'core/src/server/game/Spells/SpellMgr.cpp',
    'core/src/server/game/Spells/SpellEffects.cpp',
    'core/src/server/game/Spells/SpellInfo.cpp',
    'core/src/server/game/World/World.cpp',
    'core/src/server/worldserver/Main.cpp',
    'core/src/server/bnetserver/Main.cpp'
)
$binaryNames = @('worldserver.exe', 'bnetserver.exe')

function Get-CurrentHashes([string]$Base, [string[]]$RelativePaths) {
    $hashes = @()
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $Base $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing file: $path" }
        $hashes += [pscustomobject]@{
            Path = $relative
            SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return $hashes
}

try {
    $sources = @(Get-CurrentHashes $Root $sourcePaths)
    $binaries = @(Get-CurrentHashes $ServerDir $binaryNames)
    if ($Update) {
        if (-not (Test-Path -LiteralPath $ServerDir -PathType Container)) { throw "Missing server directory: $ServerDir" }
        $manifest = [ordered]@{
            Format = 1
            BuiltAtUtc = [DateTime]::UtcNow.ToString('o')
            Sources = $sources
            Binaries = $binaries
        }
        $tmp = "$manifestPath.tmp"
        try {
            $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tmp -Encoding UTF8
            Move-Item -LiteralPath $tmp -Destination $manifestPath -Force
        }
        finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        if (-not $Quiet) { Write-Host '  [OK] Build fingerprint recorded: server\build_sources.json' -ForegroundColor Green }
        exit 0
    }

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Build fingerprint is missing (server\build_sources.json). Existing EXEs may contain the old SpellEffect ASSERT.'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.Format -ne 1 -or @($manifest.Sources).Count -ne $sourcePaths.Count -or @($manifest.Binaries).Count -ne $binaryNames.Count) {
        throw 'Build fingerprint is incomplete or from an older release.'
    }
    foreach ($group in @(@{ Current = $sources; Recorded = @($manifest.Sources) }, @{ Current = $binaries; Recorded = @($manifest.Binaries) })) {
        for ($i = 0; $i -lt $group.Current.Count; $i++) {
            $actual = $group.Current[$i]
            $expected = $group.Recorded[$i]
            if ($expected.Path -cne $actual.Path -or $expected.SHA256 -ne $actual.SHA256) {
                throw "Binary/source mismatch: $($actual.Path). The server must be rebuilt."
            }
        }
    }
    if (-not $Quiet) { Write-Host '  [OK] worldserver/bnetserver match the spell and DB2 source tree.' -ForegroundColor Green }
    exit 0
}
catch {
    Write-Host "  [ОШИБКА] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '      Run build_server.bat, then play.bat. Do not reuse old server/*.exe.' -ForegroundColor Yellow
    exit 1
}
