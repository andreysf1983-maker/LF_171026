[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('world', 'hotfixes')]
    [string]$Database,
    [string]$MysqlExe = '',
    [string]$CnfPath = ''
)

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
if (-not $CnfPath) { $CnfPath = Join-Path $Root 'setup_tmp\mysql.cnf' }
if (-not $MysqlExe) {
    $MysqlExe = & (Join-Path $Root 'find_mysql.ps1') -Port 3306 | Select-Object -First 1
}
if ($MysqlExe) { $MysqlExe = "$MysqlExe".Trim() }
if (-not $MysqlExe -or -not (Test-Path -LiteralPath $MysqlExe)) {
    Write-Host "[ERROR] mysql.exe was not found."
    exit 2
}
if (-not (Test-Path -LiteralPath $CnfPath)) {
    Write-Host "[ERROR] MySQL credentials file was not found: $CnfPath"
    exit 2
}

switch ($Database) {
    'world' {
        $requiredTables = @(
            'creature', 'gameobject', 'creature_template', 'gameobject_template',
            'instance_template', 'lfg_dungeon_template', 'playercreateinfo_cast_spell',
            'quest_template_addon', 'creature_queststarter', 'achievement_reward',
            'playercreateinfo'
        )
        $dataTables = @('creature_template', 'gameobject_template', 'quest_template')
    }
    'hotfixes' {
        $requiredTables = @('item_sparse', 'spell', 'battle_pet_species')
        # ADB_735.10 defines battle_pet_species but intentionally ships zero rows here;
        # the actual client DB2 data is supplied by the Legion client. Requiring rows
        # in this table rejects the verified clean upstream dump. item_sparse and spell
        # must contain rows so an empty/unimported hotfix DB is still detected.
        $dataTables = @('item_sparse', 'spell')
    }
}

$tableList = ($requiredTables | ForEach-Object { "'$_'" }) -join ', '
$query = @"
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$Database';
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$Database' AND table_name IN ($tableList);
"@
$output = @(& $MysqlExe "--defaults-extra-file=$CnfPath" '--batch' '--skip-column-names' '-e' $query 2>&1)
$mysqlExitCode = $LASTEXITCODE
if ($mysqlExitCode -ne 0) {
    foreach ($line in $output) { if ("$line".Trim()) { Write-Host "  $line" } }
    Write-Host "[ERROR] Could not inspect database '$Database'."
    exit 2
}
$numbers = @($output | ForEach-Object { "$($_)".Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int64]$_ })
if ($numbers.Count -lt 2) {
    Write-Host "[ERROR] MySQL returned an unexpected schema status for '$Database'."
    exit 2
}
$tableCount = $numbers[0]
$foundRequired = $numbers[1]
if ($tableCount -eq 0) {
    Write-Host "[EMPTY] Database '$Database' has no tables; safe to import."
    exit 3
}
if ($foundRequired -ne $requiredTables.Count) {
    Write-Host "[INCOMPLETE] Database '$Database' has $tableCount tables but only $foundRequired/$($requiredTables.Count) required tables. Existing data will not be overwritten."
    exit 4
}

$dataQueries = ($dataTables | ForEach-Object { "SELECT COUNT(*) FROM $Database.$_" }) -join ';'
$dataOutput = @(& $MysqlExe "--defaults-extra-file=$CnfPath" '--batch' '--skip-column-names' '-e' ($dataQueries + ';') 2>&1)
$dataExitCode = $LASTEXITCODE
if ($dataExitCode -ne 0) {
    foreach ($line in $dataOutput) { if ("$line".Trim()) { Write-Host "  $line" } }
    Write-Host "[ERROR] Could not verify imported rows in '$Database'."
    exit 2
}
$rowCounts = @($dataOutput | ForEach-Object { "$($_)".Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int64]$_ })
if ($rowCounts.Count -ne $dataTables.Count -or @($rowCounts | Where-Object { $_ -le 0 }).Count -gt 0) {
    Write-Host "[INCOMPLETE] Database '$Database' has its schema but one or more required data tables are empty. Existing data will not be overwritten."
    exit 4
}

Write-Host "[OK] Database '$Database' is ready: $tableCount tables; required data rows verified."
exit 0
