# LEGIONFORGE 7.3.5 - подготовка дистрибутива из УЖЕ РАБОТАЮЩЕЙ установки.
# Файл хранится в UTF-8 с BOM.
#
# Зачем нужен: чтобы перенести готовый сервер на другой ПК или раздать друзьям
# без многочасовой компиляции. setup.bat на другом ПК подхватит эти архивы из
# setup_tmp\ (или корня проекта) и пропустит компиляцию/загрузку.
#
#   release\server_binaries.zip  - скомпилированные .exe/.dll + *.conf.dist + сертификаты
#   release\databases.zip        - дампы world/hotfixes (mysqldump), имена как ждёт setup.bat
#   release\legionforge_source.zip - ТОЛЬКО с ключом -Source: исходники без tools\, build\, данных и секретов
#
# Ключи: -Source (архив исходников), -Full (дополнительно auth и characters), -WithPdb (отладочные символы)
[CmdletBinding()]
param(
    [switch]$Source,
    [switch]$Full,
    [switch]$WithPdb
)

. (Join-Path $PSScriptRoot 'lf_common.ps1')

$Root = $PSScriptRoot
$ServerDir = Join-Path $Root 'server'
$ReleaseDir = Join-Path $Root 'release'
$Cnf = Join-Path $Root 'setup_tmp\mysql.cnf'
$Results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$File, [string]$Status, [string]$Detail) {
    $Results.Add([pscustomobject]@{ File = $File; Status = $Status; Detail = $Detail })
}

function Invoke-Binaries {
    $zip = Join-Path $ReleaseDir 'server_binaries.zip'
    if (-not (Test-Path -LiteralPath (Join-Path $ServerDir 'worldserver.exe'))) {
        Write-LfWarn 'worldserver.exe ещё нет - сервер не скомпилирован. Сначала запустите build_server.bat (или setup.bat).'
        Add-Result 'release\server_binaries.zip' 'ПРОПУЩЕН' 'сервер ещё не скомпилирован - запустите build_server.bat'
        return
    }
    Write-LfStep 'Упаковка скомпилированных программ (без карт data\ и без личных *.conf)...'
    $patterns = @('*.exe', '*.dll', '*.conf.dist', '*.pem', 'build_info.txt', 'build_sources.json')
    if ($WithPdb) { $patterns += '*.pdb' }
    $items = @()
    foreach ($pattern in $patterns) {
        $items += @(Get-ChildItem -LiteralPath $ServerDir -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    $items = @($items | Where-Object { $_ -notlike '*.conf' } | Sort-Object -Unique)
    try {
        New-LfZip -ZipPath $zip -Items $items -WorkDir $ServerDir
        Add-Result 'release\server_binaries.zip' 'OK' (Format-LfSize (Get-Item -LiteralPath $zip).Length)
        Write-LfOk "Готово: release\server_binaries.zip ($($items.Count) файлов)"
    }
    catch {
        Add-Result 'release\server_binaries.zip' 'ОШИБКА' $_.Exception.Message
        Write-LfErr $_.Exception.Message
    }
}

function Invoke-Databases {
    $zip = Join-Path $ReleaseDir 'databases.zip'
    if (-not (Test-Path -LiteralPath $Cnf)) {
        Add-Result 'release\databases.zip' 'ПРОПУЩЕН' 'нет setup_tmp\mysql.cnf - сначала выполните setup.bat'
        Write-LfWarn 'Нет setup_tmp\mysql.cnf - базы ещё не установлены (сначала setup.bat).'
        return
    }
    $mysql = $null
    try {
        $ErrorActionPreference = 'Continue'
        $mysql = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'find_mysql.ps1') -Port 3306 -EnsureRunning 2>$null | Select-Object -First 1
        $ErrorActionPreference = 'Stop'
    }
    catch { $ErrorActionPreference = 'Stop' }
    if ($mysql) { $mysql = "$mysql".Trim() }
    if (-not $mysql -or -not (Test-Path -LiteralPath $mysql)) {
        Add-Result 'release\databases.zip' 'ОШИБКА' 'MySQL не запущен на порту 3306'
        Write-LfErr 'MySQL не найден/не запущен на порту 3306.'
        return
    }
    # Выгрузку делает mysqldump.exe (раньше ошибочно вызывался mysql.exe с ключами --routines/--events).
    $mysqldump = Join-Path (Split-Path -Parent $mysql) 'mysqldump.exe'
    if (-not (Test-Path -LiteralPath $mysqldump)) {
        Add-Result 'release\databases.zip' 'ОШИБКА' "не найден $mysqldump"
        Write-LfErr "Не найден mysqldump.exe рядом с $mysql"
        return
    }
    $versionText = ''
    try { $ErrorActionPreference = 'Continue'; $versionText = "$(& $mysqldump --version 2>&1)"; $ErrorActionPreference = 'Stop' } catch { $ErrorActionPreference = 'Stop' }
    $isMariaDb = $versionText -match 'MariaDB'

    $map = [ordered]@{ world = 'ADB_world.sql'; hotfixes = 'ADB_hotfixes.sql' }
    if ($Full) { $map['auth'] = 'auth.sql'; $map['characters'] = 'characters.sql' }
    $dumped = @()
    foreach ($db in $map.Keys) {
        $out = Join-Path $ReleaseDir $map[$db]
        Write-LfStep "Выгрузка базы $db -> $($map[$db]) (может занять несколько минут)..."
        $arguments = @("--defaults-extra-file=$Cnf", '--single-transaction', '--quick', '--routines', '--events', '--triggers',
            '--hex-blob', '--default-character-set=utf8mb4', '--max_allowed_packet=512M')
        if (-not $isMariaDb) { $arguments += @('--set-gtid-purged=OFF', '--column-statistics=0') }
        $arguments += @("--result-file=$out", $db)
        $code = Invoke-LfNative -FilePath $mysqldump -Arguments $arguments -Quiet
        $valid = ($code -eq 0) -and (Test-Path -LiteralPath $out) -and ((Get-Item -LiteralPath $out).Length -gt 1024)
        if ($valid) {
            $tail = Get-Content -LiteralPath $out -Tail 3 -ErrorAction SilentlyContinue
            $valid = [bool]($tail -match 'Dump completed')
        }
        if (-not $valid) {
            Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
            Add-Result 'release\databases.zip' 'ОШИБКА' "mysqldump не смог выгрузить базу $db (код $code), подробности в logs\prepare_release.log"
            Write-LfErr "Выгрузка базы $db не удалась (код $code)."
            foreach ($file in $dumped) { Remove-Item -LiteralPath (Join-Path $ReleaseDir $file) -Force -ErrorAction SilentlyContinue }
            return
        }
        Write-LfOk ("{0}: {1}" -f $map[$db], (Format-LfSize (Get-Item -LiteralPath $out).Length))
        $dumped += $map[$db]
    }
    try {
        Write-LfStep 'Сжатие дампов в release\databases.zip...'
        New-LfZip -ZipPath $zip -Items $dumped -WorkDir $ReleaseDir
        foreach ($file in $dumped) { Remove-Item -LiteralPath (Join-Path $ReleaseDir $file) -Force -ErrorAction SilentlyContinue }
        Add-Result 'release\databases.zip' 'OK' (Format-LfSize (Get-Item -LiteralPath $zip).Length)
        Write-LfOk 'Готово: release\databases.zip'
    }
    catch {
        Add-Result 'release\databases.zip' 'ОШИБКА' $_.Exception.Message
        Write-LfErr $_.Exception.Message
    }
}

function Invoke-SourceArchive {
    $zip = Join-Path $ReleaseDir 'legionforge_source.zip'
    Write-LfStep 'Упаковка исходного кода (без tools\, build\, release\, setup_tmp\, карт и секретов)...'
    $sevenZip = Get-LfSevenZip
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    $arguments = @('a', '-tzip', '-mx=5', '-y', '-bso0', '-bsp1', $zip, '*',
        '-xr!.git', '-x!build', '-x!release', '-x!arhiv', '-x!setup_tmp', '-x!logs', '-x!WoW_Client',
        '-x!tools\mysql', '-x!tools\downloads', '-x!tools\cmake', '-x!tools\vsbuildtools*', '-x!tools\boost_*',
        '-x!tools\openssl', '-x!tools\7zip', '-x!server\data', '-x!server\logs', '-x!server\*.exe', '-x!server\*.dll',
        '-x!server\*.pdb', '-x!server\*.conf', '-xr!mysql.cnf', '-xr!*.log', '-x!client_path.txt')
    Push-Location -LiteralPath $Root
    try { $code = Invoke-LfNative -FilePath $sevenZip -Arguments $arguments -Quiet }
    finally { Pop-Location }
    if ($code -le 1 -and (Test-Path -LiteralPath $zip)) {
        Add-Result 'release\legionforge_source.zip' 'OK' (Format-LfSize (Get-Item -LiteralPath $zip).Length)
        Write-LfOk 'Готово: release\legionforge_source.zip'
    }
    else {
        Add-Result 'release\legionforge_source.zip' 'ОШИБКА' "7-Zip завершился с кодом $code"
        Write-LfErr "Не удалось упаковать исходники (код $code)."
    }
}

$exitCode = 0
try {
    Open-LfLog (Join-Path $Root 'logs\prepare_release.log')
    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
    Invoke-Binaries
    Invoke-Databases
    if ($Source) { Invoke-SourceArchive }
}
catch {
    Write-LfErr $_.Exception.Message
    Add-Result '(общая ошибка)' 'ОШИБКА' $_.Exception.Message
}
finally {
    Write-Host ''
    Write-Host '  ================= ИТОГ (проверено по факту на диске) =================' -ForegroundColor White
    foreach ($r in $Results) {
        $color = 'Green'
        if ($r.Status -eq 'ПРОПУЩЕН') { $color = 'Yellow' }
        if ($r.Status -eq 'ОШИБКА') { $color = 'Red'; $exitCode = 1 }
        Write-Host ("  [{0}] {1} - {2}" -f $r.Status, $r.File, $r.Detail) -ForegroundColor $color
    }
    if (-not $Source) { Write-Host '  Архив исходников не создавался (нужен только для публикации кода: prepare_release.bat /source).' -ForegroundColor DarkGray }
    Close-LfLog
}
exit $exitCode
