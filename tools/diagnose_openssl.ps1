<#
.SYNOPSIS
    LEGIONFORGE 7.3.5 - диагностика фатального выхода bnetserver/worldserver
    из-за "OPENSSL_Uplink(...): no OPENSSL_Applink".

.DESCRIPTION
    Симптом: окно сервера печатает баннер, затем одну строку
        OPENSSL_Uplink(00007FFFB2656C58,08): no OPENSSL_Applink
    и сразу закрывается ("Для продолжения нажмите любую клавишу").
    Крэш-дампа нет, в логе пусто - процесс убит внутри libcrypto до инициализации.

    Механика. Динамический OpenSSL (libcrypto-3-x64.dll) и exe собраны с РАЗНЫМИ
    CRT, поэтому DLL не может звать stdio напрямую: она берёт указатели из таблицы
    OPENSSL_ApplinkTable, которую обязано заполнить приложение функцией
    OPENSSL_Applink(). Если экспорта нет, OPENSSL_Uplink() вызывает OPENSSL_die().

    Что проверяет скрипт:
      1. Есть ли в exe экспорт OPENSSL_Applink (т.е. скомпилирован ли фикс
         #include <openssl/applink.c> из core\src\server\*\Main.cpp).
      2. Какие DLL OpenSSL лежат рядом с exe (это то, что реально загрузится).
      3. Нет ли в PATH посторонних libcrypto/libssl, которые могут перекрыть
         локальные (Git for Windows, PostgreSQL, Steam, старые сборки OpenSSL).
      4. Валидна ли переменная OPENSSL_CONF (невалидный путь - частый триггер
         первой же записи в stderr из DLL).

.PARAMETER ServerDir
    Каталог с bnetserver.exe и worldserver.exe. По умолчанию ..\server.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagnose_openssl.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagnose_openssl.ps1 -ServerDir D:\legionforge\server
#>
param(
    [string]$ServerDir = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
if (-not $ServerDir) { $ServerDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'server' }

$script:ExitCode = 0
function Say([string]$Text, [string]$Color = 'Gray') {
    if ($Quiet) { return }
    Write-Host $Text -ForegroundColor $Color
}
function Fail([string]$Text) { Say "  [ОШИБКА] $Text" 'Red';    $script:ExitCode = 1 }
function Warn([string]$Text) { Say "  [!] $Text" 'Yellow'; if ($script:ExitCode -eq 0) { $script:ExitCode = 2 } }
function Ok([string]$Text)   { Say "  [OK] $Text" 'Green' }

Say '  == LEGIONFORGE: диагностика OpenSSL / OPENSSL_Applink =='
Say "  Каталог сервера: $ServerDir"

if (-not (Test-Path -LiteralPath $ServerDir)) {
    Fail "Каталог $ServerDir не найден."
    exit $script:ExitCode
}

# ---------------------------------------------------------------------------
# 1. Parse the actual PE export directory. A raw string search is NOT proof
#    of an exported symbol: the same name can occur in debug/import strings.
# ---------------------------------------------------------------------------
function Get-PeU32([byte[]]$Bytes, [long]$Offset) {
    if ($Offset -lt 0 -or ($Offset + 4) -gt $Bytes.Length) { throw 'PE header points outside the file' }
    return [BitConverter]::ToUInt32($Bytes, [int]$Offset)
}
function Convert-PeRva([object[]]$Sections, [long]$Rva) {
    foreach ($s in $Sections) {
        $size = [math]::Max([long]$s.VirtualSize, [long]$s.RawSize)
        if ($Rva -ge [long]$s.VirtualAddress -and $Rva -lt ([long]$s.VirtualAddress + $size)) {
            return [long]($Rva - [long]$s.VirtualAddress + [long]$s.RawPointer)
        }
    }
    return -1
}
function Test-PeExport([string]$Path, [string]$Name) {
    $b = [System.IO.File]::ReadAllBytes($Path)
    if ($b.Length -lt 0x100 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A) { throw 'Invalid MZ header' }
    $pe = Get-PeU32 $b 0x3C
    if ((Get-PeU32 $b $pe) -ne 0x00004550) { throw 'Invalid PE signature' }
    $sectionCount = [BitConverter]::ToUInt16($b, [int]($pe + 6))
    $optionalSize = [BitConverter]::ToUInt16($b, [int]($pe + 20))
    $opt = [long]$pe + 24
    if (($opt + $optionalSize) -gt $b.Length) { throw 'Truncated optional header' }
    $magic = [BitConverter]::ToUInt16($b, [int]$opt)
    if ($magic -eq 0x20B) { $dirOffset = $opt + 112 }
    elseif ($magic -eq 0x10B) { $dirOffset = $opt + 96 }
    else { throw 'Unsupported PE optional header' }
    if (($dirOffset + 4) -gt ($opt + $optionalSize)) { throw 'Missing export data directory' }
    $exportRva = Get-PeU32 $b $dirOffset
    if ($exportRva -eq 0) { return $false }

    $sections = @()
    $start = $opt + $optionalSize
    if ($sectionCount -gt 96 -or ($start + 40 * $sectionCount) -gt $b.Length) { throw 'Invalid PE section table' }
    for ($i = 0; $i -lt $sectionCount; $i++) {
        $p = $start + 40 * $i
        $sections += [pscustomobject]@{
            VirtualSize = Get-PeU32 $b ($p + 8)
            VirtualAddress = Get-PeU32 $b ($p + 12)
            RawSize = Get-PeU32 $b ($p + 16)
            RawPointer = Get-PeU32 $b ($p + 20)
        }
    }
    $exportOff = Convert-PeRva $sections $exportRva
    if ($exportOff -lt 0) { throw 'Invalid export directory RVA' }
    $count = Get-PeU32 $b ($exportOff + 24)
    $namesRva = Get-PeU32 $b ($exportOff + 32)
    if ($count -gt 100000) { throw 'Invalid export name count' }
    $table = Convert-PeRva $sections $namesRva
    if ($table -lt 0) { throw 'Invalid export name RVA' }
    for ($i = 0; $i -lt $count; $i++) {
        $nameRva = Get-PeU32 $b ($table + 4 * $i)
        $nameOff = Convert-PeRva $sections $nameRva
        if ($nameOff -lt 0 -or ($nameOff + $Name.Length + 1) -gt $b.Length) { continue }
        if ([System.Text.Encoding]::ASCII.GetString($b, [int]$nameOff, $Name.Length) -cne $Name) { continue }
        if ($b[[int]($nameOff + $Name.Length)] -eq 0) { return $true }
    }
    return $false
}

$needle = 'OPENSSL_Applink'

foreach ($exeName in @('bnetserver.exe', 'worldserver.exe')) {
    $exePath = Join-Path $ServerDir $exeName
    if (-not (Test-Path -LiteralPath $exePath)) {
        Say "  [$exeName] не найден - пропуск (соберите сервер: build_server.bat)" 'DarkGray'
        continue
    }

    Say ''
    Say "  --- $exeName ---" 'Cyan'

    $hasExport = $false
    try { $hasExport = Test-PeExport $exePath $needle }
    catch { Warn "Не удалось разобрать таблицу экспорта $exeName : $($_.Exception.Message)" }

    if ($hasExport) {
        Ok "экспорт OPENSSL_Applink присутствует в PE - фикс скомпилирован в exe."
    } else {
        Fail "в таблице экспорта exe НЕТ OPENSSL_Applink. Это даёт '$needle' -> OPENSSL_die()."
        Say '        Исправление уже есть в исходниках:' 'Yellow'
        Say '          core\src\server\bnetserver\Main.cpp'   'Yellow'
        Say '          core\src\server\worldserver\Main.cpp'  'Yellow'
        Say '        там добавлено #include <openssl/applink.c>.' 'Yellow'
        Say '        Пересоберите сервер:  build_server.bat' 'Yellow'
        Say '        До пересборки помогает временное смягчение (см. пункт 4 ниже).' 'Yellow'
    }
}

# ---------------------------------------------------------------------------
# 2. DLL OpenSSL рядом с exe
# ---------------------------------------------------------------------------
Say ''
Say '  --- DLL OpenSSL рядом с сервером ---' 'Cyan'
$localDlls = @(Get-ChildItem -LiteralPath $ServerDir -Filter '*.dll' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^(libcrypto|libssl)' })
if ($localDlls.Count -eq 0) {
    Say '  Локальных libcrypto/libssl нет: OpenSSL статически влинкован в exe.' 'DarkGray'
    Say '  Тогда uplink-таблица не нужна и строка про OPENSSL_Applink означала бы' 'DarkGray'
    Say '  загрузку ПОСТОРОННЕЙ DLL из PATH - смотрите пункт 3.' 'DarkGray'
} else {
    foreach ($d in $localDlls) {
        $ver = ''
        try { $ver = $d.VersionInfo.FileVersion } catch { }
        Ok ("{0}  (версия {1}, {2:N0} байт)" -f $d.Name, $(if ($ver) { $ver } else { 'н/д' }), $d.Length)
    }
    $crypto = @($localDlls | Where-Object { $_.Name -match '^libcrypto' })
    $ssl    = @($localDlls | Where-Object { $_.Name -match '^libssl' })
    if ($crypto.Count -ne $ssl.Count) {
        Warn 'libcrypto и libssl присутствуют не в паре - возможны конфликты версий.'
    }
}

# ---------------------------------------------------------------------------
# 3. DLL search order: the EXE directory wins over PATH for the SAME filename.
# libcrypto-4-x64.dll cannot replace an import of libcrypto-3-x64.dll. Report
# only actual missing local 3.x libraries, not every unrelated file in PATH.
# ---------------------------------------------------------------------------
Say ''
Say '  --- OpenSSL DLL в PATH ---' 'Cyan'
$localNames = @{}
foreach ($dll in $localDlls) { $localNames[$dll.Name.ToLowerInvariant()] = $true }
$seenDirs = @{}
$hiddenCount = 0
$missingLocalInPath = @{}
if ($env:PATH) {
    foreach ($item in ($env:PATH -split ';')) {
        $dir = [Environment]::ExpandEnvironmentVariables($item.Trim().Trim('"'))
        if (-not $dir -or $seenDirs.ContainsKey($dir) -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        $seenDirs[$dir] = $true
        try {
            $hits = @(Get-ChildItem -LiteralPath $dir -Filter '*.dll' -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -match '^(libcrypto|libssl)' })
            foreach ($h in $hits) {
                $name = $h.Name.ToLowerInvariant()
                if ($localNames.ContainsKey($name)) { $hiddenCount++; continue }
                if ($name -match '^lib(crypto|ssl)-3-x64\.dll$' -and -not $missingLocalInPath.ContainsKey($name)) {
                    $missingLocalInPath[$name] = $dir
                }
            }
        } catch { }
    }
}
foreach ($name in $missingLocalInPath.Keys) {
    Warn ("Локальная DLL {0} отсутствует; Windows может загрузить её из {1}. Пересоберите сервер для копирования пары DLL." -f $name, $missingLocalInPath[$name])
}
if ($missingLocalInPath.Count -eq 0) {
    Ok ("Конфликтов в PATH нет. {0} совпадений перекрыты локальными DLL; DLL с другими именами не замещают их." -f $hiddenCount)
}

# ---------------------------------------------------------------------------
# 4. OPENSSL_CONF
# ---------------------------------------------------------------------------
Say ''
Say '  --- Переменная OPENSSL_CONF ---' 'Cyan'
$cnf = $env:OPENSSL_CONF
$bundled = Join-Path $PSScriptRoot 'openssl.cnf'
if (-not $cnf) {
    Say '  [i] OPENSSL_CONF не задана. Это не ошибка, если в EXE есть OPENSSL_Applink;' 'Gray'
    Say '      play.bat задаёт проверенный конфиг перед диагностикой и запуском.' 'Gray'
} elseif (Test-Path -LiteralPath $cnf) {
    Ok "OPENSSL_CONF задана и файл существует: $cnf"
} else {
    Fail "OPENSSL_CONF указывает на НЕСУЩЕСТВУЮЩИЙ файл: $cnf"
}

if (Test-Path -LiteralPath $bundled) {
    Say ''
    Say '  При необходимости задайте локальный конфиг OpenSSL:' 'Cyan'
    Say "      set `"OPENSSL_CONF=$bundled`"" 'White'
    Say '  play.bat подставляет этот путь автоматически, если OPENSSL_CONF пуста' 'Gray'
    Say '  или указывает на несуществующий файл.' 'Gray'
} else {
    Warn "Не найден штатный конфиг $bundled"
}

Say ''
if ($script:ExitCode -eq 0) {
    Ok 'Признаков проблемы OPENSSL_Applink не обнаружено.'
} elseif ($script:ExitCode -eq 1) {
    Fail 'Требуется пересборка сервера (build_server.bat) - фикс уже в исходниках.'
} else {
    Warn 'Есть предупреждения; если сервер всё равно падает с no OPENSSL_Applink - пересоберите его.'
}

exit $script:ExitCode
