<#
.SYNOPSIS
  Export quest chains from the world DB into docs/quests/zones/ as pattern-tagged markdown.

.USAGE
  .\tools\export_quest_catalog.ps1                         # export configured zones
  .\tools\export_quest_catalog.ps1 -AllStarterZones        # all QuestSortIDs with L1-12 quests
  .\tools\export_quest_catalog.ps1 -ZoneId 6453            # single QuestSortID
  .\tools\export_quest_catalog.ps1 -PatternReport          # pattern summary only
  .\tools\export_quest_catalog.ps1 -MasterIndex            # full quest CSV index
  .\tools\export_quest_catalog.ps1 -ZoneIndex              # regenerate zones/README.md table
#>
param(
    [int]$ZoneId = 0,
    [switch]$PatternReport,
    [switch]$AllStarterZones,
    [switch]$MasterIndex,
    [switch]$ZoneIndex,
    [int]$StarterLevelMax = 12,
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

$outDir = Join-Path $Root "docs\quests\zones"
$genDir = Join-Path $Root "docs\quests\generated"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $genDir | Out-Null

function Invoke-WorldQuery([string]$Sql) {
    $raw = & $MysqlExe --defaults-extra-file=$CnfPath world -N -B -e $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($raw -join "`n") }
    return $raw
}

# QuestSortID => slug, display name (curated overrides for export filenames)
$ZoneCatalog = @{
    6453 = @{ Slug = "6453-echo-isles-durotar"; Name = "Echo Isles / Darkspear (6453)"; LevelMax = 12 }
    6451 = @{ Slug = "6451-valley-of-trials"; Name = "Valley of Trials Orc (6451)"; LevelMax = 10 }
    363  = @{ Slug = "363-valley-of-trials-classic"; Name = "Valley of Trials Classic (363)"; LevelMax = 10 }
    14   = @{ Slug = "14-durotar"; Name = "Durotar Senjin onward (14)"; LevelMax = 12 }
    85   = @{ Slug = "85-tirisfal"; Name = "Tirisfal Glades (85)"; LevelMax = 12 }
    130  = @{ Slug = "130-silverpine"; Name = "Silverpine Forest (130)"; LevelMax = 20 }
    148  = @{ Slug = "148-teledrassil"; Name = "Teldrassil (148)"; LevelMax = 12 }
    3524 = @{ Slug = "3524-azuremyst"; Name = "Azuremyst Isle (3524)"; LevelMax = 12 }
    6170 = @{ Slug = "6170-wandering-isle"; Name = "Wandering Isle Pandaren (6170)"; LevelMax = 12 }
}

# Negative QuestSortIDs = class starter buckets; positive = zone buckets
$KnownZoneNames = @{
    6453 = "Echo Isles / Darkspear (6453)"
    6451 = "Valley of Trials Orc (6451)"
    363  = "Valley of Trials Classic (363)"
    14   = "Durotar Senjin onward (14)"
    85   = "Tirisfal Glades (85)"
    130  = "Silverpine Forest (130)"
    148  = "Teldrassil (148)"
    3524 = "Azuremyst Isle (3524)"
    6170 = "Wandering Isle Pandaren (6170)"
    5736 = "Wandering Isle / Pandaren (5736)"
    6457 = "Elwynn Forest (6457)"
    4755 = "Gilneas (4755)"
    4737 = "Kezan Goblin (4737)"
    5785 = "Deathknell starter (5785)"
    6138 = "Sunstrider Isle Blood Elf (6138)"
    4714 = "Mists starter zone (4714)"
    6456 = "Azuremyst Draenei (6456)"
    6455 = "Ammen Vale (6455)"
    6176 = "Pandaren continuation (6176)"
    6454 = "Eversong Woods (6454)"
    6452 = "Mulgore Tauren (6452)"
    6450 = "Camp Narache (6450)"
    6984 = "Frostfire Ridge (6984)"
    5841 = "Shadowmoon Valley Draenor (5841)"
    5842 = "Tanaan Jungle intro (5842)"
    -81  = "Warrior class starter (-81)"
    -82  = "Shaman class starter (-82)"
    -161 = "Mage class starter (-161)"
    -162 = "Rogue class starter (-162)"
    -261 = "Hunter class starter (-261)"
    -262 = "Priest class starter (-262)"
    -263 = "Druid class starter (-263)"
    -395 = "Monk class starter (-395)"
    -141 = "Paladin class starter (-141)"
    -61  = "Warlock class starter (-61)"
    -284 = "Test / dev bucket (-284)"
}

function Get-ZoneSlug([int]$SortId) {
    if ($ZoneCatalog.ContainsKey($SortId)) { return $ZoneCatalog[$SortId].Slug }
    return "$SortId-zone-bucket"
}

function Get-ZoneName([int]$SortId) {
    if ($ZoneCatalog.ContainsKey($SortId)) { return $ZoneCatalog[$SortId].Name }
    if ($KnownZoneNames.ContainsKey($SortId)) { return $KnownZoneNames[$SortId] }
    return "QuestSortID $SortId"
}

function Discover-StarterZones([int]$LevelMax) {
    $sql = @"
SELECT QuestSortID, COUNT(*) AS cnt
FROM quest_template
WHERE QuestLevel BETWEEN 1 AND $LevelMax
GROUP BY QuestSortID
ORDER BY cnt DESC, QuestSortID
"@
    $rows = Invoke-WorldQuery $sql
    $discovered = @{}
    foreach ($line in $rows) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $p = $line -split "`t"
        if ($p.Count -lt 2) { continue }
        $sid = [int]$p[0]
        if ($ZoneCatalog.ContainsKey($sid)) {
            $z = $ZoneCatalog[$sid]
            $meta = @{ Slug = $z.Slug; Name = $z.Name; LevelMax = $z.LevelMax; Count = [int]$p[1] }
        } else {
            $meta = @{ Slug = (Get-ZoneSlug $sid); Name = (Get-ZoneName $sid); LevelMax = $LevelMax; Count = [int]$p[1] }
        }
        if (-not $meta.LevelMax -or $meta.LevelMax -lt $LevelMax) { $meta.LevelMax = $LevelMax }
        if (-not $meta.Count) { $meta.Count = [int]$p[1] }
        $discovered["$sid"] = $meta
    }
    return $discovered
}

function Export-MasterIndex {
    Write-Host "[*] Exporting master quest index (all quests)..."
    $sql = @"
SELECT qt.ID, REPLACE(qt.LogTitle, CHAR(9), ' '), qt.QuestLevel, qt.QuestSortID,
       IFNULL(qta.PrevQuestID,0), IFNULL(qta.NextQuestID,0), IFNULL(qt.StartItem,0),
       IFNULL(qta.ScriptName,''),
       IFNULL(GROUP_CONCAT(DISTINCT qo.Type ORDER BY qo.Type SEPARATOR ','), '')
FROM quest_template qt
LEFT JOIN quest_template_addon qta ON qta.ID = qt.ID
LEFT JOIN quest_objectives qo ON qo.QuestID = qt.ID
GROUP BY qt.ID, qt.LogTitle, qt.QuestLevel, qt.QuestSortID,
         qta.PrevQuestID, qta.NextQuestID, qt.StartItem, qta.ScriptName
ORDER BY qt.QuestSortID, qt.QuestLevel, qt.ID
"@
    $rows = Invoke-WorldQuery $sql
    $csvPath = Join-Path $genDir "master-index.csv"
    $header = "ID,Title,Level,QuestSortID,PrevQuestID,NextQuestID,StartItem,ScriptName,ObjectiveTypes,Patterns"
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add($header)
    foreach ($line in $rows) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $p = $line -split "`t"
        if ($p.Count -lt 9) { continue }
        $typeNames = @()
        if ($p[8] -and $p[8] -ne "NULL") {
            foreach ($t in ($p[8] -split ",")) {
                if ($t -match '^\d+$' -and $ObjectiveTypes.ContainsKey([int]$t)) {
                    $typeNames += $ObjectiveTypes[[int]$t]
                }
            }
        }
        $tags = Get-PatternTags $p[6] $typeNames $false $p[7]
        $title = ($p[1] -replace '"','""')
        $script = ($p[7] -replace '"','""')
        $tagStr = ($tags -join ";")
        [void]$lines.Add("$($p[0]),`"$title`",$($p[2]),$($p[3]),$($p[4]),$($p[5]),$($p[6]),`"$script`",$($p[8]),`"$tagStr`"")
    }
    [System.IO.File]::WriteAllLines($csvPath, $lines)
    Write-Host "[OK] $csvPath ($($rows.Count) quests)"
}

function Write-ZoneIndexReadme([hashtable]$Zones) {
    $readmePath = Join-Path $outDir "README.md"
    $existingNotes = ""
    if (Test-Path $readmePath) {
        $content = Get-Content $readmePath -Raw
        if ($content -match '(?s)(## Manual notes.*)$') {
            $existingNotes = $Matches[1]
        }
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Zone quest catalogs")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Auto-generated from the world DB by ``tools/export_quest_catalog.ps1``. Re-run:")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('```powershell')
    [void]$sb.AppendLine('.\tools\export_quest_catalog.ps1 -AllStarterZones -ZoneIndex')
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Starter zones (levels 1-$StarterLevelMax)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| QuestSortID | Zone | File | Quest count |")
    [void]$sb.AppendLine("|-------------|------|------|------------:|")
    foreach ($kv in ($Zones.GetEnumerator() | Sort-Object { [int]$_.Key })) {
        $sid = [int]$kv.Key
        $meta = $kv.Value
        $file = "$($meta.Slug).md"
        $filePath = Join-Path $outDir $file
        $cnt = "-"
        if (Test-Path $filePath) {
            $match = Select-String -Path $filePath -Pattern '^\| \d+ \|' -AllMatches
            if ($match) { $cnt = $match.Matches.Count }
        }
        [void]$sb.AppendLine("| $sid | $($meta.Name) | [$file]($file) | $cnt |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## How to read a catalog file")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- **ID** - ``quest_template.ID``")
    [void]$sb.AppendLine("- **Prev / Next** - chain from ``quest_template_addon``")
    [void]$sb.AppendLine("- **Patterns** - auto tags ([TAXONOMY.md](../TAXONOMY.md))")
    [void]$sb.AppendLine("- **Provided item** - ``StartItem`` (capture quests)")
    [void]$sb.AppendLine("- **Script** - custom ``QuestScript`` if any")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Full quest lookup: [generated/master-index.csv](../generated/master-index.csv)")
    [void]$sb.AppendLine("")
    if ($existingNotes) {
        [void]$sb.AppendLine($existingNotes)
    } else {
        [void]$sb.AppendLine("## Manual notes (hand-edited below exports)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("### 6453 - Echo Isles priority fixes")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| ID | Title | Patterns | Status | Notes |")
        [void]$sb.AppendLine("|----|-------|----------|--------|-------|")
        [void]$sb.AppendLine("| 24626 | Young and Vicious | P05, P11 | SCRIPT | ``quest_young_and_vicious`` - spawn Swiftclaw 37989 on accept |")
        [void]$sb.AppendLine("| 24623 | Saving the Young | P01, P02 | TODO | Hatchlings 39157 - verify spawns + item 52283 |")
        [void]$sb.AppendLine("| 24814 | An Ancient Enemy | P01, P04 | TODO | Vol'jin talk + Spitescale - likely P09 |")
    }
    [System.IO.File]::WriteAllText($readmePath, $sb.ToString())
    Write-Host "[OK] $readmePath"
}

$ObjectiveTypes = @{
    0  = "MONSTER"
    1  = "ITEM"
    2  = "GAMEOBJECT"
    3  = "TALKTO"
    4  = "CURRENCY"
    5  = "LEARN_SPELL"
    6  = "MIN_REPUTATION"
    7  = "MAX_REPUTATION"
    8  = "MONEY"
    9  = "PLAYER_KILLS"
    10 = "AREATRIGGER"
    11 = "PET_BATTLE_NPC"
    12 = "DEFEAT_PET"
    13 = "WIN_PVP_PET"
    14 = "CRITERIA_TREE"
    15 = "PROGRESS_BAR"
    16 = "HAVE_CURRENCY"
    17 = "OBTAIN_CURRENCY"
}

function Get-PatternTags {
    param($StartItem, $ObjectiveTypeNames, $HasPhaseCond, $ScriptName)
    $tags = @()
    if ($ObjectiveTypeNames -contains "MONSTER") { $tags += "P01-KILL" }
    if ($ObjectiveTypeNames -contains "ITEM") { $tags += "P02-COLLECT" }
    if ($ObjectiveTypeNames -contains "GAMEOBJECT") { $tags += "P03-GAMEOBJECT" }
    if ($ObjectiveTypeNames -contains "TALKTO") { $tags += "P04-TALKTO" }
    if ($StartItem -gt 0 -and ($ObjectiveTypeNames -contains "MONSTER")) { $tags += "P05-ITEM-USE-CAPTURE" }
    if ($ObjectiveTypeNames -contains "AREATRIGGER") { $tags += "P06-AREATRIGGER" }
    if ($ObjectiveTypeNames -contains "CRITERIA_TREE") { $tags += "P07-CRITERIA-SCRIPTED" }
    if ($ObjectiveTypeNames -contains "PROGRESS_BAR") { $tags += "P08-PROGRESS-BAR" }
    if ($HasPhaseCond) { $tags += "P09-PHASED" }
    if ($ScriptName) { $tags += "P11-CUSTOM-SCRIPT" }
    if (-not $tags.Count) { $tags += "P00-UNKNOWN" }
    return ($tags | Select-Object -Unique)
}

function Export-Zone([int]$SortId, [hashtable]$Meta) {
    $lvlMax = $Meta.LevelMax
    $slug = $Meta.Slug
    $name = $Meta.Name

    $questSql = @"
SELECT qt.ID, qt.LogTitle, qt.QuestLevel, IFNULL(qta.PrevQuestID,0), IFNULL(qta.NextQuestID,0),
       IFNULL(qt.StartItem,0), IFNULL(qta.ScriptName,''),
       (SELECT GROUP_CONCAT(DISTINCT qo.Type ORDER BY qo.Type SEPARATOR ',')
        FROM quest_objectives qo WHERE qo.QuestID = qt.ID),
       (SELECT COUNT(*) FROM conditions c
        WHERE c.SourceTypeOrReferenceId = 26
          AND c.ConditionTypeOrReference IN (9,28,8)
          AND c.ConditionValue1 = qt.ID) > 0
FROM quest_template qt
LEFT JOIN quest_template_addon qta ON qta.ID = qt.ID
WHERE qt.QuestSortID = $SortId AND qt.QuestLevel BETWEEN 1 AND $lvlMax
ORDER BY qt.QuestLevel, qt.ID
"@
    $rows = Invoke-WorldQuery $questSql
    if (-not $rows -or $rows.Count -eq 0) {
        Write-Host "  [--] no quests for zone $SortId"
        return
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $name")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("QuestSortID: **$SortId** | Level range: 1-$lvlMax | Exported: $(Get-Date -Format 'yyyy-MM-dd')")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("See [TAXONOMY.md](../TAXONOMY.md) for pattern codes.")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| ID | Title | Lvl | Prev | Next | Patterns | Provided item | Script |")
    [void]$sb.AppendLine("|----|-------|-----|------|------|----------|---------------|--------|")

    $patternCounts = @{}

    foreach ($line in $rows) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $p = $line -split "`t"
        if ($p.Count -lt 9) { continue }
        $id, $title, $level, $prev, $next, $startItem, $script, $objTypes, $hasPhase = $p
        $typeNames = @()
        if ($objTypes -and $objTypes -ne "NULL") {
            foreach ($t in ($objTypes -split ",")) {
                if ($t -match '^\d+$' -and $ObjectiveTypes.ContainsKey([int]$t)) {
                    $typeNames += $ObjectiveTypes[[int]$t]
                }
            }
        }
        $hasPhaseBool = ($hasPhase -eq "1")
        $tags = Get-PatternTags $startItem $typeNames $hasPhaseBool $script
        foreach ($tag in $tags) {
            if (-not $patternCounts.ContainsKey($tag)) { $patternCounts[$tag] = 0 }
            $patternCounts[$tag]++
        }
        $tagStr = ($tags -join ", ")
        $itemStr = if ([int]$startItem -gt 0) { $startItem } else { "-" }
        $scriptStr = if ($script) { ('`' + $script + '`') } else { "-" }
        [void]$sb.AppendLine("| $id | $title | $level | $prev | $next | $tagStr | $itemStr | $scriptStr |")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Pattern summary (this zone)")
    [void]$sb.AppendLine("")
    foreach ($kv in ($patternCounts.GetEnumerator() | Sort-Object Name)) {
        [void]$sb.AppendLine("- **$($kv.Key)**: $($kv.Value) quest(s)")
    }

    # Detail block for high-risk patterns in this zone
    $detailSql = @"
SELECT qt.ID, qt.LogTitle, qo.Type, qo.ObjectID, IFNULL(qo.Description,''), IFNULL(qt.StartItem,0)
FROM quest_template qt
JOIN quest_objectives qo ON qo.QuestID = qt.ID
WHERE qt.QuestSortID = $SortId AND qt.QuestLevel BETWEEN 1 AND $lvlMax
  AND qo.Type IN (0,1,2,3,10,14,15)
ORDER BY qt.ID, qo.Order
"@
    $objRows = Invoke-WorldQuery $detailSql
    if ($objRows) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Objectives (implementation reference)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Quest | Objective type | ObjectID | Description | StartItem |")
        [void]$sb.AppendLine("|-------|----------------|----------|-------------|-----------|")
        foreach ($line in $objRows) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $p = $line -split "`t"
            if ($p.Count -lt 6) { continue }
            $tName = "TYPE_$($p[2])"
            if ($p[2] -match '^\d+$' -and $ObjectiveTypes.ContainsKey([int]$p[2])) {
                $tName = $ObjectiveTypes[[int]$p[2]]
            }
            $desc = $p[4] -replace '\|','/'
            [void]$sb.AppendLine("| $($p[0]) $($p[1]) | $tName | $($p[3]) | $desc | $($p[5]) |")
        }
    }

    $outPath = Join-Path $outDir "$slug.md"
    [System.IO.File]::WriteAllText($outPath, $sb.ToString())
    Write-Host "  [OK] $outPath ($($rows.Count) quests)"
    return $patternCounts
}

if ($MasterIndex) {
    Export-MasterIndex
    exit 0
}

$exportZones = $ZoneCatalog
if ($AllStarterZones) {
    Write-Host "[*] Discovering starter QuestSortIDs (levels 1-$StarterLevelMax)..."
    $exportZones = Discover-StarterZones $StarterLevelMax
    Write-Host "[*] Found $($exportZones.Count) zone buckets"
}

if ($PatternReport -and -not $AllStarterZones -and $ZoneId -eq 0) {
    $reportOnly = $true
} else {
    $reportOnly = $false
}

if ($PatternReport -or $AllStarterZones -or $ZoneId -eq 0) {
    if (-not $exportZones -or $exportZones.Count -eq 0) { $exportZones = $ZoneCatalog }
    $allPatterns = @{}
    $sortedZones = $exportZones.GetEnumerator() | Sort-Object { if ($_.Value.Count) { -$_.Value.Count } else { [int]$_.Key } }
    foreach ($kv in $sortedZones) {
        $sid = [int]$kv.Key
        $counts = Export-Zone $sid $kv.Value
        if ($counts) {
            foreach ($pk in $counts.Keys) {
                if (-not $allPatterns.ContainsKey($pk)) { $allPatterns[$pk] = 0 }
                $allPatterns[$pk] += $counts[$pk]
            }
        }
    }
    if ($PatternReport) {
        $reportPath = Join-Path $genDir "pattern-report.md"
        $rpt = New-Object System.Text.StringBuilder
        [void]$rpt.AppendLine("# Quest pattern report (exported zones)")
        [void]$rpt.AppendLine("")
        [void]$rpt.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
        [void]$rpt.AppendLine("Zones: $($exportZones.Count) | Starter level max: $StarterLevelMax")
        [void]$rpt.AppendLine("")
        foreach ($kv in ($allPatterns.GetEnumerator() | Sort-Object Name)) {
            [void]$rpt.AppendLine("- **$($kv.Key)**: $($kv.Value)")
        }
        [System.IO.File]::WriteAllText($reportPath, $rpt.ToString())
        Write-Host "[OK] $reportPath"
    }
    if ($ZoneIndex) { Write-ZoneIndexReadme $exportZones }
    if ($reportOnly) { exit 0 }
    Write-Host "[OK] Done. See docs/quests/zones/"
    exit 0
}

if ($ZoneId -gt 0) {
    $meta = if ($ZoneCatalog.ContainsKey($ZoneId)) { $ZoneCatalog[$ZoneId] }
            else { @{ Slug = (Get-ZoneSlug $ZoneId); Name = (Get-ZoneName $ZoneId); LevelMax = $StarterLevelMax } }
    Export-Zone $ZoneId $meta | Out-Null
    if ($ZoneIndex) { Write-ZoneIndexReadme @{ $ZoneId = $meta } }
} else {
    Write-Host "[*] Exporting $($exportZones.Count) zones..."
    $sortedZones = $exportZones.GetEnumerator() | Sort-Object { if ($_.Value.Count) { -$_.Value.Count } else { [int]$_.Key } }
    foreach ($kv in $sortedZones) {
        Export-Zone ([int]$kv.Key) $kv.Value | Out-Null
    }
    if ($ZoneIndex) { Write-ZoneIndexReadme $exportZones }
    Write-Host "[OK] Done. See docs/quests/zones/"
}
