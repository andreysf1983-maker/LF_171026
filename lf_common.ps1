# LEGIONFORGE 7.3.5 - общие функции для build_server.ps1, prepare_release.ps1.
# Совместимо с Windows PowerShell 5.1 и PowerShell 7+.
# ВАЖНО: файл хранится в UTF-8 с BOM, иначе PowerShell 5.1 ломает кириллицу.
#
# Подключение:  . (Join-Path $PSScriptRoot 'lf_common.ps1')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch { }

$script:LfRoot = $PSScriptRoot
$script:LfTools = Join-Path $script:LfRoot 'tools'
$script:LfDownloads = Join-Path $script:LfTools 'downloads'
$script:LfLogWriter = $null

# ---- Портативный 7-Zip 25.01 (контрольные суммы проверены по реальным файлам) ----
# 7zr.exe из релиза 25.01 на GitHub неизменяем - его хэш закреплён.
# ВАЖНО: https://www.7-zip.org/a/7zr.exe всегда отдаёт САМУЮ НОВУЮ версию, поэтому её хэш меняется
# с каждым релизом. Раньше здесь стоял выдуманный хэш (ad4c82fa...), из-за чего установка
# прерывалась на шаге 1/4 ("SHA-256 не совпал") - см. ОШИБКА.txt и АУДИТ.md.
$script:Lf7zrSha256 = @(
    '27cbe3d5804ad09e90bbcaa916da0d5c3b0be9462d0e0fb6cb54be5ed9030875'   # GitHub ip7z/7zip, релиз 25.01
    '256feca8e274e5da655e2a284fabafd9f554365eb164862089dacd4e8276d282'   # www.7-zip.org/a/7zr.exe на момент аудита
)
$script:Lf7zInstallerSha256 = '78afa2a1c773caf3cf7edf62f857d2a8a5da55fb0fff5da416074c0d28b2b55f'

function Open-LfLog([string]$Path) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $script:LfLogWriter = New-Object System.IO.StreamWriter($Path, $true, $utf8)
    $script:LfLogWriter.AutoFlush = $true
    Write-LfLog ("==== {0} ====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
}

function Close-LfLog {
    if ($script:LfLogWriter) {
        try { $script:LfLogWriter.Flush(); $script:LfLogWriter.Dispose() } catch { }
        $script:LfLogWriter = $null
    }
}

function Write-LfLog([string]$Text) {
    if ($script:LfLogWriter) {
        try { $script:LfLogWriter.WriteLine(("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Text)) } catch { }
    }
}

function Write-LfStep([string]$Message) { Write-Host "  [*] $Message" -ForegroundColor Cyan; Write-LfLog "[*] $Message" }
function Write-LfOk([string]$Message) { Write-Host "  [OK] $Message" -ForegroundColor Green; Write-LfLog "[OK] $Message" }
function Write-LfWarn([string]$Message) { Write-Host "  [ВНИМАНИЕ] $Message" -ForegroundColor Yellow; Write-LfLog "[WARN] $Message" }
function Write-LfErr([string]$Message) { Write-Host "  [ОШИБКА] $Message" -ForegroundColor Red; Write-LfLog "[ERROR] $Message" }

function Test-LfAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LfFreeSpaceGB([string]$Path) {
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $drive = New-Object System.IO.DriveInfo([System.IO.Path]::GetPathRoot($full))
        return [math]::Round($drive.AvailableFreeSpace / 1GB, 1)
    }
    catch { return -1 }
}

function Get-LfRamGB {
    try { return [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) }
    catch { return 8 }
}

function Get-LfSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Format-LfSize([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} ГБ' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} МБ' -f ($Bytes / 1MB)) }
    return ('{0:N0} КБ' -f [math]::Max(1, $Bytes / 1KB))
}

# Дочерние программы (cmake, MSBuild, cl) пишут вывод в UTF-8. Если декодировать его как OEM-866,
# русские сообщения превращаются в "╨╕╨╖╨╝╨╡╨╜╨╡╨╜╨╕╨╡". На время вызова переключаем декодирование в UTF-8,
# а затем возвращаем прежнюю кодовую страницу: build_server.bat печатает текст уже в CP866.
$script:LfConsolePrev = $null
function Enter-LfUtf8Output {
    try {
        $script:LfConsolePrev = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
    catch { $script:LfConsolePrev = $null }
}

function Exit-LfUtf8Output {
    try { if ($script:LfConsolePrev) { [Console]::OutputEncoding = $script:LfConsolePrev } }
    catch { }
    $script:LfConsolePrev = $null
}

function Invoke-LfNative {
    # Запускает внешнюю программу, показывает вывод в консоли и пишет его в журнал.
    # Возвращает код выхода. В PowerShell 5.1 перенаправление stderr при
    # $ErrorActionPreference = 'Stop' прерывает скрипт, поэтому здесь 'Continue'.
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$Quiet
    )
    $ErrorActionPreference = 'Continue'
    Write-LfLog ("> `"{0}`" {1}" -f $FilePath, ($Arguments -join ' '))
    Enter-LfUtf8Output
    try {
        & $FilePath @Arguments 2>&1 | ForEach-Object {
            # Windows PowerShell 5.1 оборачивает каждую строку stderr в ErrorRecord; разворачиваем её,
            # иначе в журнал попадает "System.Management.Automation.RemoteException" вместо текста.
            $line = $null
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                if ($_.TargetObject -is [string] -and "$($_.TargetObject)".Trim()) { $line = [string]$_.TargetObject }
                elseif ($_.Exception -and "$($_.Exception.Message)".Trim()) { $line = [string]$_.Exception.Message }
                else { $line = $_.ToString() }
            }
            elseif ($_ -is [System.Exception]) { $line = [string]$_.Message }
            else { $line = "$_" }
            if ($null -eq $line) { $line = '' }
            if ($line -eq 'System.Management.Automation.RemoteException') { return }
            Write-LfLog $line
            if (-not $Quiet) { Write-Host $line }
        }
    }
    finally { Exit-LfUtf8Output }
    $code = $LASTEXITCODE
    Write-LfLog ("exit code: {0}" -f $code)
    return $code
}

# [LEGIONFORGE FIX 2026-10] Windows PowerShell 5.1 negotiates SSL3/TLS1.0 by default.
# Most CDNs (slproweb.com, boost.io, cmake.org, github) refused those handshakes, which
# surfaced to the user as "файл не скачивается". Force TLS 1.2 (+1.3 when available).
function Initialize-LfTls {
    try {
        $wanted = [Net.SecurityProtocolType]::Tls12
        try { $wanted = $wanted -bor [Net.SecurityProtocolType]::Tls13 } catch { }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $wanted
    }
    catch { }
    try { [Net.ServicePointManager]::DefaultConnectionLimit = 16 } catch { }
}
Initialize-LfTls

# slproweb.com (OpenSSL installers) returns 403 for the default PowerShell/curl agents.
# A normal browser UA + Referer makes the direct link work, e.g.
#   https://slproweb.com/download/Win64OpenSSL-3_5_9.exe
$Global:LfUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36'

function Get-LfReferer([string]$Url) {
    try {
        $u = [uri]$Url
        return ('{0}://{1}/' -f $u.Scheme, $u.Host)
    }
    catch { return $null }
}

function Invoke-LfDownload {
    # Загрузка с несколькими зеркалами, повторами, докачкой и проверкой SHA-256.
    #   -Sha256  допускает СПИСОК хэшей: подходит любой из них.
    #   Если хэш не совпал, тот же адрес повторно не качается (результат был бы тем же) - берётся следующее зеркало.
    #   LEGIONFORGE_SKIP_HASH=1 отключает проверку хэша (для файлов, положенных вручную; хэш в журнале остаётся).
    param(
        [Parameter(Mandatory = $true)][string[]]$Urls,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string[]]$Sha256 = @(),
        [long]$MinBytes = 1024
    )
    $expected = @($Sha256 | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
    $skipHash = ($env:LEGIONFORGE_SKIP_HASH -eq '1')
    $name = Split-Path -Leaf $Destination
    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    if (Test-Path -LiteralPath $Destination) {
        $okExisting = (Get-Item -LiteralPath $Destination).Length -ge $MinBytes
        if ($okExisting -and $expected.Count -gt 0) {
            $existingHash = Get-LfSha256 $Destination
            if ($expected -notcontains $existingHash) {
                if ($skipHash) { Write-LfWarn "Хэш файла $name не проверяется (LEGIONFORGE_SKIP_HASH=1): $existingHash" }
                else { $okExisting = $false }
            }
        }
        if ($okExisting) { Write-LfOk "Уже загружено: $name"; return }
        Remove-Item -LiteralPath $Destination -Force
    }

    $part = "$Destination.part"
    $curl = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $failures = New-Object System.Collections.Generic.List[string]

    foreach ($url in $Urls) {
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            Write-LfStep "Загрузка $name (попытка $attempt): $url"
            try {
                $referer = Get-LfReferer $url
                if ($curl) {
                    $ErrorActionPreference = 'Continue'
                    $curlArgs = @('--fail', '--location', '--retry', '5', '--retry-delay', '3',
                        '--connect-timeout', '30', '--max-time', '7200',
                        '--user-agent', $Global:LfUserAgent,
                        '--tlsv1.2', '--output', $part)
                    if ($referer) { $curlArgs += @('--referer', $referer) }
                    if ((Test-Path -LiteralPath $part) -and $attempt -eq 1) { $curlArgs += @('--continue-at', '-') }
                    $curlArgs += $url
                    & $curl.Source @curlArgs
                    $code = $LASTEXITCODE
                    $ErrorActionPreference = 'Stop'
                    if ($code -ne 0) { throw "curl завершился с кодом $code ($url)" }
                }
                else {
                    Initialize-LfTls
                    $headers = @{ 'User-Agent' = $Global:LfUserAgent; 'Accept' = '*/*' }
                    if ($referer) { $headers['Referer'] = $referer }
                    $oldProgress = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    try { Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing -Headers $headers -TimeoutSec 7200 }
                    finally { $ProgressPreference = $oldProgress }
                }
                if (-not (Test-Path -LiteralPath $part)) { throw 'файл не появился после загрузки' }
                $size = (Get-Item -LiteralPath $part).Length
                if ($size -lt $MinBytes) { throw "слишком маленький файл ($size байт) - вероятно, страница ошибки вместо архива" }
                # [LEGIONFORGE FIX] Cloudflare/403 заглушки приходят как HTML с кодом 200.
                $head = ''
                try {
                    $peek = [byte[]](Get-Content -LiteralPath $part -Encoding Byte -TotalCount 512 -ErrorAction SilentlyContinue)
                    if ($peek) { $head = [System.Text.Encoding]::ASCII.GetString($peek) }
                }
                catch { }
                if ($head -match '(?i)^\s*(<!DOCTYPE|<html|<\?xml)') {
                    throw 'сервер вернул HTML-страницу вместо файла (блокировка по User-Agent или устаревшая ссылка)'
                }
                if ($expected.Count -gt 0) {
                    $actual = Get-LfSha256 $part
                    if ($expected -contains $actual) { Write-LfOk "Контрольная сумма SHA-256 совпала: $name" }
                    elseif ($skipHash) { Write-LfWarn "SHA-256 не совпал, но проверка отключена (LEGIONFORGE_SKIP_HASH=1): $actual" }
                    else {
                        $failures.Add("$url -> SHA-256 не совпал (ожидался $($expected -join ' или '), получен $actual)")
                        Write-LfWarn "SHA-256 не совпал для $url (получен $actual) - пробую следующее зеркало."
                        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
                        break
                    }
                }
                Move-Item -LiteralPath $part -Destination $Destination -Force
                Write-LfOk ("Загружено: {0} ({1})" -f $name, (Format-LfSize (Get-Item -LiteralPath $Destination).Length))
                return
            }
            catch {
                $ErrorActionPreference = 'Stop'
                $failures.Add("$url -> $($_.Exception.Message)")
                Write-LfWarn $_.Exception.Message
                Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
            }
        }
    }
    throw ("Не удалось загрузить $name. Проверьте интернет/антивирус или положите файл вручную в: $Destination" +
        "`n  (для файла, положенного вручную, задайте set LEGIONFORGE_SKIP_HASH=1 перед запуском)`n  " + ($failures -join "`n  "))
}

function Get-LfSevenZip {
    # Возвращает путь к 7z.exe (ZIP, 7z, RAR). Порядок поиска:
    #   1) портативный tools\7zip  2) уже установленный в системе 7-Zip  3) загрузка 7-Zip 25.01 в tools\7zip.
    $target = Join-Path $script:LfTools '7zip'
    $exe = Join-Path $target '7z.exe'
    if (Test-Path -LiteralPath $exe) { return $exe }

    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
        if (-not $base) { continue }
        $system = Join-Path $base '7-Zip\7z.exe'
        if (Test-Path -LiteralPath $system) { Write-LfOk "Найден установленный 7-Zip: $system"; return $system }
    }

    Write-LfStep 'Подготовка портативного 7-Zip 25.01 в tools\7zip...'
    $sevenR = Join-Path $script:LfDownloads '7zr.exe'
    $installer = Join-Path $script:LfDownloads '7z2501-x64.exe'
    # Сначала GitHub (неизменяемый релиз 25.01), затем сайт 7-zip.org.
    Invoke-LfDownload -Urls @('https://github.com/ip7z/7zip/releases/download/25.01/7zr.exe', 'https://www.7-zip.org/a/7zr.exe') `
        -Destination $sevenR -Sha256 $script:Lf7zrSha256 -MinBytes 100000
    Invoke-LfDownload -Urls @('https://github.com/ip7z/7zip/releases/download/25.01/7z2501-x64.exe', 'https://www.7-zip.org/a/7z2501-x64.exe') `
        -Destination $installer -Sha256 $script:Lf7zInstallerSha256 -MinBytes 500000

    New-Item -ItemType Directory -Force -Path $target | Out-Null
    # Установщик 7-Zip - это 7z-архив с SFX-заглушкой: внутри 7z.exe и 7z.dll, 7zr.exe его распаковывает.
    $null = Invoke-LfNative -FilePath $sevenR -Arguments @('x', '-y', "-o$target", $installer) -Quiet
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-LfWarn 'Распаковка установщика 7-Zip не удалась, пробую тихую установку в tools\7zip...'
        $p = Start-Process -FilePath $installer -ArgumentList "/S /D=$target" -Wait -PassThru
        Write-LfLog "7-Zip installer exit code: $($p.ExitCode)"
    }
    if (-not (Test-Path -LiteralPath $exe)) { throw "Не удалось подготовить 7-Zip: $exe" }
    Write-LfOk "7-Zip готов: $exe"
    return $exe
}

function Expand-LfArchive([string]$Archive, [string]$Destination) {
    # Распаковка ZIP/7z/RAR через портативный 7-Zip. Код 1 = предупреждения (допустимо).
    $sevenZip = Get-LfSevenZip
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $code = Invoke-LfNative -FilePath $sevenZip -Arguments @('x', '-y', '-bso0', '-bsp1', "-o$Destination", $Archive)
    if ($code -gt 1) { throw "7-Zip не смог распаковать $Archive (код $code)" }
}

function New-LfZip([string]$ZipPath, [string[]]$Items, [string]$WorkDir, [string[]]$Exclude = @()) {
    # Создание ZIP через 7-Zip (быстро, без ограничения 2 ГБ у Compress-Archive в PowerShell 5.1).
    $sevenZip = Get-LfSevenZip
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    $arguments = @('a', '-tzip', '-mx=5', '-y', '-bso0', '-bsp1', $ZipPath) + $Items
    foreach ($pattern in $Exclude) { $arguments += "-xr!$pattern" }
    Push-Location -LiteralPath $WorkDir
    try { $code = Invoke-LfNative -FilePath $sevenZip -Arguments $arguments }
    finally { Pop-Location }
    if ($code -gt 1) { throw "7-Zip не смог создать архив $ZipPath (код $code)" }
    if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Архив не создан: $ZipPath" }
}
