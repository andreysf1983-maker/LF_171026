# LEGIONFORGE 7.3.5 - подготовка переносимого MySQL 8.0 и инструментов.
# Совместимо с Windows PowerShell 5.1 и PowerShell 7+.
# ВАЖНО: файл хранится в UTF-8 с BOM. Без BOM Windows PowerShell 5.1 читает
# скрипт в ANSI-кодировке (cp1251), и кириллические строки ломают разбор.
[CmdletBinding()]
param(
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Windows PowerShell 5.1 на старых сборках .NET по умолчанию использует TLS 1.0/1.1,
# а dev.mysql.com и aka.ms принимают только TLS 1.2+.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch { }

$RepoRoot = $PSScriptRoot
$ToolsRoot = Join-Path $RepoRoot 'tools'
$DownloadsDir = Join-Path $ToolsRoot 'downloads'
$MysqlRoot = Join-Path $ToolsRoot 'mysql'
$MysqlServerDir = Join-Path $MysqlRoot 'server'
$MysqlBinDir = Join-Path $MysqlServerDir 'bin'
$MysqlExe = Join-Path $MysqlBinDir 'mysql.exe'
$MysqldExe = Join-Path $MysqlBinDir 'mysqld.exe'
$DataDir = Join-Path $MysqlRoot 'data'
$LogsDir = Join-Path $MysqlRoot 'logs'
$MyIni = Join-Path $MysqlRoot 'my.ini'
$SetupTempDir = Join-Path $RepoRoot 'setup_tmp'
$RootCnf = Join-Path $SetupTempDir 'mysql.cnf'
$ReadyFlag = Join-Path $MysqlRoot 'legionforge-ready.flag'
$Version = '8.0.46'
$ArchiveName = "mysql-$Version-winx64.zip"
$ArchivePath = Join-Path $DownloadsDir $ArchiveName
$ExtractDir = Join-Path $DownloadsDir 'mysql-extract'
# Основной адрес + зеркала. Когда Oracle переносит версию в архив,
# первые два адреса перестают работать, а последние два начинают.
$MysqlUrls = @(
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/$ArchiveName"
    "https://cdn.mysql.com/Downloads/MySQL-8.0/$ArchiveName"
    "https://cdn.mysql.com/archives/mysql-8.0/$ArchiveName"
    "https://downloads.mysql.com/archives/get/p/23/file/$ArchiveName"
)
$ExpectedMd5 = '003f527d5df61b663ff191038cd676bd'
$ExpectedSize = 248009349
$VCRedistPath = Join-Path $DownloadsDir 'vc_redist.x64.exe'
$VCRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
$Port = 3306
$AppUser = 'admin@legionforge.ru'
$AppPassword = 'legionforge'

function Write-Step([string]$Message) {
    Write-Host "  [*] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function ConvertTo-MySqlPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
}

function Invoke-Native {
    # Запускает внешнюю программу и возвращает код выхода и объединённый вывод.
    # В Windows PowerShell 5.1 любое перенаправление stderr внешней программы
    # (2>$null, 2>&1, *>) при $ErrorActionPreference = 'Stop' превращает первую
    # строку stderr в завершающую ошибку. Поэтому на время вызова - 'Continue'.
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    $ErrorActionPreference = 'Continue'
    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { "$_" })
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = (($output | Where-Object { $_ }) -join ' ').Trim()
    }
}

function Invoke-NativeQuiet {
    # То же, что Invoke-Native, но возвращает только код выхода.
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    return (Invoke-Native -FilePath $FilePath -Arguments $Arguments).ExitCode
}

function Test-PortOpen([int]$ListenPort) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect('127.0.0.1', $ListenPort, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(700)) { return $false }
        $client.EndConnect($pending)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-ListenerProcess {
    try {
        $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $listener) { return $null }
        return Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)" -ErrorAction SilentlyContinue
    }
    catch {
        return $null
    }
}

function New-RandomPassword {
    $bytes = New-Object byte[] 36
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ([Convert]::ToBase64String($bytes).TrimEnd('=')).Replace('+', 'x').Replace('/', 'y')
}

function Get-RootPassword {
    if (Test-Path -LiteralPath $RootCnf) {
        $passwordLine = Get-Content -LiteralPath $RootCnf -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '^password=(.*)$' } |
            Select-Object -First 1
        if ($passwordLine -match '^password=(.*)$' -and $Matches[1]) { return $Matches[1] }
    }
    return New-RandomPassword
}

function Write-RootClientConfig([string]$Password) {
    New-Item -ItemType Directory -Force -Path $SetupTempDir | Out-Null
    $content = @(
        '[client]'
        'user=root'
        "password=$Password"
        'host=127.0.0.1'
        "port=$Port"
        'protocol=tcp'
    )
    [System.IO.File]::WriteAllLines($RootCnf, $content, [System.Text.Encoding]::ASCII)
    try {
        $null = Invoke-NativeQuiet -FilePath 'icacls.exe' -Arguments @($RootCnf, '/inheritance:r', '/grant:r', "$($env:USERDOMAIN)\$($env:USERNAME):(F)")
    }
    catch { }
}

function Invoke-Download([string]$Url, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
    $curl = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($curl) {
        # Прогресс curl выводит в stderr - во время загрузки не даём 'Stop' его перехватить.
        $ErrorActionPreference = 'Continue'
        & $curl.Source '--fail' '--location' '--retry' '3' '--retry-delay' '2' '--connect-timeout' '30' '--output' $Destination $Url
        $curlCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($curlCode -ne 0) {
            Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            # ${curlCode} в фигурных скобках: иначе PowerShell принимает "$curlCode:" за ссылку на диск.
            throw "Загрузка завершилась с кодом ${curlCode}: $Url"
        }
    }
    else {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
    if (-not (Test-Path -LiteralPath $Destination)) { throw "Файл не появился после загрузки: $Destination" }
}

function Get-FileFromMirrors([string[]]$Urls, [string]$Destination) {
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($url in $Urls) {
        try {
            Write-Step "Источник: $url"
            Invoke-Download -Url $url -Destination $Destination
            return
        }
        catch {
            $failures.Add($_.Exception.Message)
            Write-Warn $_.Exception.Message
        }
    }
    throw ("Не удалось скачать файл ни с одного адреса. Проверьте интернет или положите $ArchiveName в tools\downloads вручную. " + ($failures -join ' | '))
}

function Get-Md5([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant()
}

function Expand-ZipFast([string]$ZipPath, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    try {
        # System.IO.Compression в разы быстрее Expand-Archive из Windows PowerShell 5.1.
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
    }
    catch {
        Write-Warn "Быстрая распаковка недоступна ($($_.Exception.Message)); используется Expand-Archive."
        Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
    }
}

function Ensure-VCRuntime {
    $runtimeDll = Join-Path $env:WINDIR 'System32\vcruntime140.dll'
    $cppDll = Join-Path $env:WINDIR 'System32\msvcp140.dll'
    if ((Test-Path -LiteralPath $runtimeDll) -and (Test-Path -LiteralPath $cppDll)) {
        Write-Ok 'Microsoft Visual C++ x64 runtime уже установлен.'
        return
    }

    Write-Step 'Скачивание и установка официального Microsoft Visual C++ Runtime...'
    if (-not (Test-Path -LiteralPath $VCRedistPath)) {
        Invoke-Download -Url $VCRedistUrl -Destination $VCRedistPath
    }
    $installer = Start-Process -FilePath $VCRedistPath -ArgumentList '/install /quiet /norestart' -Wait -PassThru
    if ($installer.ExitCode -notin @(0, 1638, 3010)) {
        throw "Установка VC++ Runtime завершилась с кодом $($installer.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $runtimeDll)) {
        throw 'VC++ Runtime не найден после установки. Перезагрузите Windows и повторите запуск.'
    }
    Write-Ok 'Microsoft Visual C++ Runtime готов.'
}

function Get-MysqlArchive {
    # Уже скачанный (или положенный вручную) архив используется, если MD5 совпадает.
    if (Test-Path -LiteralPath $ArchivePath) {
        if ((Get-Md5 $ArchivePath) -eq $ExpectedMd5) {
            Write-Ok "Найден ранее скачанный архив: $ArchivePath"
            return
        }
        Write-Warn 'Найден неполный или повреждённый архив MySQL - он будет скачан заново.'
        Remove-Item -LiteralPath $ArchivePath -Force
    }

    Write-Step "Загрузка официального MySQL Community Server $Version (ZIP, около 237 МБ)..."
    Get-FileFromMirrors -Urls $MysqlUrls -Destination $ArchivePath
    $actualSize = (Get-Item -LiteralPath $ArchivePath).Length
    $actualMd5 = Get-Md5 $ArchivePath
    if ($actualMd5 -ne $ExpectedMd5) {
        Remove-Item -LiteralPath $ArchivePath -Force -ErrorAction SilentlyContinue
        throw "Контрольная сумма MySQL ZIP не совпала (ожидалась $ExpectedMd5, получена $actualMd5; размер $actualSize из $ExpectedSize байт). Архив удалён, повторите запуск."
    }
    Write-Ok 'Контрольная сумма официального архива совпала.'
}

function Write-MyIni {
    $basedir = ConvertTo-MySqlPath $MysqlServerDir
    $datadir = ConvertTo-MySqlPath $DataDir
    $logfile = ConvertTo-MySqlPath (Join-Path $LogsDir 'mysql-error.log')
    $content = @(
        '[mysqld]'
        "basedir=$basedir"
        "datadir=$datadir"
        "port=$Port"
        'bind-address=127.0.0.1'
        'mysqlx=0'
        'max_allowed_packet=512M'
        'max_connections=100'
        'innodb_buffer_pool_size=512M'
        'tmp_table_size=128M'
        'max_heap_table_size=128M'
        'innodb_flush_log_at_trx_commit=2'
        'character-set-server=utf8mb4'
        "log-error=$logfile"
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($MyIni, $content, $utf8NoBom)
}

function Initialize-MysqlDataDir {
    # Каталог data без системной схемы mysql - след прерванной инициализации.
    # mysqld --initialize откажется работать с непустым каталогом, поэтому
    # такой каталог не удаляется, а переименовывается в data.broken-<время>.
    if (Test-Path -LiteralPath $DataDir) {
        $leftovers = @(Get-ChildItem -LiteralPath $DataDir -Force -ErrorAction SilentlyContinue)
        if ($leftovers.Count -gt 0) {
            $backup = "$DataDir.broken-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-Warn "Каталог данных после прерванной инициализации перемещён в $backup"
            Move-Item -LiteralPath $DataDir -Destination $backup
        }
    }
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

    $initOut = Join-Path $LogsDir 'mysql-initialize.log'
    $initErr = Join-Path $LogsDir 'mysql-initialize.err.log'
    # Start-Process вместо "& mysqld ... *> log": mysqld пишет журнал в stderr,
    # а в Windows PowerShell 5.1 это прерывало скрипт на первой же строке.
    $arguments = "--defaults-file=`"$MyIni`" --initialize-insecure --console"
    $process = Start-Process -FilePath $MysqldExe -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru `
        -RedirectStandardOutput $initOut -RedirectStandardError $initErr
    if ($process.ExitCode -ne 0) {
        $details = @(Get-Content -LiteralPath $initErr -Tail 30 -ErrorAction SilentlyContinue) +
            @(Get-Content -LiteralPath $initOut -Tail 10 -ErrorAction SilentlyContinue)
        throw "Инициализация MySQL завершилась с кодом $($process.ExitCode). $($details -join ' ')"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $DataDir 'mysql'))) {
        throw "mysqld --initialize-insecure завершился без ошибки, но системная схема не создана. Смотрите $initErr"
    }
}

function Get-BootstrapSql([string]$RootPassword) {
    $escapedRoot = $RootPassword.Replace("'", "''")
    return @"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$escapedRoot';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '$escapedRoot';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '$escapedRoot';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
$(Get-AppProvisioningSql)
"@
}

function Get-AppProvisioningSql {
    return @"
CREATE DATABASE IF NOT EXISTS ``auth`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``characters`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``world`` CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS ``hotfixes`` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$AppUser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$AppPassword';
ALTER USER '$AppUser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$AppPassword';
CREATE USER IF NOT EXISTS '$AppUser'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$AppPassword';
ALTER USER '$AppUser'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$AppPassword';
GRANT ALL PRIVILEGES ON ``auth``.* TO '$AppUser'@'localhost';
GRANT ALL PRIVILEGES ON ``characters``.* TO '$AppUser'@'localhost';
GRANT ALL PRIVILEGES ON ``world``.* TO '$AppUser'@'localhost';
GRANT ALL PRIVILEGES ON ``hotfixes``.* TO '$AppUser'@'localhost';
GRANT ALL PRIVILEGES ON ``auth``.* TO '$AppUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``characters``.* TO '$AppUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``world``.* TO '$AppUser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``hotfixes``.* TO '$AppUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
}

function Write-MySqlClientConfig([string]$Path, [string]$User, [string]$Password) {
    $content = @(
        '[client]'
        "user=$User"
        "password=$Password"
        'host=127.0.0.1'
        "port=$Port"
        'protocol=tcp'
    )
    [System.IO.File]::WriteAllLines($Path, $content, [System.Text.Encoding]::ASCII)
}

function Start-PortableServer([string]$InitFile) {
    $stdout = Join-Path $LogsDir 'mysqld-stdout.log'
    $stderr = Join-Path $LogsDir 'mysqld-stderr.log'
    $arguments = "--defaults-file=`"$MyIni`" --console"
    if ($InitFile) { $arguments += " --init-file=`"$InitFile`"" }
    return Start-Process -FilePath $MysqldExe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
}

function Wait-ForMysql([System.Diagnostics.Process]$Process) {
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if (Test-PortOpen $Port) { return }
        if ($Process -and $Process.HasExited) {
            $tail = Get-Content -LiteralPath (Join-Path $LogsDir 'mysqld-stderr.log') -Tail 30 -ErrorAction SilentlyContinue
            throw "mysqld.exe завершился с кодом $($Process.ExitCode). $($tail -join ' ')"
        }
        Start-Sleep -Seconds 1
    }
    $tail = Get-Content -LiteralPath (Join-Path $LogsDir 'mysql-error.log') -Tail 30 -ErrorAction SilentlyContinue
    throw "MySQL не открыл порт $Port за 120 секунд. $($tail -join ' ')"
}

function Wait-ForRootAuth([System.Diagnostics.Process]$Process) {
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $connectCode = Invoke-NativeQuiet -FilePath $MysqlExe -Arguments @("--defaults-extra-file=$RootCnf", '--connect-timeout=5', '-Nse', 'SELECT 1')
        if ($connectCode -eq 0) { return }
        if ($Process -and $Process.HasExited) {
            throw "mysqld.exe остановился до настройки root (код $($Process.ExitCode))."
        }
        Start-Sleep -Seconds 2
    }
    throw 'MySQL не принял root-подключение после выполнения bootstrap SQL. Проверьте tools/mysql/logs/mysql-error.log.'
}

try {
    Write-Host ''
    Write-Host '  LEGIONFORGE - подготовка локальных инструментов' -ForegroundColor White
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Требуется Windows x64.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Запустите upload_tools.bat от имени администратора.'
    }

    New-Item -ItemType Directory -Force -Path $DownloadsDir, $MysqlRoot, $LogsDir | Out-Null
    $listener = Get-ListenerProcess
    if ($listener) {
        $listenerPath = [string]$listener.ExecutablePath
        $expectedPath = [System.IO.Path]::GetFullPath($MysqldExe)
        if (-not $listenerPath -or -not [string]::Equals([System.IO.Path]::GetFullPath($listenerPath), $expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Порт $Port уже занят другим процессом ($listenerPath). Остановите MySQL на этом порту или настройте существующий сервер, затем повторите запуск."
        }
    }

    if (-not (Test-Path -LiteralPath $MysqlExe)) {
        Ensure-VCRuntime
        Get-MysqlArchive

        Write-Step 'Распаковка MySQL в tools/mysql/server...'
        Expand-ZipFast -ZipPath $ArchivePath -Destination $ExtractDir
        $packageDir = Join-Path $ExtractDir "mysql-$Version-winx64"
        if (-not (Test-Path -LiteralPath (Join-Path $packageDir 'bin\mysqld.exe'))) {
            throw 'В ZIP не найдена ожидаемая папка MySQL с bin\mysqld.exe.'
        }
        if (Test-Path -LiteralPath $MysqlServerDir) { Remove-Item -LiteralPath $MysqlServerDir -Recurse -Force }
        Move-Item -LiteralPath $packageDir -Destination $MysqlServerDir
        Remove-Item -LiteralPath $ArchivePath, $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok 'Портативные бинарные файлы MySQL распакованы.'
    }
    else {
        Write-Ok "MySQL уже подготовлен: $MysqlExe"
    }

    if (-not (Test-Path -LiteralPath $MysqldExe)) { throw "Не найден сервер MySQL: $MysqldExe" }
    if (-not (Test-Path -LiteralPath $MyIni)) { Write-MyIni }
    New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

    $rootPassword = Get-RootPassword
    Write-RootClientConfig $rootPassword
    $needsBootstrap = -not (Test-Path -LiteralPath $ReadyFlag)
    $listener = Get-ListenerProcess
    $serverProcess = $null

    if (-not (Test-Path -LiteralPath (Join-Path $DataDir 'mysql'))) {
        if ($listener) {
            Write-Step 'Остановка экземпляра MySQL без инициализированной базы...'
            Stop-Process -Id $listener.ProcessId -Force
            for ($i = 0; $i -lt 20 -and (Test-PortOpen $Port); $i++) { Start-Sleep -Seconds 1 }
            $listener = $null
        }
        Write-Step 'Инициализация пустой переносимой базы данных...'
        Initialize-MysqlDataDir
        $needsBootstrap = $true
    }

    if ($listener -and $needsBootstrap) {
        Write-Step 'Перезапуск незавершённого локального экземпляра MySQL для безопасной настройки паролей...'
        Stop-Process -Id $listener.ProcessId -Force
        for ($i = 0; $i -lt 20 -and (Test-PortOpen $Port); $i++) { Start-Sleep -Seconds 1 }
        $listener = $null
    }

    if (-not (Test-PortOpen $Port)) {
        $bootstrapSql = $null
        if ($needsBootstrap) {
            $bootstrapSql = Join-Path $SetupTempDir 'mysql-init.sql'
            $sql = Get-BootstrapSql $rootPassword
            [System.IO.File]::WriteAllText($bootstrapSql, $sql, [System.Text.Encoding]::ASCII)
        }
        Write-Step "Запуск MySQL на 127.0.0.1:$Port..."
        $serverProcess = Start-PortableServer $bootstrapSql
        try {
            Wait-ForMysql $serverProcess
            if ($needsBootstrap) { Wait-ForRootAuth $serverProcess }
        }
        finally {
            # Файл с паролем root удаляется в любом случае, даже при ошибке запуска.
            if ($bootstrapSql -and (Test-Path -LiteralPath $bootstrapSql)) {
                Remove-Item -LiteralPath $bootstrapSql -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        Write-Ok 'Порт MySQL уже открыт.'
    }

    if ($needsBootstrap) {
        $provisioningSql = Get-BootstrapSql $rootPassword
    }
    else {
        $provisioningSql = Get-AppProvisioningSql
    }
    $provision = Invoke-Native -FilePath $MysqlExe -Arguments @("--defaults-extra-file=$RootCnf", '--connect-timeout=10', '-e', $provisioningSql)
    if ($provision.ExitCode -ne 0) {
        if ($needsBootstrap) {
            throw "Не удалось применить первичную настройку MySQL: $($provision.Output) Проверьте журнал tools/mysql/logs/mysql-error.log."
        }
        throw "Не удалось создать базы или пользователя приложения в MySQL: $($provision.Output)"
    }

    if ((Invoke-NativeQuiet -FilePath $MysqlExe -Arguments @("--defaults-extra-file=$RootCnf", '--connect-timeout=10', '-Nse', 'SELECT 1')) -ne 0) {
        throw 'Проверка root-подключения к MySQL не пройдена.'
    }

    $appCnf = Join-Path $SetupTempDir 'mysql-app-check.cnf'
    Write-MySqlClientConfig -Path $appCnf -User $AppUser -Password $AppPassword
    try {
        if ((Invoke-NativeQuiet -FilePath $MysqlExe -Arguments @("--defaults-extra-file=$appCnf", '--connect-timeout=10', '-Nse', 'SELECT 1')) -ne 0) {
            throw "Проверка учётной записи $AppUser не пройдена."
        }
    }
    finally {
        Remove-Item -LiteralPath $appCnf -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $ReadyFlag)) {
        [System.IO.File]::WriteAllText($ReadyFlag, "MySQL $Version ready`r`n", [System.Text.Encoding]::ASCII)
    }
    Write-Ok "MySQL $Version работает локально на порту $Port."
    Write-Ok "Пользователь БД: $AppUser / $AppPassword (доступ только к базам LEGIONFORGE)."
    Write-Host '  [OK] Все проверки пройдены. Теперь запустите setup.bat.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "  [!] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '      Журнал MySQL: tools\mysql\logs\mysql-error.log' -ForegroundColor Yellow
    exit 1
}
