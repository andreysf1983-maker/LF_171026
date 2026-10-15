# LEGIONFORGE 7.3.5 - проверка библиотек (DLL), без которых worldserver.exe и bnetserver.exe не запускаются.
#
# ЗАЧЕМ. Сборка создаёт exe, но они зависят от DLL: libmysql.dll, OpenSSL (libssl/libcrypto), при динамической
# линковке - Boost, а также среда выполнения Visual C++ (vcruntime140.dll, msvcp140.dll). На ПК без Visual Studio
# этих DLL нет, и процесс завершается сразу. Окно в play.bat свёрнуто, поэтому ошибка не видна.
#
# ЧТО ДЕЛАЕТ. Читает таблицу импорта PE-файлов (без внешних утилит), рекурсивно обходит зависимости
# worldserver.exe / bnetserver.exe. Недостающие DLL ищет в tools\ и в установке Visual Studio / Build Tools,
# копирует в server\. Если что-то не найдено - выводит список и возвращает код 1.
# Отчёт пишется в server\runtime_check.txt (UTF-8).
#
# Параметры: -Root (папка проекта), -ServerDir (по умолчанию Root\server), -CheckOnly (только проверка, без копирования).
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ServerDir = '',
    [string]$SystemDir = '',
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
if (-not $SystemDir -and $env:SystemRoot) { $SystemDir = Join-Path $env:SystemRoot 'System32' }

$report = New-Object System.Collections.Generic.List[string]
$RedistHint = 'Установите Microsoft Visual C++ Redistributable x64: https://aka.ms/vs/17/release/vc_redist.x64.exe'

function Add-Line([string]$Text, [string]$Color = 'Gray') {
    Write-Host ('  ' + $Text) -ForegroundColor $Color
    $report.Add($Text)
}

function Save-Report {
    if (-not (Test-Path -LiteralPath $ServerDir -PathType Container)) { return }
    $path = Join-Path $ServerDir 'runtime_check.txt'
    $header = 'LEGIONFORGE runtime check ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $lines = @($header) + @($report)
    [System.IO.File]::WriteAllLines($path, [string[]]$lines, (New-Object System.Text.UTF8Encoding $true))
}

function Test-SystemDll([string]$Name) {
    if (-not $SystemDir) { return $false }
    return (Test-Path -LiteralPath (Join-Path $SystemDir $Name) -PathType Leaf)
}

# ---- Разбор PE: таблица импорта (IMAGE_IMPORT_DESCRIPTOR) ----
function Convert-RvaToOffset($Sections, [long]$Rva) {
    foreach ($s in $Sections) {
        $size = [math]::Max([long]$s.VSize, [long]$s.RawSize)
        if ($Rva -ge [long]$s.VA -and $Rva -lt ([long]$s.VA + $size)) {
            return [int]($Rva - [long]$s.VA + [long]$s.RawPtr)
        }
    }
    return -1
}

function Get-PeImports([string]$Path) {
    $b = [System.IO.File]::ReadAllBytes($Path)
    if ($b.Length -lt 0x40 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A) { throw 'не PE-файл (нет сигнатуры MZ)' }
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    if ($pe -lt 0 -or ($pe + 24) -gt $b.Length -or [BitConverter]::ToUInt32($b, $pe) -ne 0x00004550) {
        throw 'нет сигнатуры PE'
    }
    $numSections = [BitConverter]::ToUInt16($b, $pe + 6)
    $optSize = [BitConverter]::ToUInt16($b, $pe + 20)
    $opt = $pe + 24
    $magic = [BitConverter]::ToUInt16($b, $opt)
    if ($magic -eq 0x20B) { $ddBase = $opt + 112 }
    elseif ($magic -eq 0x10B) { $ddBase = $opt + 96 }
    else { throw 'неизвестный формат PE' }
    $importRva = [BitConverter]::ToUInt32($b, $ddBase + 8)
    if ($importRva -eq 0) { return @() }

    $sections = New-Object System.Collections.Generic.List[object]
    $secBase = $opt + $optSize
    for ($i = 0; $i -lt $numSections; $i++) {
        $o = $secBase + 40 * $i
        $sections.Add([pscustomobject]@{
            VSize   = [BitConverter]::ToUInt32($b, $o + 8)
            VA      = [BitConverter]::ToUInt32($b, $o + 12)
            RawSize = [BitConverter]::ToUInt32($b, $o + 16)
            RawPtr  = [BitConverter]::ToUInt32($b, $o + 20)
        })
    }
    $off = Convert-RvaToOffset $sections $importRva
    if ($off -lt 0) { return @() }

    $names = New-Object System.Collections.Generic.List[string]
    while (($off + 20) -le $b.Length) {
        $nameRva = [BitConverter]::ToUInt32($b, $off + 12)
        if ($nameRva -eq 0) { break }
        $nOff = Convert-RvaToOffset $sections $nameRva
        if ($nOff -ge 0) {
            $end = $nOff
            while ($end -lt $b.Length -and $b[$end] -ne 0) { $end++ }
            $names.Add([System.Text.Encoding]::ASCII.GetString($b, $nOff, $end - $nOff))
        }
        $off += 20
    }
    return $names.ToArray()
}

# ---- Поиск каталогов и индекс DLL ----
# Пути собираются по сегментам: это работает и с кириллицей, и со скобками "(x86)" в Program Files.
function Get-SubDirs([string]$Base, [string[]]$Segments) {
    $current = @()
    if ($Base) { $current = @($Base) }
    foreach ($seg in $Segments) {
        $next = New-Object System.Collections.Generic.List[string]
        foreach ($dir in $current) {
            if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
            if ($seg.Contains('*')) {
                foreach ($c in @(Get-ChildItem -LiteralPath $dir -Directory -Filter $seg -ErrorAction SilentlyContinue)) {
                    $next.Add($c.FullName)
                }
            }
            else {
                $p = Join-Path $dir $seg
                if (Test-Path -LiteralPath $p -PathType Container) { $next.Add($p) }
            }
        }
        $current = @($next)
    }
    return @($current)
}

function Add-DllIndex([hashtable]$Index, [string[]]$Dirs, [bool]$Recurse) {
    foreach ($d in $Dirs) {
        if (-not $d -or -not (Test-Path -LiteralPath $d -PathType Container)) { continue }
        $files = @(Get-ChildItem -LiteralPath $d -Filter '*.dll' -File -Recurse:$Recurse -ErrorAction SilentlyContinue)
        $files = @($files | Sort-Object @{ Expression = { if ($_.FullName -match 'x64') { 0 } else { 1 } } }, @{ Expression = { $_.FullName } })
        foreach ($f in $files) {
            $k = $f.Name.ToLowerInvariant()
            if (-not $Index.ContainsKey($k)) { $Index[$k] = $f.FullName }
        }
    }
}

# ================================================================== основной ход
Add-Line '== LEGIONFORGE: проверка библиотек сервера ==' 'White'
Add-Line ("Папка server: {0}" -f $ServerDir)

$exeNames = @('worldserver.exe', 'bnetserver.exe')
$localFiles = @{}
if (Test-Path -LiteralPath $ServerDir -PathType Container) {
    foreach ($f in @(Get-ChildItem -LiteralPath $ServerDir -File -ErrorAction SilentlyContinue)) {
        $localFiles[$f.Name.ToLowerInvariant()] = $f.FullName
    }
}
$missingExe = @($exeNames | Where-Object { -not $localFiles.ContainsKey($_.ToLowerInvariant()) })
if ($missingExe.Count -gt 0) {
    Add-Line ('Нет файлов: ' + ($missingExe -join ', ') + '. Сначала выполните build_server.bat или setup.bat.') 'Red'
    Save-Report
    exit 1
}

# Do not start an EXE compiled before the SpellEffect fix. File presence alone is
# insufficient: an old worldserver still ASSERTs at LoadSpellInfoStore.
$freshnessScript = Join-Path $Root 'tools\check_build_freshness.ps1'
if (-not (Test-Path -LiteralPath $freshnessScript -PathType Leaf)) {
    Add-Line 'Нет tools\check_build_freshness.ps1. Восстановите полный архив проекта.' 'Red'
    Save-Report
    exit 1
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $freshnessScript -Root $Root -ServerDir $ServerDir -Quiet
if ($LASTEXITCODE -ne 0) {
    Add-Line 'EXE не соответствуют исходникам или собраны до исправления SpellEffect. Запустите build_server.bat, затем play.bat.' 'Red'
    Save-Report
    exit 1
}
Add-Line 'Контроль сборки: EXE и исходники DB2/SpellEffect совпадают.' 'Green'

# Источники библиотек: Visual C++ runtime, Boost, OpenSSL, libmysql.
$index = @{}
$vsBases = @()
foreach ($pf in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($pf) { $vsBases += (Join-Path (Join-Path $pf 'Microsoft Visual Studio') '2022') }
}
$crtDirs = @()
foreach ($vs in $vsBases) {
    $crtDirs += Get-SubDirs $vs @('*', 'VC', 'Redist', 'MSVC', '*', 'x64', 'Microsoft.VC*.CRT')
}
$toolsDir = Join-Path $Root 'tools'
$crtDirs += Get-SubDirs (Join-Path $toolsDir 'vsbuildtools') @('VC', 'Redist', 'MSVC', '*', 'x64', 'Microsoft.VC*.CRT')
$boostDirs = @()
$boostDirs += Get-SubDirs $toolsDir @('boost_*', 'lib64-msvc-14.3')
$boostDirs += Get-SubDirs $toolsDir @('boost_*', 'lib')
Add-DllIndex $index @($crtDirs) $false
Add-DllIndex $index @($boostDirs) $false
Add-DllIndex $index @((Join-Path $toolsDir 'openssl'), (Join-Path $toolsDir 'mysql')) $true

# Обход зависимостей.
$queue = New-Object System.Collections.Generic.Queue[string]
foreach ($e in $exeNames) { $queue.Enqueue($localFiles[$e.ToLowerInvariant()]) }
$seen = @{}
$copied = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

while ($queue.Count -gt 0) {
    $file = $queue.Dequeue()
    try { $imports = @(Get-PeImports $file) }
    catch {
        Add-Line ("Не удалось разобрать {0}: {1}" -f (Split-Path -Leaf $file), $_.Exception.Message) 'Yellow'
        continue
    }
    foreach ($name in $imports) {
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        if ($key.StartsWith('api-ms-win-') -or $key.StartsWith('ext-ms-')) { continue }   # часть Windows 10/11
        if (Test-SystemDll $name) { continue }                                           # уже есть в System32
        if ($localFiles.ContainsKey($key)) { $queue.Enqueue($localFiles[$key]); continue }
        if ($index.ContainsKey($key)) {
            $src = $index[$key]
            $dest = Join-Path $ServerDir $name
            if (-not $CheckOnly) { Copy-Item -LiteralPath $src -Destination $dest -Force }
            $localFiles[$key] = $dest
            $copied.Add(("{0}  <-  {1}" -f $name, $src))
            $queue.Enqueue($src)
            continue
        }
        $missing.Add($name)
    }
}

if ($copied.Count -gt 0) {
    Add-Line ('Скопированы недостающие библиотеки: {0}' -f $copied.Count) 'Green'
    foreach ($c in $copied) { Add-Line ('  ' + $c) 'Green' }
}
else {
    Add-Line 'Все библиотеки уже на месте или есть в Windows.' 'Green'
}

$missingUnique = @($missing | Select-Object -Unique)
if ($missingUnique.Count -gt 0) {
    Add-Line 'НЕ НАЙДЕНЫ библиотеки, без которых сервер не запустится:' 'Red'
    foreach ($m in $missingUnique) { Add-Line ('  - ' + $m) 'Red' }
    if (@($missingUnique | Where-Object { $_ -match '^(vcruntime|msvcp|concrt|vcomp|ucrt)' }).Count -gt 0) { Add-Line $RedistHint 'Yellow' }
    if (@($missingUnique | Where-Object { $_ -match 'boost' }).Count -gt 0) { Add-Line 'Boost: выполните build_server.bat (шаг 1), чтобы подготовить tools\boost_*' 'Yellow' }
    if (@($missingUnique | Where-Object { $_ -match 'libssl|libcrypto' }).Count -gt 0) { Add-Line 'OpenSSL: выполните build_server.bat (шаг 1), чтобы подготовить tools\openssl' 'Yellow' }
    if (@($missingUnique | Where-Object { $_ -match 'libmysql' }).Count -gt 0) { Add-Line 'libmysql.dll: выполните build_server.bat (шаг 1), чтобы подготовить tools\mysql' 'Yellow' }
    Add-Line 'Полный отчёт: server\runtime_check.txt'
    Save-Report
    exit 1
}

foreach ($f in @('worldserver.conf', 'bnetserver.conf', 'bnetserver.cert.pem', 'bnetserver.key.pem')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ServerDir $f) -PathType Leaf)) {
        Add-Line ('Нет файла ' + $f + ' - запустите setup.bat для создания конфигурации.') 'Yellow'
    }
}
# ---------------------------------------------------------------------------
# [LEGIONFORGE FIX 2026-10] OPENSSL_Applink.
# DLL-проверка выше отвечает только "есть ли файл libcrypto-3-x64.dll".
# Но сервер может найти все DLL и всё равно умереть мгновенно и БЕЗ крэш-дампа:
#     OPENSSL_Uplink(00007FFFB2656C58,08): no OPENSSL_Applink
# Это происходит, когда динамический OpenSSL хочет написать в stderr, а exe не
# экспортирует OPENSSL_Applink (разные CRT у DLL и у exe). Проверяем экспорт.
# ---------------------------------------------------------------------------
$diagPath = Join-Path $PSScriptRoot 'tools\diagnose_openssl.ps1'
if (Test-Path -LiteralPath $diagPath -PathType Leaf) {
    $diagLines = @()
    try {
        $diagLines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $diagPath -ServerDir $ServerDir 2>&1 | Out-String -Stream)
    } catch {
        $diagLines = @()
    }
    $diagCode = $LASTEXITCODE
    foreach ($line in $diagLines) {
        $trimmed = "$line".Trim()
        if (-not $trimmed) { continue }
        $color = 'Gray'
        if ($trimmed -match '\[ОШИБКА\]') { $color = 'Red' }
        elseif ($trimmed -match '\[OK\]') { $color = 'Green' }
        elseif ($trimmed -match '\[!\]') { $color = 'Yellow' }
        Add-Line $trimmed $color
    }
    if ($diagCode -eq 1) {
        Add-Line 'OPENSSL_Applink: требуется пересборка сервера (build_server.bat) - фикс уже в Main.cpp.' 'Red'
        Save-Report
        exit 1
    } elseif ($diagCode -eq 0) {
        Add-Line 'OPENSSL_Applink: проверка пройдена.' 'Green'
    }
}

Add-Line 'OK: библиотеки для запуска на месте.' 'Green'
Save-Report
exit 0
