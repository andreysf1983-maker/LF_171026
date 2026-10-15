[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ClientDir = '',
    [string]$ServerDir = '',
    [ValidateSet('none', 'new', 'priority', 'all')]
    [string]$MmapsMode = 'new',
    # Перезаписывать db2, которые уже есть на сервере, но отличаются от клиентских.
    # ОПАСНО: ядро проверяет LayoutHash и MaxId -> возможен ASSERT при старте.
    [switch]$OverwriteDb2,
    # Не трогать vmaps (ускоряет повторный прогон).
    [switch]$SkipVmaps
)

# ===========================================================================
#  LEGIONFORGE 7.3.5 - ДОИЗВЛЕЧЕНИЕ недостающих данных (delta extract).
#
#  Отличие от extract_maps.ps1: ничего не удаляет и не перезаписывает.
#  Клиент распаковывается во временную папку setup_tmp\delta, после чего
#  в server\data копируются ТОЛЬКО те файлы, которых там ещё нет.
#  Это именно то, что нужно для кастомных клиентов (UWoW и аналоги):
#  готовые maps/vmaps из чужой сборки остаются, а новые карты, db2 новых
#  рас и прочий кастом добавляются поверх.
#
#  Изменившиеся db2 по умолчанию НЕ перезаписываются, а складываются в
#  server\data\dbc_client_delta - их подмена может уронить worldserver по
#  ASSERT (несовпадение LayoutHash/MaxId с ядром). Решение принимает человек.
# ===========================================================================

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
. (Join-Path $Root 'tools\lf_db2.ps1')

$dataDir   = Join-Path $ServerDir 'data'
$staging   = Join-Path $Root 'setup_tmp\delta'
$reportDir = Join-Path $Root 'reports'
$logDir    = Join-Path $ServerDir 'logs'
New-Item -ItemType Directory -Force -Path $staging, $reportDir, $logDir, $dataDir | Out-Null
# [LEGIONFORGE PATCH 2026-10] vmap4extractor пишет Buildings/ в ТЕКУЩИЙ каталог,
# vmap4assembler ожидает его наличие; mapextractor - подкаталоги staging.
# Без предварительного создания часть инструментов молча ничего не извлекала.
foreach ($sub in @('maps', 'dbc', 'Cameras', 'gt', 'Buildings', 'vmaps', 'mmaps')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $staging $sub) | Out-Null
}
$logFile = Join-Path $logDir ('extract_delta_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Log([string]$text, [string]$color = 'Gray') {
    Write-Host $text -ForegroundColor $color
    Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $text) -Encoding UTF8
}

# [LEGIONFORGE PATCH 2026-10] Безопасный запуск внешних exe.
# Корень бага "извлечение карт": при $ErrorActionPreference = 'Stop' любая строка,
# которую программа пишет в stderr, превращается Windows PowerShell 5.1 в
# NativeCommandError и ОБРЫВАЕТ весь скрипт. Именно так падал шаг 2/4 (vmaps):
#   vmap4extractor.exe : Can't open World\Maps\test\test.wdt: FILE_NOT_FOUND
# Это штатное сообщение экстрактора о dev/test-карте без геометрии, а не ошибка.
# Функция ниже: (а) временно переключает EAP на Continue, (б) разворачивает
# ErrorRecord в обычный текст, (в) фильтрует известные штатные сообщения,
# (г) возвращает код возврата программы (внутри функции $LASTEXITCODE не виден
# снаружи, поэтому код именно возвращается).
function Invoke-LfTool {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string[]]$IgnorePatterns = @(
            'FILE_NOT_FOUND',
            "Can't open .*\.wdt",
            'Skipping map',
            '^\[INFO\] Skipped '
        )
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Log ("  [!] Инструмент не найден: {0}" -f $FilePath) 'Yellow'
        return 127
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Log ("      > `"{0}`" {1}" -f (Split-Path -Leaf $FilePath), ($Arguments -join ' ')) 'DarkGray'
        & $FilePath @Arguments 2>&1 | ForEach-Object {
            $line = $null
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                if ($_.TargetObject -is [string] -and "$($_.TargetObject)".Trim()) { $line = [string]$_.TargetObject }
                elseif ($_.Exception -and "$($_.Exception.Message)".Trim()) { $line = [string]$_.Exception.Message }
                else { $line = $_.ToString() }
            }
            elseif ($_ -is [System.Exception]) { $line = [string]$_.Message }
            else { $line = "$_" }
            if ([string]::IsNullOrWhiteSpace($line)) { return }
            if ($line -eq 'System.Management.Automation.RemoteException') { return }
            foreach ($p in $IgnorePatterns) {
                if ($line -match $p) { $script:ignoredToolLines++; return }
            }
            Log ("      | {0}" -f $line) 'DarkGray'
        }
    }
    finally { $ErrorActionPreference = $prev }
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    Log ("      exit code: {0}" -f $code) 'DarkGray'
    return [int]$code
}
$script:ignoredToolLines = 0


if (-not $ClientDir) {
    $saved = Join-Path $Root 'client_path.txt'
    if (Test-Path -LiteralPath $saved) {
        $exe = (Get-Content -LiteralPath $saved -TotalCount 1).Trim()
        if ($exe -and (Test-Path -LiteralPath $exe)) { $ClientDir = Split-Path -Parent $exe }
    }
}
if ((-not $ClientDir) -or (-not (Test-Path -LiteralPath $ClientDir))) {
    Log '  [!] Клиент не найден: укажите -ClientDir или client_path.txt' 'Yellow'
    exit 2
}
$ClientDir = (Resolve-Path -LiteralPath $ClientDir).Path.TrimEnd('\')

$tools = @{
    mapextractor    = Join-Path $ServerDir 'mapextractor.exe'
    vmap4extractor  = Join-Path $ServerDir 'vmap4extractor.exe'
    vmap4assembler  = Join-Path $ServerDir 'vmap4assembler.exe'
    mmaps_generator = Join-Path $ServerDir 'mmaps_generator.exe'
}
foreach ($k in @('mapextractor')) {
    if (-not (Test-Path -LiteralPath $tools[$k])) { Log "  [!] Нет $k.exe в папке server" 'Yellow'; exit 2 }
}

$copied = [ordered]@{ maps = 0; dbc = 0; cameras = 0; gt = 0; vmaps = 0; mmaps = 0 }
$deltaDbc = Join-Path $dataDir 'dbc_client_delta'
$changedDb2 = @()

function Copy-OnlyNew([string]$src, [string]$dst, [string]$filter, [string]$bucket) {
    if (-not (Test-Path -LiteralPath $src)) { return }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    foreach ($f in Get-ChildItem -LiteralPath $src -Filter $filter -File -Recurse -ErrorAction SilentlyContinue) {
        $target = Join-Path $dst $f.Name
        if (Test-Path -LiteralPath $target) {
            if ($bucket -eq 'dbc') {
                $existing = Get-Item -LiteralPath $target
                if ($existing.Length -ne $f.Length) {
                    $script:changedDb2 += $f.Name
                    if ($OverwriteDb2) {
                        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
                        $script:copied[$bucket]++
                    }
                    else {
                        New-Item -ItemType Directory -Force -Path $deltaDbc | Out-Null
                        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $deltaDbc $f.Name) -Force
                    }
                }
            }
            continue
        }
        Copy-Item -LiteralPath $f.FullName -Destination $target -Force
        $script:copied[$bucket]++
    }
}

# ---------- 1. maps + dbc + cameras + gt ----------
Log '  [*] Шаг 1/4: распаковка карт и db2 клиента во временную папку...' 'Cyan'
$code = Invoke-LfTool $tools.mapextractor @('-i', $ClientDir, '-o', $staging)
if ($code -ne 0) { Log "  [!] mapextractor вернул код $code (часть данных могла не извлечься)" 'Yellow' }

Copy-OnlyNew (Join-Path $staging 'maps')    (Join-Path $dataDir 'maps')    '*.map' 'maps'
Copy-OnlyNew (Join-Path $staging 'dbc')     (Join-Path $dataDir 'dbc')     '*.db2' 'dbc'
Copy-OnlyNew (Join-Path $staging 'dbc')     (Join-Path $dataDir 'dbc')     '*.dbc' 'dbc'
Copy-OnlyNew (Join-Path $staging 'Cameras') (Join-Path $dataDir 'Cameras') '*.*'   'cameras'
Copy-OnlyNew (Join-Path $staging 'gt')      (Join-Path $dataDir 'gt')      '*.*'   'gt'
Log ("      добавлено: карт {0}, db2 {1}, камер {2}" -f $copied.maps, $copied.dbc, $copied.cameras) 'Green'

# ---------- 2. vmaps ----------
if (-not $SkipVmaps -and (Test-Path -LiteralPath $tools.vmap4extractor)) {
    Log '  [*] Шаг 2/4: vmaps (может занять десятки минут)...' 'Cyan'
    Push-Location $staging
    try {
        # [LEGIONFORGE PATCH 2026-10] раньше здесь было
        #   & $tools.vmap4extractor -d $ClientDir 2>&1 | Out-Null
        # и ПЕРВОЕ ЖЕ сообщение в stderr ("Can't open World\Maps\test\test.wdt:
        # FILE_NOT_FOUND") роняло весь скрипт с NativeCommandError.
        New-Item -ItemType Directory -Force -Path (Join-Path $staging 'Buildings') | Out-Null
        $code = Invoke-LfTool $tools.vmap4extractor @('-d', $ClientDir)
        if ($code -ne 0) {
            Log ("  [!] vmap4extractor вернул код {0} - продолжаю, vmaps будут собраны из того, что извлечено" -f $code) 'Yellow'
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $staging 'vmaps') | Out-Null
        $code = Invoke-LfTool $tools.vmap4assembler @('Buildings', (Join-Path $staging 'vmaps'))
        if ($code -ne 0) { Log ("  [!] vmap4assembler вернул код {0}" -f $code) 'Yellow' }
    }
    catch {
        Log ("  [!] Шаг vmaps прерван: {0}" -f $_.Exception.Message) 'Yellow'
        Log '      Это не фатально: maps/dbc уже скопированы, vmaps можно добить позже.' 'DarkGray'
    }
    finally { Pop-Location }
    Copy-OnlyNew (Join-Path $staging 'vmaps') (Join-Path $dataDir 'vmaps') '*.vmtree' 'vmaps'
    Copy-OnlyNew (Join-Path $staging 'vmaps') (Join-Path $dataDir 'vmaps') '*.vmtile' 'vmaps'
    Log ("      добавлено vmap-файлов: {0}" -f $copied.vmaps) 'Green'
}
else { Log '  [*] Шаг 2/4: vmaps пропущены' 'DarkGray' }

# ---------- 3. mmaps для новых карт ----------
if ($MmapsMode -ne 'none' -and (Test-Path -LiteralPath $tools.mmaps_generator)) {
    Log '  [*] Шаг 3/4: навигационные мешки для новых карт...' 'Cyan'
    $mmapsDir = Join-Path $dataDir 'mmaps'
    New-Item -ItemType Directory -Force -Path $mmapsDir | Out-Null
    $haveMmap = @{}
    foreach ($f in Get-ChildItem -LiteralPath $mmapsDir -Filter '*.mmtile' -File -ErrorAction SilentlyContinue) {
        $n = 0; if ([int]::TryParse($f.Name.Substring(0, 4), [ref]$n)) { $haveMmap[$n] = $true }
    }
    $mapIds = @{}
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $dataDir 'maps') -Filter '*.map' -File -ErrorAction SilentlyContinue) {
        $n = 0; if ([int]::TryParse($f.Name.Substring(0, 4), [ref]$n)) { $mapIds[$n] = $true }
    }
    $targets = @()
    switch ($MmapsMode) {
        'new'      { $targets = @($mapIds.Keys | Where-Object { -not $haveMmap.ContainsKey($_) }) }
        'priority' { $targets = @(0, 1, 530, 571, 646, 870, 1116, 1220, 1669) | Where-Object { $mapIds.ContainsKey($_) } }
        'all'      { $targets = @($mapIds.Keys) }
    }
    $targets = $targets | Sort-Object
    Log ("      карт к обработке: {0}" -f $targets.Count) 'Gray'
    $failedMmaps = @()
    Push-Location $dataDir
    try {
        foreach ($id in $targets) {
            # [LEGIONFORGE PATCH 2026-10] считаем карту обработанной только при
            # нулевом коде возврата и логируем штатные предупреждения генератора.
            $code = Invoke-LfTool $tools.mmaps_generator @("$id", '--silent')
            if ($code -eq 0) { $copied.mmaps++ }
            else { $failedMmaps += $id }
        }
    }
    finally { Pop-Location }
}
else { Log '  [*] Шаг 3/4: mmaps пропущены' 'DarkGray' }

# ---------- 4. отчёт ----------
Log '  [*] Шаг 4/4: отчёт' 'Cyan'
$report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('s')
    ClientDir   = $ClientDir
    Copied      = $copied
    FailedMmaps = $failedMmaps
    IgnoredToolLines = $script:ignoredToolLines
    ChangedDb2  = ($changedDb2 | Sort-Object -Unique)
    OverwriteDb2 = [bool]$OverwriteDb2
    DeltaDbcDir = $deltaDbc
    LogFile     = $logFile
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportDir 'extract_delta.json') -Encoding UTF8

Log '' 
Log ("  [OK] Доизвлечение завершено: карт +{0}, db2 +{1}, vmaps +{2}, mmaps-карт {3}" -f $copied.maps, $copied.dbc, $copied.vmaps, $copied.mmaps) 'Green'
if ($changedDb2.Count -gt 0 -and -not $OverwriteDb2) {
    Log ("  [i] {0} db2 отличаются от серверных и сохранены в data\dbc_client_delta (не подменены)." -f ($changedDb2 | Sort-Object -Unique).Count) 'Yellow'
    Log '      Подмена допустима только после проверки tools\check_db2_build.ps1,' 'Yellow'
    Log '      иначе worldserver упадёт по ASSERT (LayoutHash/MaxId).' 'Yellow'
}
exit 0
