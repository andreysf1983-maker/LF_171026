[CmdletBinding()]
param(
    [int]$Value = 0,
    [switch]$Restore,
    [string]$Root = ''
)

# LEGIONFORGE 7.3.5 - задать BATTLE_PET_SPECIES_MAX_ID под данные вашего клиента.
#
# КОГДА НУЖНО. worldserver падает при старте:
#   DB2Stores.cpp:745 ASSERTION FAILED:
#   BATTLE_PET_SPECIES_MAX_ID (2164) must be equal to or greater than 5004
# Это значит, что в BattlePetSpecies.db2 вашего клиента MaxId = 5003, то есть клиент
# содержит больше видов питомцев, чем чистый 7.3.5 build 26124 (там предел 2163).
# dbc извлекается ИЗ клиента, поэтому пересборка data не поможет: значение надо
# поднять в ядре и пересобрать worldserver.
#
# ЧТО МЕНЯЕТ. Одну строку core/src/server/game/DataStores/DBCEnums.h.
# Константа используется всего в двух местах:
#   * ASSERT при загрузке DB2 (DB2Stores.cpp:745);
#   * ёмкость входящего буфера KnownPets в CMSG_AUCTION_LIST_ITEMS
#     (AuctionHousePackets.h:280, чтение на стороне сервера).
# Формат ИСХОДЯЩИХ пакетов от этого не меняется, поэтому правка протокольно безопасна.
#
# Запуск:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\set_pet_species_max_id.ps1 -Value 5004
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\set_pet_species_max_id.ps1 -Restore
# После изменения обязательна пересборка: build_worldserver.bat
# Коды выхода: 0 - успех, 1 - ошибка параметров/файла.

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$file = Join-Path $Root 'core\src\server\game\DataStores\DBCEnums.h'
if (-not (Test-Path -LiteralPath $file)) { Write-Host "  [!] Не найден файл: $file"; exit 1 }

$pattern = '#define\s+BATTLE_PET_SPECIES_MAX_ID\s+(\d+)'
$text = [System.IO.File]::ReadAllText($file)
$current = [regex]::Match($text, $pattern)
if (-not $current.Success) { Write-Host '  [!] Строка BATTLE_PET_SPECIES_MAX_ID не найдена.'; exit 1 }
$currentValue = [int]$current.Groups[1].Value

if ($Restore) {
    $target = 2164
    Write-Host ("  [*] Возврат к значению чистого 7.3.5 build 26124: {0} -> {1}" -f $currentValue, $target)
}
elseif ($Value -gt 0) { $target = $Value }
else {
    Write-Host ("  [i] Текущее значение BATTLE_PET_SPECIES_MAX_ID = {0}" -f $currentValue)
    Write-Host '      Укажите -Value <число> (из сообщения ASSERT: "must be equal to or greater than N")'
    Write-Host '      или -Restore для возврата к 2164.'
    exit 0
}

if ($target -lt 2164) {
    Write-Host "  [!] Значение $target меньше 2164 - это сломает чистый клиент 7.3.5. Отказ."
    exit 1
}
if ($target -eq $currentValue) {
    Write-Host ("  [OK] Значение уже {0}, менять нечего." -f $currentValue)
    exit 0
}

$backup = "$file.orig"
if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $file -Destination $backup -Force
    Write-Host "  [*] Резервная копия: $backup"
}
$updated = [regex]::Replace($text, $pattern, "#define BATTLE_PET_SPECIES_MAX_ID $target", 1)
[System.IO.File]::WriteAllText($file, $updated, (New-Object System.Text.UTF8Encoding $false))

$verify = [int][regex]::Match([System.IO.File]::ReadAllText($file), $pattern).Groups[1].Value
if ($verify -ne $target) { Write-Host "  [!] Проверка не прошла: в файле осталось $verify"; exit 1 }

Write-Host ("  [OK] BATTLE_PET_SPECIES_MAX_ID = {0} (было {1})." -f $target, $currentValue)
Write-Host '      Теперь ОБЯЗАТЕЛЬНО пересоберите ядро: build_worldserver.bat'
Write-Host ("      Ёмкость KnownPets (входящий буфер аукциона) изменится с {0} до {1} байт;" -f
    ([math]::Floor($currentValue / 8) + 1), ([math]::Floor($target / 8) + 1))
Write-Host '      формат исходящих пакетов от этого не меняется.'
exit 0
