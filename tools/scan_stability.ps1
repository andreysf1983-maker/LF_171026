<#
.SYNOPSIS
  DB stability scan: phasing coverage, starter maps, warlock pet, quest phase scripts.

.USAGE
  .\tools\scan_stability.ps1
#>
param(
    [string]$Root = "",
    [string]$MysqlExe = "",
    [string]$CnfPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
if (-not $CnfPath) { $CnfPath = Join-Path $Root "setup_tmp\mysql.cnf" }
if (-not $MysqlExe) {
    $candidates = @(
        "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $MysqlExe = $c; break } }
    if (-not $MysqlExe) {
        $findScript = Join-Path $Root "find_mysql.ps1"
        if (Test-Path $findScript) { $MysqlExe = & $findScript -Port 3306 }
    }
}

$outDir = Join-Path $Root "docs\stability\generated"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-World([string]$Sql) {
    $raw = & $MysqlExe --defaults-extra-file=$CnfPath world -N -B -e $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($raw -join "`n") }
    return $raw
}

Write-Host "[*] Stability scan..."

$mapPhase = Invoke-World @"
SELECT map,
  COUNT(*) AS total,
  SUM(PhaseId <> 0 OR PhaseGroup <> 0) AS phased,
  ROUND(100 * SUM(PhaseId <> 0 OR PhaseGroup <> 0) / COUNT(*), 2) AS pct_phased
FROM creature
GROUP BY map
ORDER BY total DESC
"@
[System.IO.File]::WriteAllLines((Join-Path $outDir "creature-phase-by-map.txt"), $mapPhase)

$starter = Invoke-World @"
SELECT 'kalimdor_starters' AS bucket, COUNT(*) AS total,
  SUM(PhaseId <> 0 OR PhaseGroup <> 0) AS phased
FROM creature WHERE map = 1 AND zoneId IN (14, 363, 6451, 6452, 6453, 6454, 6455, 6456, 6457)
UNION ALL
SELECT 'ek_starters', COUNT(*), SUM(PhaseId <> 0 OR PhaseGroup <> 0)
FROM creature WHERE map = 0 AND zoneId IN (1, 9, 12, 40, 85, 130, 132, 154, 188, 220)
UNION ALL
SELECT 'wandering_isle', COUNT(*), SUM(PhaseId <> 0 OR PhaseGroup <> 0)
FROM creature WHERE map = 860
UNION ALL
SELECT 'lost_isles', COUNT(*), SUM(PhaseId <> 0 OR PhaseGroup <> 0)
FROM creature WHERE map = 648
UNION ALL
SELECT 'gilneas', COUNT(*), SUM(PhaseId <> 0 OR PhaseGroup <> 0)
FROM creature WHERE map = 654
"@
[System.IO.File]::WriteAllLines((Join-Path $outDir "starter-phase-coverage.txt"), $starter)

$phaseMeta = Invoke-World @"
SELECT 'phase_area' AS k, COUNT(*) FROM phase_area
UNION ALL SELECT 'conditions_26', COUNT(*) FROM conditions WHERE SourceTypeOrReferenceId = 26
UNION ALL SELECT 'quest_generic_phase', COUNT(*) FROM quest_template_addon WHERE ScriptName = 'quest_generic_phase'
UNION ALL SELECT 'legion_quest_item_target', COUNT(*) FROM legion_quest_item_target
UNION ALL SELECT 'creature_phased', COUNT(*) FROM creature WHERE PhaseId <> 0 OR PhaseGroup <> 0
UNION ALL SELECT 'gameobject_phased', COUNT(*) FROM gameobject WHERE PhaseId <> 0 OR PhaseGroup <> 0
"@
[System.IO.File]::WriteAllLines((Join-Path $outDir "phase-meta-counts.txt"), $phaseMeta)

$imp = Invoke-World @"
SELECT entry, name, modelid1, scale, minlevel, maxlevel
FROM creature_template WHERE entry IN (416, 58959, 55659, 417, 1860, 1863, 17252)
"@
[System.IO.File]::WriteAllLines((Join-Path $outDir "warlock-pet-templates.txt"), $imp)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Stability scan summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("See [PROBLEM-AREAS.md](../../PROBLEM-AREAS.md) for analysis.")
[void]$sb.AppendLine("")
$fence = '```'
[void]$sb.AppendLine("## Phase meta")
[void]$sb.AppendLine("")
[void]$sb.AppendLine($fence)
foreach ($line in $phaseMeta) { [void]$sb.AppendLine($line) }
[void]$sb.AppendLine($fence)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Starter coverage (total / phased)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine($fence)
foreach ($line in $starter) { [void]$sb.AppendLine($line) }
[void]$sb.AppendLine($fence)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Top maps by creature count")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Map | Total | Phased | % |")
[void]$sb.AppendLine("|-----|------:|-------:|--:|")
foreach ($line in ($mapPhase | Select-Object -First 20)) {
    $p = $line -split "`t"
    if ($p.Count -ge 4) {
        [void]$sb.AppendLine("| $($p[0]) | $($p[1]) | $($p[2]) | $($p[3]) |")
    }
}
[System.IO.File]::WriteAllText((Join-Path $outDir "SUMMARY.md"), $sb.ToString())

Write-Host "[OK] $outDir"
Write-Host "     Run: python .\tools\legion_db2\scan_levelup_spells.py"
