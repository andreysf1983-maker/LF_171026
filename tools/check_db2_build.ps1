[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$DataDir = '',
    [string]$Locale = ''
)

# LEGIONFORGE 7.3.5 - проверка файлов DB2 (папка dbc) на соответствие ядру и билду клиента.
#
# ЗАЧЕМ. worldserver сверяет данные клиента со своими константами и при расхождении
# аварийно завершается через ASSERT (намеренная запись в нулевой указатель, см.
# core/src/common/Debugging/Errors.cpp). Реальный пример от 10.10.2026:
#   DB2Stores.cpp:745 ASSERTION FAILED:
#   BATTLE_PET_SPECIES_MAX_ID (2164) must be equal to or greater than 5004
# Это значит: в BattlePetSpecies.db2 максимальный ID = 5003, а ядро рассчитано на 2163.
# Такой dbc НЕ из чистого клиента 7.3.5 build 26124.
#
# ЧТО ПРОВЕРЯЕТСЯ (без запуска сервера и без Python):
#   1. Сигнатура файла: WDC1 (Legion). WDC2/WDC3/WDC5 = клиент новее 7.3.5.
#   2. LayoutHash каждого DB2 против ожидаемого в core/.../DB2Metadata.h.
#      Ядро отклоняет файл с чужим хэшем (DB2FileLoader.cpp:1408 return false).
#   3. Ограничения, на которые в ядре стоят ASSERT по данным клиента:
#      BattlePetSpecies (BATTLE_PET_SPECIES_MAX_ID), Difficulty (MAX_DIFFICULTY),
#      TaxiNodes (TaxiMaskSize). GetNumRows() = MaxId + 1 (DB2Store.h:100).
#   4. Полнота набора: сколько DB2 на месте из тех, что ядро грузит (242 хранилища).
#
# Коды выхода: 0 - dbc подходит; 1 - найдены несоответствия; 2 - папка dbc не найдена.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_db2_build.ps1

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $DataDir) { $DataDir = Join-Path $Root 'server\data' }

$coreDir = Join-Path $Root 'core'
$metaHeader = Join-Path $coreDir 'src\server\game\DataStores\DB2Metadata.h'
$storesFile = Join-Path $coreDir 'src\server\game\DataStores\DB2Stores.cpp'
$enumsFile = Join-Path $coreDir 'src\server\game\DataStores\DBCEnums.h'
$spellEnumsFile = Join-Path $coreDir 'src\server\game\Miscellaneous\SharedDefines.h'
$spellHandlersFile = Join-Path $coreDir 'src\server\game\Spells\SpellEffects.cpp'
foreach ($f in @($metaHeader, $storesFile, $enumsFile, $spellEnumsFile, $spellHandlersFile)) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Host "  [!] Не найден файл ядра: $f"; exit 2 }
}

# ---------- 1. Ожидаемые LayoutHash из метаданных ядра ----------
$metaText = [System.IO.File]::ReadAllText($metaHeader)
$expected = @{}
foreach ($m in [regex]::Matches($metaText, 'struct\s+(\w+)Meta\s*\{[\s\S]*?static\s+DB2Meta\s+const\*\s+Instance\(\)[\s\S]*?instance\(\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(0x[0-9A-Fa-f]+)')) {
    $expected[$m.Groups[1].Value] = [pscustomobject]@{
        Meta = $m.Groups[1].Value
        IndexField = [int]$m.Groups[2].Value
        FieldCount = [int]$m.Groups[3].Value
        LayoutHash = [Convert]::ToUInt32($m.Groups[4].Value, 16)
    }
}
if ($expected.Count -lt 100) { Write-Host "  [!] Не удалось разобрать DB2Metadata.h (найдено $($expected.Count) таблиц)"; exit 2 }

# ---------- 2. Соответствие "имя файла DB2" -> "мета-структура" ----------
$storesText = [System.IO.File]::ReadAllText($storesFile)
$fileToMeta = @{}
foreach ($m in [regex]::Matches($storesText, 'DB2Storage<(\w+)Entry>\s+\w+\("([^"]+\.db2)"')) {
    $entry = $m.Groups[1].Value
    $fileName = $m.Groups[2].Value
    if ($expected.ContainsKey($entry)) { $fileToMeta[$fileName] = $entry }
}
if ($fileToMeta.Count -lt 100) { Write-Host "  [!] Не удалось разобрать DB2Stores.cpp (найдено $($fileToMeta.Count) хранилищ)"; exit 2 }

# ---------- 3. Константы ядра, на которые стоят ASSERT ----------
$enumText = [System.IO.File]::ReadAllText($enumsFile)
$battlePetMaxId = 0
$bp = [regex]::Match($enumText, '#define\s+BATTLE_PET_SPECIES_MAX_ID\s+(\d+)')
if ($bp.Success) { $battlePetMaxId = [int]$bp.Groups[1].Value }
$taxiMaskSize = 0
$tm = [regex]::Match($enumText, '#define\s+TaxiMaskSize\s+(\d+)')
if ($tm.Success) { $taxiMaskSize = [int]$tm.Groups[1].Value }
# MAX_DIFFICULTY - последний элемент enum Difficulty, идёт за наибольшим явным значением
$maxDifficulty = 0
$diffEnum = [regex]::Match($enumText, 'enum\s+Difficulty\s*(?::\s*\w+\s*)?\{([\s\S]*?)MAX_DIFFICULTY')
if ($diffEnum.Success) {
    $values = @()
    foreach ($m in [regex]::Matches($diffEnum.Groups[1].Value, '=\s*(\d+)')) { $values += [int]$m.Groups[1].Value }
    if ($values.Count -gt 0) { $maxDifficulty = ($values | Measure-Object -Maximum).Maximum + 1 }
}

# SpellEffect.db2 is WDC1 with compressed record sections: its individual
# effects cannot be inferred from the 84-byte header. But mismatched C++ enum
# and dispatch table is a deterministic crash, so catch it before worldserver.
$spellEnumText = [System.IO.File]::ReadAllText($spellEnumsFile)
$spellHandlerText = [System.IO.File]::ReadAllText($spellHandlersFile)
$spellLimitMatch = [regex]::Match($spellEnumText, 'TOTAL_SPELL_EFFECTS\s*=\s*(\d+)')
$spellHandlerBlock = [regex]::Match($spellHandlerText, 'pEffect\s+SpellEffects\[TOTAL_SPELL_EFFECTS\]\s*=\s*\{([\s\S]*?)\};')
if (-not $spellLimitMatch.Success -or -not $spellHandlerBlock.Success) {
    Write-Host '  [!] Не удалось сверить TOTAL_SPELL_EFFECTS и таблицу обработчиков.'
    exit 2
}
$spellLimit = [int]$spellLimitMatch.Groups[1].Value
$spellHandlers = [regex]::Matches($spellHandlerBlock.Groups[1].Value, '&Spell::').Count

# ---------- 4. Каталог dbc ----------
$dbcRoot = Join-Path $DataDir 'dbc'
if (-not (Test-Path -LiteralPath $dbcRoot -PathType Container)) {
    Write-Host "  [!] Папка не найдена: $dbcRoot"
    Write-Host '      Извлеките данные клиента: extract_maps.bat (нужен клиент 7.3.5 build 26124).'
    exit 2
}
if (-not $Locale) {
    if (Test-Path -LiteralPath (Join-Path $dbcRoot 'enUS') -PathType Container) { $Locale = 'enUS' }
    else {
        $first = @(Get-ChildItem -LiteralPath $dbcRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($first.Count -gt 0) { $Locale = $first[0].Name }
    }
}
$dbcDir = Join-Path $dbcRoot $Locale
if (-not (Test-Path -LiteralPath $dbcDir -PathType Container)) {
    Write-Host "  [!] Папка локали не найдена: $dbcDir"; exit 2
}

function Read-Db2Header([string]$Path) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $buffer = New-Object byte[] 84
        $read = $stream.Read($buffer, 0, 84)
        if ($read -lt 84) { return $null }
        return [pscustomobject]@{
            Signature = [BitConverter]::ToUInt32($buffer, 0)
            RecordCount = [BitConverter]::ToUInt32($buffer, 4)
            FieldCount = [BitConverter]::ToUInt32($buffer, 8)
            TableHash = [BitConverter]::ToUInt32($buffer, 20)
            LayoutHash = [BitConverter]::ToUInt32($buffer, 24)
            MinId = [BitConverter]::ToUInt32($buffer, 28)
            MaxId = [BitConverter]::ToUInt32($buffer, 32)
            IndexField = [BitConverter]::ToInt16($buffer, 46)
        }
    }
    finally { $stream.Dispose() }
}

function Get-SignatureName([uint32]$Sig) {
    switch ($Sig) {
        0x31434457 { return 'WDC1' }
        0x32434457 { return 'WDC2' }
        0x33434457 { return 'WDC3' }
        0x34434457 { return 'WDC4' }
        0x35434457 { return 'WDC5' }
        default { return ('0x{0:X8}' -f $Sig) }
    }
}

Write-Host '  == LEGIONFORGE: проверка DB2 (dbc) на соответствие ядру =='
Write-Host ("  Каталог: {0}" -f $dbcDir)
Write-Host ("  Ожидается таблиц ядром: {0}; константы: BATTLE_PET_SPECIES_MAX_ID={1}, MAX_DIFFICULTY={2}, TaxiMaskSize={3}" -f
    $fileToMeta.Count, $battlePetMaxId, $maxDifficulty, $taxiMaskSize)

$missing = New-Object System.Collections.Generic.List[string]
$badSignature = New-Object System.Collections.Generic.List[string]
$badLayout = New-Object System.Collections.Generic.List[string]
$overLimit = New-Object System.Collections.Generic.List[string]
$checkedCount = 0
if ($spellLimit -ne $spellHandlers) {
    $overLimit.Add(('SpellEffect dispatch table: TOTAL_SPELL_EFFECTS={0}, фактических обработчиков={1}. Исправьте исходники и пересоберите EXE.' -f $spellLimit, $spellHandlers))
}
Write-Host ("  SpellEffect: допустимо 0..{0}; обработчиков {1}. Значения записей WDC1 проверяет worldserver." -f ($spellLimit - 1), $spellHandlers)

foreach ($fileName in ($fileToMeta.Keys | Sort-Object)) {
    $metaName = $fileToMeta[$fileName]
    $path = Join-Path $dbcDir $fileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing.Add($fileName); continue }

    $header = Read-Db2Header $path
    if ($null -eq $header) { $missing.Add($fileName + ' (файл короче 84 байт)'); continue }
    $checkedCount++

    $sigName = Get-SignatureName $header.Signature
    if ($header.Signature -ne 0x31434457) {
        $badSignature.Add(('{0}: сигнатура {1} (ядро читает только WDC1 - это клиент новее 7.3.5)' -f $fileName, $sigName))
        continue
    }

    $want = $expected[$metaName]
    if ($header.LayoutHash -ne $want.LayoutHash) {
        $badLayout.Add(('{0}: LayoutHash 0x{1:X8}, ядро ожидает 0x{2:X8} (другой билд клиента)' -f
            $fileName, $header.LayoutHash, $want.LayoutHash))
    }

    $rows = [uint32]$header.MaxId + 1
    switch ($metaName) {
        'BattlePetSpecies' {
            if ($battlePetMaxId -gt 0 -and $rows -gt $battlePetMaxId) {
                $overLimit.Add(('{0}: MaxId={1} -> строк {2}, а BATTLE_PET_SPECIES_MAX_ID={3}. worldserver упадёт на ASSERT (DB2Stores.cpp:745).' -f
                    $fileName, $header.MaxId, $rows, $battlePetMaxId))
            }
        }
        'Difficulty' {
            if ($maxDifficulty -gt 0 -and $rows -gt $maxDifficulty) {
                $overLimit.Add(('{0}: MaxId={1} -> строк {2}, а MAX_DIFFICULTY={3}. worldserver упадёт на ASSERT (DB2Stores.cpp:827).' -f
                    $fileName, $header.MaxId, $rows, $maxDifficulty))
            }
        }
        'TaxiNodes' {
            if ($taxiMaskSize -gt 0) {
                $need = [math]::Floor((($rows - 1) / 8)) + 1
                if ($taxiMaskSize -lt $need) {
                    $overLimit.Add(('{0}: строк {1}, нужно TaxiMaskSize>={2}, а в ядре {3}. worldserver упадёт на ASSERT (DB2Stores.cpp:1096).' -f
                        $fileName, $rows, $need, $taxiMaskSize))
                }
            }
        }
    }
}

Write-Host ("  Проверено файлов: {0}; отсутствует: {1}" -f $checkedCount, $missing.Count)
$problems = 0

if ($badSignature.Count -gt 0) {
    $problems += $badSignature.Count
    Write-Host '  [!] Файлы НЕ из клиента 7.3.5 (сигнатура новее WDC1):' -ForegroundColor Red
    $badSignature | ForEach-Object { Write-Host ('      ' + $_) -ForegroundColor Red }
}
if ($badLayout.Count -gt 0) {
    $problems += $badLayout.Count
    Write-Host '  [!] LayoutHash не совпадает с ядром (dbc от другого билда):' -ForegroundColor Red
    $badLayout | ForEach-Object { Write-Host ('      ' + $_) -ForegroundColor Red }
}
if ($overLimit.Count -gt 0) {
    $problems += $overLimit.Count
    Write-Host '  [!] Данные выходят за пределы констант ядра (ASSERT при запуске):' -ForegroundColor Red
    $overLimit | ForEach-Object { Write-Host ('      ' + $_) -ForegroundColor Red }
}
if ($missing.Count -gt 0) {
    $problems += $missing.Count
    Write-Host ('  [!] Отсутствуют файлы DB2: {0} (первые 15)' -f $missing.Count) -ForegroundColor Yellow
    $missing | Select-Object -First 15 | ForEach-Object { Write-Host ('      ' + $_) -ForegroundColor Yellow }
}

if ($problems -eq 0) {
    Write-Host '  [OK] Заголовки dbc, LayoutHash и статические лимиты совпадают; содержимое SpellEffect проверяется при загрузке worldserver.' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host '  Что делать:' -ForegroundColor Cyan
Write-Host '    1. Папка server\data скопирована откуда-то целиком? Тогда dbc (и, скорее всего, maps/vmaps)'
Write-Host '       взяты из другого клиента. Извлеките данные заново из своего клиента 7.3.5 build 26124:'
Write-Host '       extract_maps.bat - он сам напишет dbc из CASC клиента.'
Write-Host '    2. Проверить билд клиента: в логе клиента (Logs/FrameXML.log) или по версии Wow-64.exe.'
Write-Host '       Сервер LEGIONFORGE работает только с 7.3.5 (build 26124).'
Write-Host '    3. Если dbc намеренно расширен (например, добавлены питомцы из новых дополнений),'
Write-Host '       потребуется поднять константы ядра и пересобрать его - см. docs\CRASH-DIAGNOSIS.md,'
Write-Host '       раздел "BattlePetSpecies 5004". Без пересборки сервер запускаться не будет.'
exit 1
