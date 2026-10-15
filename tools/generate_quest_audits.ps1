<#
.SYNOPSIS
  Run quest audit SQL and write summary markdown under docs/quests/generated/.

.USAGE
  .\tools\generate_quest_audits.ps1
  .\tools\generate_quest_audits.ps1 -FullMissingSpawns   # all levels (large)
#>
param(
    [switch]$FullMissingSpawns,
    [string]$Root = "",
    [string]$MysqlExe = "",
    [string]$CnfPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
if (-not $CnfPath) { $CnfPath = Join-Path $Root "setup_tmp\mysql.cnf" }
if (-not $MysqlExe) {
    $findScript = Join-Path $Root "find_mysql.ps1"
    if (Test-Path $findScript) { $MysqlExe = & $findScript -Port 3306 }
}
if (-not $MysqlExe -or -not (Test-Path $MysqlExe)) {
    Write-Error "mysql.exe not found. Run setup.bat or pass -MysqlExe."
}
if (-not (Test-Path $CnfPath)) {
    Write-Error "Missing $CnfPath"
}

$genDir = Join-Path $Root "docs\quests\generated"
New-Item -ItemType Directory -Force -Path $genDir | Out-Null

function Invoke-WorldQuery([string]$Sql) {
    $raw = & $MysqlExe --defaults-extra-file=$CnfPath world -N -B -e $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($raw -join "`n") }
    return $raw
}

function Write-QueryFile([string]$Name, [string]$Sql) {
    $path = Join-Path $genDir $Name
    $rows = Invoke-WorldQuery $Sql
    [System.IO.File]::WriteAllLines($path, $rows)
    Write-Host "  [OK] $Name ($($rows.Count) rows)"
    return $rows
}

Write-Host "[*] Running quest audits..."

$trainingDummy = 44175
$lvlMax = if ($FullMissingSpawns) { 999 } else { 20 }

# Missing creature spawns (NOT EXISTS avoids only_full_group_by issues)
$missingSql = @"
SELECT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID, IFNULL(qo.Description,'')
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
WHERE qo.Type = 0 AND qo.ObjectID > 0 AND qt.QuestLevel BETWEEN 1 AND $lvlMax
  AND NOT EXISTS (SELECT 1 FROM creature c WHERE c.id = qo.ObjectID)
ORDER BY qt.QuestSortID, qo.QuestID, qo.ObjectID
"@
$missingRows = Write-QueryFile "audit-missing-spawns-l1-$lvlMax.txt" $missingSql

# Real missing (exclude training dummy and deprecated titles)
$realMissing = @()
$dummyCount = 0
$deprecatedCount = 0
foreach ($line in $missingRows) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 5) { continue }
    if ([int]$p[3] -eq $trainingDummy) { $dummyCount++; continue }
    if ($p[1] -match '\[DEPRECATED\]') { $deprecatedCount++; continue }
    $realMissing += $line
}
[System.IO.File]::WriteAllLines((Join-Path $genDir "audit-missing-spawns-real-l1-$lvlMax.txt"), $realMissing)
Write-Host "  [OK] audit-missing-spawns-real-l1-$lvlMax.txt ($($realMissing.Count) rows, excluded dummy=$dummyCount deprecated=$deprecatedCount)"

# Instance-only kill targets (creature exists only on instance maps)
$instanceSql = @"
SELECT DISTINCT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID, c.map, c.zoneId, c.areaId
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
JOIN creature c ON c.id = qo.ObjectID
WHERE qo.Type = 0 AND qo.ObjectID > 0 AND qt.QuestLevel BETWEEN 1 AND 30
  AND NOT EXISTS (
    SELECT 1 FROM creature c2
    WHERE c2.id = qo.ObjectID AND c2.map IN (0, 1, 530, 571, 732, 870, 1116, 1220, 1464)
  )
ORDER BY qt.QuestSortID, qo.QuestID
"@
$instanceRows = Write-QueryFile "audit-instance-only-spawns-l1-30.txt" $instanceSql

# Phased on accept (starter levels)
$phasedSql = @"
SELECT DISTINCT c.ConditionValue1 AS quest_id, qt.LogTitle, qt.QuestSortID, c.SourceGroup AS phase_area
FROM conditions c
JOIN quest_template qt ON qt.ID = c.ConditionValue1
WHERE c.SourceTypeOrReferenceId = 26 AND c.ConditionTypeOrReference = 9
  AND qt.QuestLevel BETWEEN 1 AND 15
ORDER BY qt.QuestSortID, c.ConditionValue1
"@
$phasedRows = Write-QueryFile "audit-phased-starter-accept.txt" $phasedSql

# Criteria / progress bar starters
$criteriaSql = @"
SELECT DISTINCT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.Type, qo.ObjectID
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
WHERE qo.Type IN (14, 15) AND qt.QuestLevel BETWEEN 1 AND 12
ORDER BY qt.QuestSortID, qo.QuestID
"@
$criteriaRows = Write-QueryFile "audit-criteria-starter.txt" $criteriaSql

# P05 capture candidates L1-20
$p05Sql = @"
SELECT qt.ID, qt.LogTitle, qt.QuestSortID, qt.StartItem, qo.ObjectID, IFNULL(qo.Description,'')
FROM quest_template qt
JOIN quest_objectives qo ON qo.QuestID = qt.ID AND qo.Type = 0
WHERE qt.StartItem > 0 AND qt.QuestLevel BETWEEN 1 AND 20
ORDER BY qt.QuestSortID, qt.ID
"@
$p05Rows = Write-QueryFile "audit-p05-capture-l1-20.txt" $p05Sql

# P05 all levels (Legion band)
$p05AllSql = @"
SELECT qt.ID, qt.LogTitle, qt.QuestSortID, qt.StartItem, qo.ObjectID, IFNULL(qo.Description,'')
FROM quest_template qt
JOIN quest_objectives qo ON qo.QuestID = qt.ID AND qo.Type = 0
WHERE qt.StartItem > 0 AND qt.QuestLevel BETWEEN 1 AND $lvlMax
ORDER BY qt.QuestSortID, qt.ID
"@
$p05AllRows = Write-QueryFile "audit-p05-capture-l1-$lvlMax.txt" $p05AllSql

# Credit bunnies / invisible targets (no creature row, name hints script-only)
$creditBunnySql = @"
SELECT qo.QuestID, qt.LogTitle, qt.QuestSortID, qo.ObjectID, IFNULL(ct.name,''), IFNULL(ct.unit_flags,0)
FROM quest_objectives qo
JOIN quest_template qt ON qt.ID = qo.QuestID
LEFT JOIN creature_template ct ON ct.entry = qo.ObjectID
WHERE qo.Type = 0 AND qo.ObjectID > 0 AND qt.QuestLevel BETWEEN 1 AND $lvlMax
  AND NOT EXISTS (SELECT 1 FROM creature c WHERE c.id = qo.ObjectID)
  AND (
    IFNULL(ct.name,'') REGEXP 'Credit|Bunny|Trigger|Dummy|Stalker|Invisible|Proxy|Spirit|Servant|Target'
    OR IFNULL(ct.unit_flags,0) & 33554432
    OR qo.ObjectID = $trainingDummy
  )
ORDER BY qt.QuestSortID, qo.QuestID
"@
$creditBunnyRows = Write-QueryFile "audit-credit-bunny-l1-$lvlMax.txt" $creditBunnySql

# Fixable missing spawns = real missing minus credit bunnies
$creditBunnyIds = @{}
foreach ($line in $creditBunnyRows) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 4) { continue }
    $creditBunnyIds["$($p[0])|$($p[3])"] = $true
}
$fixableMissing = @()
foreach ($line in $realMissing) {
    $p = $line -split "`t"
    if ($p.Count -lt 4) { continue }
    if ($creditBunnyIds.ContainsKey("$($p[0])|$($p[3])")) { continue }
    $fixableMissing += $line
}
[System.IO.File]::WriteAllLines((Join-Path $genDir "audit-fixable-missing-spawns-l1-$lvlMax.txt"), $fixableMissing)
Write-Host "  [OK] audit-fixable-missing-spawns-l1-$lvlMax.txt ($($fixableMissing.Count) rows, credit-bunny=$($creditBunnyRows.Count))"

# Starter QuestSortID discovery
$sortSql = @"
SELECT QuestSortID, COUNT(*) AS cnt
FROM quest_template
WHERE QuestLevel BETWEEN 1 AND 12
GROUP BY QuestSortID
ORDER BY cnt DESC, QuestSortID
"@
$sortRows = Write-QueryFile "quest-sortids-starter.txt" $sortSql

function Group-BySortId($rows) {
    $groups = @{}
    foreach ($line in $rows) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $p = $line -split "`t"
        if ($p.Count -lt 3) { continue }
        $sid = $p[2]
        if (-not $groups.ContainsKey($sid)) { $groups[$sid] = 0 }
        $groups[$sid]++
    }
    return ($groups.GetEnumerator() | Sort-Object { [int]$_.Value } -Descending)
}

$missingByZone = Group-BySortId $missingRows
$realByZone = @{}
foreach ($line in $realMissing) {
    $p = $line -split "`t"
    $sid = $p[2]
    if (-not $realByZone.ContainsKey($sid)) { $realByZone[$sid] = 0 }
    $realByZone[$sid]++
}

# --- AUDIT-SUMMARY.md ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Quest audit summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Raw outputs in this folder. Re-run: ``.\tools\generate_quest_audits.ps1``")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Counts (levels 1-$lvlMax)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Count |")
[void]$sb.AppendLine("|--------|------:|")
[void]$sb.AppendLine("| Kill objectives with **no** ``creature`` row | $($missingRows.Count) |")
[void]$sb.AppendLine("| Excluding training dummy **44175** | $($missingRows.Count - $dummyCount) |")
[void]$sb.AppendLine("| Excluding dummy + ``[DEPRECATED]`` titles | $($realMissing.Count) |")
[void]$sb.AppendLine("| Credit bunny / script-only targets | $($creditBunnyRows.Count) |")
[void]$sb.AppendLine("| **Fixable** missing spawns (real minus credit bunnies) | $($fixableMissing.Count) |")
[void]$sb.AppendLine("| P05 item-use capture (L1-20) | $($p05Rows.Count) |")
[void]$sb.AppendLine("| P05 item-use capture (L1-$lvlMax) | $($p05AllRows.Count) |")
[void]$sb.AppendLine("| Phased on accept (L1-15) | $($phasedRows.Count) |")
[void]$sb.AppendLine("| Criteria / progress bar (L1-12) | $($criteriaRows.Count) |")
[void]$sb.AppendLine("| Instance-only kill targets (L1-30) | $($instanceRows.Count) |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Training dummy (44175) - not broken spawns")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Class starter **practice spell** quests use creature **44175** (Training Dummy).")
[void]$sb.AppendLine("These appear in the missing-spawn audit but are **expected** - dummy is spawned by the class")
[void]$sb.AppendLine("starter zone script, not the world ``creature`` table. Pattern: **P07-like** scripted hit.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Top QuestSortIDs - fixable missing spawns")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| QuestSortID | Fixable rows |")
[void]$sb.AppendLine("|-------------|-------------:|")
$fixableByZone = @{}
foreach ($line in $fixableMissing) {
    $p = $line -split "`t"
    $sid = $p[2]
    if (-not $fixableByZone.ContainsKey($sid)) { $fixableByZone[$sid] = 0 }
    $fixableByZone[$sid]++
}
foreach ($kv in ($fixableByZone.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25)) {
    [void]$sb.AppendLine("| $($kv.Key) | $($kv.Value) |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Top QuestSortIDs - real missing spawns")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| QuestSortID | Missing objective rows |")
[void]$sb.AppendLine("|-------------|----------------------:|")
foreach ($kv in ($realByZone.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25)) {
    [void]$sb.AppendLine("| $($kv.Key) | $($kv.Value) |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Top QuestSortIDs - all missing (incl. dummy)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| QuestSortID | Rows |")
[void]$sb.AppendLine("|-------------|-----:|")
foreach ($kv in ($missingByZone | Select-Object -First 15)) {
    [void]$sb.AppendLine("| $($kv.Name) | $($kv.Value) |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Action priority")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("1. **Real missing spawns** in exported starter zones (see zone catalogs) - add ``creature`` rows or P05 spawn-on-accept.")
[void]$sb.AppendLine("2. **P05 capture** quests with ``StartItem`` - batch QuestScript template.")
[void]$sb.AppendLine("3. **P09 phased** accepts - verify ``conditions`` type 26 + ``OnConditionChange`` on reward.")
[void]$sb.AppendLine("4. **P10 instance-only** objectives - see [INSTANCED-QUESTS.md](INSTANCED-QUESTS.md); do not spawn on open world.")
[void]$sb.AppendLine("5. **44175** class quests - verify dummy spawn in class starter area only if players report stuck objectives.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Files")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| File | Contents |")
[void]$sb.AppendLine("|------|----------|")
[void]$sb.AppendLine("| ``audit-missing-spawns-l1-$lvlMax.txt`` | All kill objectives without creature row |")
[void]$sb.AppendLine("| ``audit-missing-spawns-real-l1-$lvlMax.txt`` | Excludes dummy + deprecated |")
[void]$sb.AppendLine("| ``audit-fixable-missing-spawns-l1-$lvlMax.txt`` | Real minus credit bunnies |")
[void]$sb.AppendLine("| ``audit-credit-bunny-l1-$lvlMax.txt`` | Script-only / invisible targets |")
[void]$sb.AppendLine("| ``audit-p05-capture-l1-20.txt`` | StartItem + kill objective |")
[void]$sb.AppendLine("| ``audit-p05-capture-l1-$lvlMax.txt`` | P05 all levels in band |")
[void]$sb.AppendLine("| ``audit-phased-starter-accept.txt`` | Phase on quest accept |")
[void]$sb.AppendLine("| ``audit-criteria-starter.txt`` | Criteria tree / progress bar |")
[void]$sb.AppendLine("| ``audit-instance-only-spawns-l1-30.txt`` | Mobs only on instance maps |")
[void]$sb.AppendLine("| ``quest-sortids-starter.txt`` | QuestSortID buckets (L1-12) |")

$summaryPath = Join-Path $genDir "AUDIT-SUMMARY.md"
[System.IO.File]::WriteAllText($summaryPath, $sb.ToString())
Write-Host "[OK] $summaryPath"

# --- INSTANCED-QUESTS.md ---
$isb = New-Object System.Text.StringBuilder
[void]$isb.AppendLine("# Instanced & phased quest index (audit)")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("See [INSTANCING.md](../INSTANCING.md) for fix recipes (P09 vs P10).")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("## Phased on accept (levels 1-15)")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("| Quest ID | Title | QuestSortID | Phase area |")
[void]$isb.AppendLine("|----------|-------|-------------|------------|")
foreach ($line in $phasedRows) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 4) { continue }
    [void]$isb.AppendLine("| $($p[0]) | $($p[1]) | $($p[2]) | $($p[3]) |")
}
[void]$isb.AppendLine("")
[void]$isb.AppendLine("## Instance-only kill objectives (levels 1-30)")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("These creatures have spawns **only** on instance maps - open-world spawn is wrong fix.")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("| Quest ID | Title | QuestSortID | Creature | Map | Zone | Area |")
[void]$isb.AppendLine("|----------|-------|-------------|----------|-----|------|------|")
foreach ($line in $instanceRows) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 7) { continue }
    [void]$isb.AppendLine("| $($p[0]) | $($p[1]) | $($p[2]) | $($p[3]) | $($p[4]) | $($p[5]) | $($p[6]) |")
}
[void]$isb.AppendLine("")
[void]$isb.AppendLine("## Criteria / progress bar (levels 1-12)")
[void]$isb.AppendLine("")
[void]$isb.AppendLine("| Quest ID | Title | QuestSortID | Obj type | Object ID |")
[void]$isb.AppendLine("|----------|-------|-------------|----------|-----------|")
foreach ($line in $criteriaRows) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 5) { continue }
    $tName = if ($p[3] -eq "14") { "CRITERIA_TREE" } else { "PROGRESS_BAR" }
    [void]$isb.AppendLine("| $($p[0]) | $($p[1]) | $($p[2]) | $tName | $($p[4]) |")
}

$instPath = Join-Path $genDir "INSTANCED-QUESTS.md"
[System.IO.File]::WriteAllText($instPath, $isb.ToString())
Write-Host "[OK] $instPath"
Write-Host "[OK] Audit complete."
