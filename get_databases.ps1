[CmdletBinding()]
param(
    [string]$TargetDir = '',
    [string]$CacheDir = '',
    [string]$DatabaseUrl = '',
    [string]$ArchivePath = '',
    [string]$UnrarPath = ''
)

# LEGIONFORGE 7.3.5 - получить чистые базы Ashamane (world + hotfixes).
#
# Источник: официальный релиз AshamaneCore ADB_735.10 "Final before BfA":
# https://github.com/AshamaneProject/AshamaneCore/releases/tag/ADB_735.10
# Официальный RAR: 87,997,425 байт; SHA-256 закреплён и проверяется перед распаковкой.
# RAR содержит 366,619,372 байт world + 126,317,838 байт hotfix SQL.
#
# Выходные имена, ожидаемые LEGIONFORGE: sql\base\ADB_world.sql и ADB_hotfixes.sql.
# В отличие от пользовательских world.sql/hotfixes.sql, скрипт скачивает чистый ADB,
# только если setup обнаружил пустую БД world или hotfixes.
#
# ВАЖНО: релиз опубликован Ashamane как ADB_735.10 Final before BfA (core release line 7.3.5.26972).
# Это более поздний upstream-снимок, чем клиент build 26124; см. docs\ADB_DATABASES.md.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lf_common.ps1')

$Root = $PSScriptRoot
if (-not $TargetDir) { $TargetDir = Join-Path $Root 'sql\base' }
if (-not $CacheDir) { $CacheDir = Join-Path $Root 'setup_tmp' }
$WorldSql = Join-Path $TargetDir 'ADB_world.sql'
$HotfixSql = Join-Path $TargetDir 'ADB_hotfixes.sql'
$OfficialUrl = 'https://github.com/AshamaneProject/AshamaneCore/releases/download/ADB_735.10/ADB_735.10.rar'
$OfficialSha256 = 'e3f0f90db8940f3a1201188fafdf740b8734e2d3e893e1cebbd14c2b9917154a'
# Verified official RARLAB Windows x64 UnRAR binary (https://www.rarlab.com/rar/unrarw64.exe).
# 7-Zip can list ADB_735.10.rar but cannot decode its RAR v6 m3 compression method.
$UnrarUrl = 'https://www.rarlab.com/rar/unrarw64.exe'
$UnrarSha256 = 'fecc0aa6d3f5434113bc32d4d151c2e9e0938155f71c356ed150bcecf3770f21'

function Test-MySqlDump([string]$Path, [long]$MinimumBytes) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -lt $MinimumBytes) { return $false }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $buffer = New-Object byte[] 256
        $count = $stream.Read($buffer, 0, $buffer.Length)
        if ($count -le 0) { return $false }
        $header = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
        return ($header -match '(?i)MySQL dump|MariaDB dump')
    }
    catch { return $false }
    finally { if ($stream) { $stream.Dispose() } }
}

function Test-Dumps {
    return (Test-MySqlDump $WorldSql 100MB) -and (Test-MySqlDump $HotfixSql 30MB)
}

function Move-IfValid([string]$Source, [string]$Destination, [long]$MinimumBytes) {
    if ((Test-MySqlDump $Destination $MinimumBytes) -or -not (Test-MySqlDump $Source $MinimumBytes)) { return }
    if ([System.IO.Path]::GetFullPath($Source) -ieq [System.IO.Path]::GetFullPath($Destination)) { return }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-LfOk ("Переименован/скопирован локальный дамп: {0} -> {1}" -f (Split-Path -Leaf $Source), (Split-Path -Leaf $Destination))
}

function Normalize-ExistingDumps {
    # Совместимость с именами оригинального скрипта и предварительно скачанными ADB-файлами.
    $worldSources = @(
        (Join-Path $TargetDir 'ADB_735.10_world.sql'),
        (Join-Path $CacheDir 'ADB_world.sql'),
        (Join-Path $CacheDir 'ADB_735.10_world.sql')
    )
    $hotfixSources = @(
        (Join-Path $TargetDir 'ADB_735.10_hotfix.sql'),
        (Join-Path $TargetDir 'ADB_735.10_hotfixes.sql'),
        (Join-Path $CacheDir 'ADB_hotfixes.sql'),
        (Join-Path $CacheDir 'ADB_735.10_hotfix.sql'),
        (Join-Path $CacheDir 'ADB_735.10_hotfixes.sql')
    )
    foreach ($path in $worldSources) { Move-IfValid $path $WorldSql 100MB }
    foreach ($path in $hotfixSources) { Move-IfValid $path $HotfixSql 30MB }
}

function Find-DumpFile([string]$Directory, [string[]]$Names) {
    foreach ($name in $Names) {
        $file = Get-ChildItem -LiteralPath $Directory -Filter $name -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($file) { return $file.FullName }
    }
    return $null
}

function Get-Unrar {
    if ($UnrarPath -and (Test-Path -LiteralPath $UnrarPath -PathType Leaf)) { return $UnrarPath }
    if ($env:LEGIONFORGE_UNRAR -and (Test-Path -LiteralPath $env:LEGIONFORGE_UNRAR -PathType Leaf)) {
        return $env:LEGIONFORGE_UNRAR
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $localDir = Join-Path $Root 'tools\unrar'
    foreach ($name in @('UnRAR.exe', 'unrar.exe', 'unrarw64.exe', 'Rar.exe', 'WinRAR.exe')) {
        $candidates.Add((Join-Path $localDir $name))
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
        if (-not $base) { continue }
        foreach ($name in @('UnRAR.exe', 'Rar.exe', 'WinRAR.exe')) {
            $candidates.Add((Join-Path (Join-Path $base 'WinRAR') $name))
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Write-LfOk ("Используется RAR-совместимый распаковщик: {0}" -f $candidate)
            return $candidate
        }
    }

    $exe = Join-Path $localDir 'UnRAR.exe'
    Write-LfStep 'Загрузка официального RARLAB UnRAR (7-Zip не поддерживает метод сжатия ADB_735.10)...'
    Invoke-LfDownload -Urls @($UnrarUrl) -Destination $exe -Sha256 $UnrarSha256 -MinBytes 500KB
    return $exe
}

function Expand-RarArchive([string]$Archive, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $unrar = Get-Unrar
    $destinationWithSeparator = $Destination.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
    Write-LfStep ("Распаковка официального ADB-архива через {0}..." -f (Split-Path -Leaf $unrar))
    $code = Invoke-LfNative -FilePath $unrar -Arguments @('x', '-y', '-o+', '-inul', $Archive, $destinationWithSeparator)
    if ($code -gt 1) { throw "UnRAR не смог распаковать $Archive (код $code). Проверьте архив и server/logs/get_databases.log." }
}

function Expand-ZipArchive([string]$Archive, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Expand-LfArchive -Archive $Archive -Destination $Destination
}

function Get-ArchiveFormat([string]$Path) {
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $header = New-Object byte[] 8
        $count = $stream.Read($header, 0, $header.Length)
        if ($count -ge 7 -and $header[0] -eq 0x52 -and $header[1] -eq 0x61 -and $header[2] -eq 0x72 -and $header[3] -eq 0x21) { return 'rar' }
        if ($count -ge 4 -and $header[0] -eq 0x50 -and $header[1] -eq 0x4B -and
            (($header[2] -eq 0x03 -and $header[3] -eq 0x04) -or ($header[2] -eq 0x05 -and $header[3] -eq 0x06) -or ($header[2] -eq 0x07 -and $header[3] -eq 0x08))) { return 'zip' }
        return 'unknown'
    }
    finally { if ($stream) { $stream.Dispose() } }
}

function Import-ExtractedDumps([string]$ExtractDir) {
    $world = Find-DumpFile $ExtractDir @('ADB_world.sql', 'ADB_735.10_world.sql')
    $hotfix = Find-DumpFile $ExtractDir @('ADB_hotfixes.sql', 'ADB_735.10_hotfix.sql', 'ADB_735.10_hotfixes.sql')
    if (-not $world) { throw 'В архиве не найден ADB_735.10_world.sql или ADB_world.sql.' }
    if (-not $hotfix) { throw 'В архиве не найден ADB_735.10_hotfix.sql или ADB_hotfixes.sql.' }
    if (-not (Test-MySqlDump $world 100MB)) { throw "World SQL отсутствует, слишком мал или не является MySQL dump: $world" }
    if (-not (Test-MySqlDump $hotfix 30MB)) { throw "Hotfix SQL отсутствует, слишком мал или не является MySQL dump: $hotfix" }

    Copy-Item -LiteralPath $world -Destination $WorldSql -Force
    Copy-Item -LiteralPath $hotfix -Destination $HotfixSql -Force
}

$exitCode = 0
try {
    Open-LfLog (Join-Path $Root 'logs\get_databases.log')
    New-Item -ItemType Directory -Force -Path $TargetDir, $CacheDir | Out-Null
    Normalize-ExistingDumps

    if (Test-Dumps) {
        Write-LfOk ("Чистые базы ADB уже готовы: ADB_world.sql ({0}) и ADB_hotfixes.sql ({1})." -f
            (Format-LfSize (Get-Item -LiteralPath $WorldSql).Length), (Format-LfSize (Get-Item -LiteralPath $HotfixSql).Length))
        exit 0
    }

    $free = Get-LfFreeSpaceGB $TargetDir
    if ($free -ge 0 -and $free -lt 2) { throw "Для архива и распаковки ADB нужно не менее 2 ГБ свободного места, доступно $free ГБ." }

    $localArchive = $ArchivePath
    if (-not $localArchive) {
        foreach ($candidate in @(
            (Join-Path $CacheDir 'ADB_735.10.rar'),
            (Join-Path $Root 'ADB_735.10.rar'),
            (Join-Path $TargetDir 'ADB_735.10.rar'),
            (Join-Path $CacheDir 'databases.zip'),
            (Join-Path $Root 'databases.zip'),
            (Join-Path $TargetDir 'databases.zip')
        )) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $localArchive = $candidate; break }
        }
    }

    $extract = Join-Path $CacheDir 'adb_extract'
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $extract | Out-Null

    if ($localArchive) {
        if (-not (Test-Path -LiteralPath $localArchive -PathType Leaf)) { throw "Архив не найден: $localArchive" }
        $format = Get-ArchiveFormat $localArchive
        Write-LfOk ("Используется локальный ADB-архив ({0}): {1}" -f $format, $localArchive)
        if ($format -eq 'rar') {
            $localHash = Get-LfSha256 $localArchive
            if ($localHash -ne $OfficialSha256 -and $env:LEGIONFORGE_SKIP_HASH -ne '1') {
                throw "SHA-256 локального RAR не совпадает. Ожидался $OfficialSha256, получен $localHash. Для собственного проверенного архива можно задать LEGIONFORGE_SKIP_HASH=1."
            }
            Expand-RarArchive $localArchive $extract
        }
        elseif ($format -eq 'zip') { Expand-ZipArchive $localArchive $extract }
        else { throw "Неизвестный формат локального архива: $localArchive" }
    }
    elseif ($DatabaseUrl) {
        $customArchive = Join-Path $CacheDir 'legionforge_databases.download'
        Invoke-LfDownload -Urls @($DatabaseUrl) -Destination $customArchive -MinBytes 10MB
        $format = Get-ArchiveFormat $customArchive
        if ($format -eq 'rar') { Expand-RarArchive $customArchive $extract }
        elseif ($format -eq 'zip') { Expand-ZipArchive $customArchive $extract }
        else { throw "Неизвестный формат загруженного архива: $customArchive" }
    }
    else {
        $archive = Join-Path $CacheDir 'ADB_735.10.rar'
        Write-LfStep 'Загрузка чистого ADB_735.10 от AshamaneCore (архив около 84 МБ)...'
        Invoke-LfDownload -Urls @($OfficialUrl) -Destination $archive -Sha256 $OfficialSha256 -MinBytes 50MB
        Expand-RarArchive $archive $extract
    }

    Import-ExtractedDumps $extract
    if (-not (Test-Dumps)) { throw 'После распаковки ADB_world.sql / ADB_hotfixes.sql не прошли проверку.' }
    Write-LfOk ("Готовы чистые дампы: ADB_world.sql ({0}), ADB_hotfixes.sql ({1})." -f
        (Format-LfSize (Get-Item -LiteralPath $WorldSql).Length), (Format-LfSize (Get-Item -LiteralPath $HotfixSql).Length))
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
}
catch {
    $exitCode = 1
    Write-LfErr $_.Exception.Message
}
finally { Close-LfLog }
exit $exitCode
