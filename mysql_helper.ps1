param(
    [Parameter(Mandatory = $true)]
    [string]$Action,

    [string]$MysqlExe,
    [string]$Password,
    [string]$CnfPath,
    [string]$ConfPath,
    [string[]]$ConfKeys,
    [string]$DatabaseUser = 'admin@legionforge.ru',
    [string]$DatabasePassword = 'legionforge'
)

$ErrorActionPreference = 'Stop'

if (-not $Password) { $Password = $env:SETUP_MYSQL_PASS }

function Get-MysqlExe {
    if ($MysqlExe -and (Test-Path -LiteralPath $MysqlExe)) { return $MysqlExe }
    $exe = & "$PSScriptRoot\find_mysql.ps1" -Port 3306 -EnsureRunning | Select-Object -First 1
    if ($exe) { $exe = $exe.ToString().Trim() }
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { throw 'mysql.exe not found' }
    return $exe
}

function Get-PasswordFromCnf([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return '' }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^password=(.*)$') { return $Matches[1] }
    }
    if ($env:SETUP_MYSQL_PASS) { return $env:SETUP_MYSQL_PASS }
    return ''
}

function Write-ClientCnf([string]$Path, [string]$Pass) {
    $directory = Split-Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $content = @(
        '[client]'
        'user=root'
        "password=$Pass"
        'host=127.0.0.1'
        'port=3306'
        'protocol=tcp'
    )
    [System.IO.File]::WriteAllLines($Path, $content, [System.Text.Encoding]::ASCII)
}

function Invoke-MysqlQuery([string]$Exe, [string]$Cnf, [string]$Query) {
    & $Exe "--defaults-extra-file=$Cnf" '--connect-expired-password' '-e' $Query
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Get-AppUserSql {
    $escapedPassword = $DatabasePassword.Replace("'", "''")
    return @"
CREATE DATABASE IF NOT EXISTS ``auth`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``characters`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``world`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``hotfixes`` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DatabaseUser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$escapedPassword';
ALTER USER '$DatabaseUser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$escapedPassword';
CREATE USER IF NOT EXISTS '$DatabaseUser'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$escapedPassword';
ALTER USER '$DatabaseUser'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$escapedPassword';
GRANT ALL PRIVILEGES ON ``auth``.* TO '$DatabaseUser'@'localhost';
GRANT ALL PRIVILEGES ON ``characters``.* TO '$DatabaseUser'@'localhost';
GRANT ALL PRIVILEGES ON ``world``.* TO '$DatabaseUser'@'localhost';
GRANT ALL PRIVILEGES ON ``hotfixes``.* TO '$DatabaseUser'@'localhost';
GRANT ALL PRIVILEGES ON ``auth``.* TO '$DatabaseUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``characters``.* TO '$DatabaseUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``world``.* TO '$DatabaseUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``hotfixes``.* TO '$DatabaseUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
}

switch ($Action) {
    'WriteCnf' {
        Write-ClientCnf -Path $CnfPath -Pass $Password
    }
    'Test' {
        $exe = Get-MysqlExe
        & $exe "--defaults-extra-file=$CnfPath" '--connect-expired-password' '-e' 'SELECT 1;'
        exit $LASTEXITCODE
    }
    'EnsureAppUser' {
        $exe = Get-MysqlExe
        Invoke-MysqlQuery -Exe $exe -Cnf $CnfPath -Query (Get-AppUserSql)
    }
    'CompatFix' {
        $exe = Get-MysqlExe
        $pass = Get-PasswordFromCnf $CnfPath
        if (-not $pass) { exit 0 }
        $escaped = $pass -replace "'", "''"
        $query = @"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$escaped';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '$escaped';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '$escaped';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"@
        Invoke-MysqlQuery -Exe $exe -Cnf $CnfPath -Query $query
    }
    'Tune' {
        $exe = Get-MysqlExe
        $query = 'SET GLOBAL innodb_buffer_pool_size = 536870912; SET GLOBAL tmp_table_size = 134217728; SET GLOBAL max_heap_table_size = 134217728; SET GLOBAL innodb_flush_log_at_trx_commit = 2;'
        Invoke-MysqlQuery -Exe $exe -Cnf $CnfPath -Query $query
    }
    'PatchConf' {
        if (-not (Test-Path -LiteralPath $ConfPath)) { throw "Config not found: $ConfPath" }
        if (-not $DatabaseUser -or -not $DatabasePassword) { throw 'Database credentials are required.' }
        $dbMap = @{
            LoginDatabaseInfo     = 'auth'
            WorldDatabaseInfo     = 'world'
            CharacterDatabaseInfo = 'characters'
            HotfixDatabaseInfo    = 'hotfixes'
        }
        $keyList = @($ConfKeys)
        if ($keyList.Count -eq 1 -and $keyList[0].Contains(',')) {
            $keyList = $keyList[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        $lines = Get-Content -LiteralPath $ConfPath
        $output = foreach ($line in $lines) {
            $updated = $line
            foreach ($key in $keyList) {
                if ($line -match "^($([regex]::Escape($key))\s*=)") {
                    $updated = ('{0} "127.0.0.1;3306;{1};{2};{3}"' -f $Matches[1], $DatabaseUser, $DatabasePassword, $dbMap[$key])
                    break
                }
            }
            if ($line -match '^DataDir\s*=') { $updated = 'DataDir = "./data"' }
            $updated
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllLines($ConfPath, $output, $utf8NoBom)
    }
    default { throw "Unknown action: $Action" }
}
