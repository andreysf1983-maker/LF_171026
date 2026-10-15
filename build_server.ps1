# LEGIONFORGE 7.3.5 - полностью автоматическая компиляция сервера.
# Совместимо с Windows PowerShell 5.1 и PowerShell 7+. Файл хранится в UTF-8 с BOM.
#
# Что делает (каждый шаг пропускается, если уже выполнен):
#   1. Проверяет права, место на диске, память.
#   2. Готовит портативные инструменты в tools\:
#        7zip, cmake, vsbuildtools (MSVC 2022 + Windows SDK), boost_X_Y_Z, openssl, mysql\server (заголовки + libmysql).
#   3. Генерирует проект CMake в папке build\.
#   4. Компилирует worldserver, bnetserver и утилиты извлечения карт
#      (mapextractor, vmap4extractor, vmap4assembler, mmaps_generator, connection_patcher).
#      При нехватке памяти / сбое предкомпилированных заголовков повторяет сборку в щадящем режиме.
#   5. Копирует .exe и нужные .dll в server\ и пишет server\build_info.txt.
#
# Параметры:
#   -Auto            без вопросов (вызов из setup.bat)
#   -Clean           удалить папку build\ и собрать с нуля
#   -PrepareOnly     только скачать/установить инструменты, без компиляции
#   -NoPch           собирать без предкомпилированных заголовков (медленнее, но надёжнее)
#   -ForceBuildTools всегда использовать портативные Build Tools из tools\vsbuildtools
#   -Jobs N          число параллельных проектов MSBuild (по умолчанию - по объёму ОЗУ)
#
# Переменные окружения (необязательно):
#   LEGIONFORGE_BOOST_VERSION   (по умолчанию 1.86.0)
#   LEGIONFORGE_CMAKE_VERSION   (по умолчанию 3.31.8)
#   LEGIONFORGE_OPENSSL_BRANCH  (по умолчанию 3.5, допускается любая 3.x)
#   LEGIONFORGE_NOPCH=1, LEGIONFORGE_FORCE_BUILDTOOLS=1
[CmdletBinding()]
param(
    [switch]$Auto,
    [switch]$Clean,
    [switch]$PrepareOnly,
    [switch]$NoPch,
    [switch]$ForceBuildTools,
    [int]$Jobs = 0
)

. (Join-Path $PSScriptRoot 'lf_common.ps1')

$Root = $PSScriptRoot
$CoreDir = Join-Path $Root 'core'
$BuildDir = Join-Path $Root 'build'
$ServerDir = Join-Path $Root 'server'
$ToolsDir = Join-Path $Root 'tools'
$DownloadsDir = Join-Path $ToolsDir 'downloads'
$LogFile = Join-Path $Root 'build_log.txt'

$CMakeVersion = if ($env:LEGIONFORGE_CMAKE_VERSION) { $env:LEGIONFORGE_CMAKE_VERSION } else { '3.31.8' }
$BoostVersion = if ($env:LEGIONFORGE_BOOST_VERSION) { $env:LEGIONFORGE_BOOST_VERSION } else { '1.86.0' }
$OpenSslBranch = if ($env:LEGIONFORGE_OPENSSL_BRANCH) { $env:LEGIONFORGE_OPENSSL_BRANCH } else { '3.5' }
if ($env:LEGIONFORGE_NOPCH -eq '1') { $NoPch = $true }
if ($env:LEGIONFORGE_FORCE_BUILDTOOLS -eq '1') { $ForceBuildTools = $true }

$RequiredExe = @('worldserver', 'bnetserver', 'mapextractor', 'vmap4extractor', 'vmap4assembler')
$OptionalExe = @('mmaps_generator', 'connection_patcher')

function ConvertTo-CMakePath([string]$Path) { return [System.IO.Path]::GetFullPath($Path).Replace('\', '/') }

# ------------------------------------------------------------------ CMake
function Initialize-CMake {
    $dir = Join-Path $ToolsDir 'cmake'
    $exe = Join-Path $dir 'bin\cmake.exe'
    if (Test-Path -LiteralPath $exe) { Write-LfOk "CMake уже подготовлен: tools\cmake"; return $exe }

    $zipName = "cmake-$CMakeVersion-windows-x86_64.zip"
    $base = "https://github.com/Kitware/CMake/releases/download/v$CMakeVersion"
    $sha = ''
    try {
        $content = (Invoke-WebRequest -Uri "$base/cmake-$CMakeVersion-SHA-256.txt" -UseBasicParsing).Content
        if ($content -is [byte[]]) { $content = [System.Text.Encoding]::ASCII.GetString($content) }
        foreach ($line in ($content -split "`n")) {
            if ($line -match ('^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($zipName) + '\s*$')) { $sha = $Matches[1]; break }
        }
    }
    catch { Write-LfWarn "Не удалось получить официальный SHA-256 для CMake: $($_.Exception.Message)" }

    $zip = Join-Path $DownloadsDir $zipName
    Invoke-LfDownload -Urls @("$base/$zipName") -Destination $zip -Sha256 $sha -MinBytes 10MB
    $extract = Join-Path $DownloadsDir 'cmake-extract'
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    Expand-LfArchive -Archive $zip -Destination $extract
    $inner = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    if (-not $inner -or -not (Test-Path -LiteralPath (Join-Path $inner.FullName 'bin\cmake.exe'))) { throw 'В архиве CMake не найден bin\cmake.exe' }
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    Move-Item -LiteralPath $inner.FullName -Destination $dir
    Remove-Item -LiteralPath $extract, $zip -Recurse -Force -ErrorAction SilentlyContinue
    Write-LfOk "CMake $CMakeVersion готов: tools\cmake"
    return $exe
}

# ------------------------------------------------------------------ Visual Studio / Build Tools
function Find-VisualStudio([switch]$OnlyPortable) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $ErrorActionPreference = 'Continue'
    $raw = & $vswhere -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json 2>$null
    $ErrorActionPreference = 'Stop'
    if (-not $raw) { return $null }
    try { $parsed = ConvertFrom-Json -InputObject ($raw -join "`n") } catch { return $null }
    $instances = @($parsed) | Where-Object { $_ -and $_.installationPath -and (Test-Path -LiteralPath $_.installationPath) }
    if ($OnlyPortable) {
        $portable = [System.IO.Path]::GetFullPath((Join-Path $ToolsDir 'vsbuildtools')).TrimEnd('\')
        $instances = @($instances) | Where-Object { [System.IO.Path]::GetFullPath($_.installationPath).TrimEnd('\') -ieq $portable }
    }
    return (@($instances) | Sort-Object { [version]($_.installationVersion) } -Descending | Select-Object -First 1)
}

function Get-VsInstallerHint([int]$Code) {
    switch ($Code) {
        1602 { return 'установка отменена пользователем' }
        1618 { return 'уже идёт другая установка (Windows Update / MSI) - дождитесь её окончания' }
        1641 { return 'установщик инициировал перезагрузку - перезагрузите ПК и запустите скрипт снова' }
        740 { return 'нужны права администратора' }
        5007 { return 'компьютер не соответствует требованиям Visual Studio 2022 (нужна Windows 10 1909+ x64)' }
        8006 { return 'закройте все окна Visual Studio / Visual Studio Installer и повторите' }
        default { return 'смотрите журналы установщика %TEMP%\dd_bootstrapper_*.log и %TEMP%\dd_setup_*.log' }
    }
}

function Initialize-VisualStudio {
    if (-not $ForceBuildTools) {
        $vs = Find-VisualStudio
        if ($vs) { Write-LfOk ("Найден компилятор: {0} {1}" -f $vs.displayName, $vs.installationVersion); return $vs }
    }
    $vs = Find-VisualStudio -OnlyPortable
    if ($vs) { Write-LfOk ("Портативные Build Tools уже установлены: tools\vsbuildtools ({0})" -f $vs.installationVersion); return $vs }

    $installPath = Join-Path $ToolsDir 'vsbuildtools'
    if ((Test-Path -LiteralPath $installPath) -and @(Get-ChildItem -LiteralPath $installPath -Force -ErrorAction SilentlyContinue).Count -gt 0) {
        $backup = "$installPath.broken-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-LfWarn "Остатки прерванной установки Build Tools перемещены в $backup"
        Move-Item -LiteralPath $installPath -Destination $backup
    }
    $free = Get-LfFreeSpaceGB $ToolsDir
    if ($free -ge 0 -and $free -lt 12) { throw "Для Visual Studio Build Tools нужно не менее 12 ГБ, свободно $free ГБ." }

    $bootstrapper = Join-Path $DownloadsDir 'vs_BuildTools.exe'
    Invoke-LfDownload -Urls @('https://aka.ms/vs/17/release/vs_BuildTools.exe') -Destination $bootstrapper -MinBytes 1MB

    Write-LfStep 'Установка Visual Studio 2022 Build Tools (MSVC v143 + Windows SDK) в tools\vsbuildtools'
    Write-LfStep 'Это официальный бесплатный компилятор Microsoft: загрузка ~2-3 ГБ, установка 10-40 минут.'
    Write-LfStep 'Появится окно установщика с прогрессом - ничего нажимать не нужно, не закрывайте его.'
    $arguments = @('--passive', '--wait', '--norestart', '--nocache',
        '--installPath', ('"{0}"' -f $installPath),
        '--add', 'Microsoft.VisualStudio.Workload.VCTools',
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '--includeRecommended') -join ' '
    Write-LfLog "vs_BuildTools.exe $arguments"
    $process = Start-Process -FilePath $bootstrapper -ArgumentList $arguments -Wait -PassThru
    $code = [int]$process.ExitCode
    Write-LfLog "vs_BuildTools exit code: $code"
    if ($code -eq 3010) { Write-LfWarn 'Build Tools установлены; Windows просит перезагрузку. Если сборка упадёт - перезагрузите ПК и запустите скрипт снова.' }
    elseif ($code -ne 0) { throw ("Установка Build Tools завершилась с кодом {0}: {1}" -f $code, (Get-VsInstallerHint $code)) }

    $vs = Find-VisualStudio -OnlyPortable
    if (-not $vs) { $vs = Find-VisualStudio }
    if (-not $vs) { throw 'Build Tools установлены, но компилятор MSVC не обнаружен (vswhere). Перезагрузите ПК и запустите скрипт снова.' }
    Write-LfOk ("Компилятор готов: {0} {1}" -f $vs.displayName, $vs.installationVersion)
    return $vs
}

# ------------------------------------------------------------------ Boost
function Initialize-Boost {
    $u = $BoostVersion.Replace('.', '_')
    $dir = Join-Path $ToolsDir "boost_$u"
    $libDir = Join-Path $dir 'lib64-msvc-14.3'
    $ready = (Test-Path -LiteralPath (Join-Path $dir 'boost\version.hpp')) -and (Test-Path -LiteralPath $libDir)
    if (-not $ready) {
        $free = Get-LfFreeSpaceGB $ToolsDir
        if ($free -ge 0 -and $free -lt 6) { throw "Для Boost нужно не менее 6 ГБ, свободно $free ГБ." }
        $installerName = "boost_$u-msvc-14.3-64.exe"
        $installer = Join-Path $DownloadsDir $installerName
        Invoke-LfDownload -Urls @(
            "https://archives.boost.io/release/$BoostVersion/binaries/$installerName",
            "https://downloads.sourceforge.net/project/boost/boost-binaries/$BoostVersion/$installerName"
        ) -Destination $installer -MinBytes 50MB
        Write-LfStep "Установка Boost $BoostVersion (готовые библиотеки MSVC 14.3) в tools\boost_$u - 3-10 минут..."
        $process = Start-Process -FilePath $installer -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="{0}"' -f $dir) -Wait -PassThru
        Write-LfLog "Boost installer exit code: $($process.ExitCode)"
        if ($process.ExitCode -ne 0) { throw "Установщик Boost завершился с кодом $($process.ExitCode). Удалите $installer и повторите." }
        if (-not ((Test-Path -LiteralPath (Join-Path $dir 'boost\version.hpp')) -and (Test-Path -LiteralPath $libDir))) {
            throw "После установки Boost не найдены $dir\boost\version.hpp и $libDir"
        }
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        Write-LfOk "Boost $BoostVersion установлен."
    }
    else { Write-LfOk "Boost $BoostVersion уже подготовлен: tools\boost_$u" }
    $config = Get-ChildItem -LiteralPath (Join-Path $libDir 'cmake') -Filter 'BoostConfig.cmake' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $configDir = $null
    if ($config) { $configDir = $config.DirectoryName }
    return [pscustomobject]@{ Root = $dir; LibDir = $libDir; ConfigDir = $configDir }
}

# ------------------------------------------------------------------ OpenSSL 3.x
function Find-OfflineOpenSslInstaller {
    $candidates = @()
    foreach ($folder in @((Join-Path $Root 'setup_tmp'), $DownloadsDir, $Root)) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $folder -File -Filter 'Win64OpenSSL-3_*.exe' -ErrorAction SilentlyContinue)) {
            if ($f.Name -match '^Win64OpenSSL-(3_\d+_\d+)\.exe$') {
                $candidates += [pscustomobject]@{ File = $f; Version = [version]($Matches[1] -replace '_', '.') }
            }
        }
    }
    # Prefer the requested branch, then any compatible OpenSSL 3.x already on disk.
    $ordered = @($candidates | Sort-Object @{ Expression = { if ("$($_.Version)" -like "$OpenSslBranch.*") { 0 } else { 1 } } },
        @{ Expression = { $_.Version }; Descending = $true })
    foreach ($candidate in $ordered) {
        $f = $candidate.File
        if ($f.Length -lt 10MB) { Write-LfWarn "Локальный OpenSSL слишком мал: $($f.FullName)"; continue }
        $stream = [System.IO.File]::OpenRead($f.FullName)
        try { $validPe = ($stream.ReadByte() -eq 0x4D -and $stream.ReadByte() -eq 0x5A) }
        finally { $stream.Dispose() }
        if (-not $validPe) { Write-LfWarn "Локальный установщик не является PE-файлом: $($f.FullName)"; continue }
        $signed = $false
        try { $signed = (Get-AuthenticodeSignature -LiteralPath $f.FullName).Status -eq 'Valid' }
        catch { Write-LfWarn "Не удалось проверить подпись $($f.Name): $($_.Exception.Message)" }
        $pinned = $false
        $expected = $env:LEGIONFORGE_OPENSSL_SHA256
        if ($expected -and $expected -match '^[a-fA-F0-9]{64}$') {
            $pinned = (Get-LfSha256 $f.FullName) -eq $expected.ToLowerInvariant()
        }
        if (-not $signed -and -not $pinned) {
            Write-LfWarn "Пропускаю $($f.FullName): подпись недействительна. Для доверенного офлайн-файла укажите LEGIONFORGE_OPENSSL_SHA256."
            continue
        }
        Write-LfOk "Найден локальный OpenSSL $($candidate.Version): $($f.FullName) (подпись/SHA-256 проверены)."
        return $f.FullName
    }
    return $null
}

function Find-OpenSslLayout([string]$Dir) {
    $include = Join-Path $Dir 'include'
    if (-not (Test-Path -LiteralPath (Join-Path $include 'openssl\ssl.h'))) { return $null }
    $libs = @(Get-ChildItem -LiteralPath (Join-Path $Dir 'lib') -Recurse -Filter '*.lib' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'libssl.lib' -or $_.Name -ieq 'libcrypto.lib' })
    $pick = {
        param($name)
        $all = @($libs | Where-Object { $_.Name -ieq $name })
        $best = $all | Where-Object { $_.FullName -match '\\x64\\MD\\' } | Select-Object -First 1
        if (-not $best) { $best = $all | Where-Object { $_.FullName -notmatch 'MDd|MTd|\\MT\\|static' } | Select-Object -First 1 }
        if (-not $best) { $best = $all | Select-Object -First 1 }
        return $best
    }
    $ssl = & $pick 'libssl.lib'
    $crypto = & $pick 'libcrypto.lib'
    if (-not $ssl -or -not $crypto) { return $null }
    return [pscustomobject]@{ Root = $Dir; Include = $include; Ssl = $ssl.FullName; Crypto = $crypto.FullName }
}

function Initialize-OpenSsl {
    $dir = Join-Path $ToolsDir 'openssl'
    $layout = Find-OpenSslLayout $dir
    if ($layout) { Write-LfOk 'OpenSSL уже подготовлен: tools\openssl'; return $layout }

    # Use an installer supplied in setup_tmp BEFORE fetching the online index.
    # Keep the original offline file so a failed build can be restarted without network.
    $offlineInstaller = Find-OfflineOpenSslInstaller
    if ($offlineInstaller) {
        Write-LfStep "Установка OpenSSL из локального файла $offlineInstaller в tools\openssl..."
        $process = Start-Process -FilePath $offlineInstaller -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="{0}"' -f $dir) -Wait -PassThru
        Write-LfLog "Local OpenSSL installer exit code: $($process.ExitCode)"
        if ($process.ExitCode -ne 0) { throw "Локальный установщик OpenSSL завершился с кодом $($process.ExitCode)." }
        $layout = Find-OpenSslLayout $dir
        if (-not $layout) { throw "После локальной установки OpenSSL не найдены include\openssl\ssl.h и libssl.lib/libcrypto.lib в $dir" }
        Write-LfOk 'Локальная установка OpenSSL завершена (интернет не потребовался).'
        return $layout
    }

    Write-LfStep 'Локальный установщик не найден; поиск OpenSSL 3.x в сети...'
    Write-LfStep 'Поиск актуального установщика OpenSSL 3.x (индекс slproweb с контрольными суммами)...'

    # [LEGIONFORGE FIX 2026-10] Загрузка OpenSSL падала по двум причинам:
    #   1) индекс opensslhashes мог быть недоступен -> исключение и обрыв всей сборки;
    #   2) slproweb.com отдаёт 403 на стандартный User-Agent PowerShell/curl,
    #      хотя прямая ссылка https://slproweb.com/download/Win64OpenSSL-3_5_9.exe рабочая.
    # Теперь: индекс не обязателен (есть закреплённый резерв), а у каждого файла
    # несколько зеркал. User-Agent браузера выставляется в Invoke-LfDownload.
    $candidates = @()
    try {
        $raw = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/slproweb/opensslhashes/master/win32_openssl_hashes.json' -UseBasicParsing -Headers @{ 'User-Agent' = $Global:LfUserAgent } -TimeoutSec 60).Content
        if ($raw -is [byte[]]) { $raw = [System.Text.Encoding]::UTF8.GetString($raw) }
        $index = ConvertFrom-Json -InputObject $raw
        foreach ($property in $index.files.PSObject.Properties) {
            $file = $property.Value
            if ($file.arch -eq 'INTEL' -and [int]$file.bits -eq 64 -and -not $file.light -and $file.installer -eq 'exe' -and "$($file.basever)" -like '3.*') {
                $candidates += [pscustomobject]@{ Name = $property.Name; Version = [version]"$($file.basever)"; Url = $file.url; Sha256 = @("$($file.sha256)") }
            }
        }
    }
    catch {
        Write-LfWarn "Индекс slproweb недоступен ($($_.Exception.Message)) - использую закреплённый список версий."
    }

    if (-not $candidates -or $candidates.Count -eq 0) {
        # Резервный список: проверенные прямые ссылки (хэш не фиксируем, так как
        # slproweb перевыпускает инсталляторы в рамках одной версии).
        foreach ($v in @('3_5_9', '3_4_8', '3_3_7', '3_0_22')) {
            $n = "Win64OpenSSL-$v.exe"
            $candidates += [pscustomobject]@{
                Name    = $n
                Version = [version]($v -replace '_', '.')
                Url     = "https://slproweb.com/download/$n"
                Sha256  = @()
            }
        }
    }

    # Try the preferred branch first, then other available 3.x versions. An
    # unavailable version must not prevent installation from a working mirror.
    $orderedCandidates = @($candidates | Sort-Object @{ Expression = { if ("$($_.Version)" -like "$OpenSslBranch.*") { 0 } else { 1 } } },
        @{ Expression = { $_.Version }; Descending = $true })
    if ($orderedCandidates.Count -eq 0) { throw 'Не удалось определить установщик OpenSSL 3.x для Win64.' }
    $chosen = $null
    $installer = $null
    $downloadErrors = @()
    foreach ($candidate in $orderedCandidates) {
        $mirrors = New-Object System.Collections.Generic.List[string]
        if ($candidate.Url) { $mirrors.Add([string]$candidate.Url) }
        $direct = "https://slproweb.com/download/$($candidate.Name)"
        if (-not $mirrors.Contains($direct)) { $mirrors.Add($direct) }
        $path = Join-Path $DownloadsDir $candidate.Name
        try {
            Invoke-LfDownload -Urls $mirrors.ToArray() -Destination $path -Sha256 $candidate.Sha256 -MinBytes 10MB
            $validSignature = (Get-AuthenticodeSignature -LiteralPath $path).Status -eq 'Valid'
            $trustedHash = @($candidate.Sha256 | Where-Object { $_ }) -contains (Get-LfSha256 $path)
            if (-not $validSignature -and -not $trustedHash) { throw "У $($candidate.Name) нет действительной подписи или подтверждённого SHA-256." }
            $chosen = $candidate
            $installer = $path
            break
        }
        catch {
            $downloadErrors += "$($candidate.Name): $($_.Exception.Message)"
            Write-LfWarn "OpenSSL $($candidate.Version) недоступен; пробую следующую версию. $($_.Exception.Message)"
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $chosen) { throw ("Не удалось подготовить OpenSSL. Укажите подписанный Win64OpenSSL-3_*.exe в setup_tmp. " + ($downloadErrors -join '; ')) }
    Write-LfStep "Установка OpenSSL $($chosen.Version) в tools\openssl..."
    $process = Start-Process -FilePath $installer -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="{0}"' -f $dir) -Wait -PassThru
    Write-LfLog "OpenSSL installer exit code: $($process.ExitCode)"
    if ($process.ExitCode -ne 0) { throw "Установщик OpenSSL завершился с кодом $($process.ExitCode)." }
    $layout = Find-OpenSslLayout $dir
    if (-not $layout) { throw "После установки OpenSSL не найдены include\openssl\ssl.h и libssl.lib/libcrypto.lib в $dir" }
    Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    Write-LfOk "OpenSSL $($chosen.Version) установлен."
    return $layout
}

# ------------------------------------------------------------------ MySQL (заголовки + libmysql)
function Find-MySqlDev([string]$ServerRoot) {
    if (-not $ServerRoot) { return $null }
    $include = Join-Path $ServerRoot 'include'
    $lib = Join-Path $ServerRoot 'lib\libmysql.lib'
    $dll = Join-Path $ServerRoot 'lib\libmysql.dll'
    if ((Test-Path -LiteralPath (Join-Path $include 'mysql.h')) -and (Test-Path -LiteralPath $lib)) {
        return [pscustomobject]@{ Root = $ServerRoot; Include = $include; Library = $lib; Dll = $dll }
    }
    return $null
}

function Initialize-MySqlDev {
    $portable = Join-Path $ToolsDir 'mysql\server'
    $dev = Find-MySqlDev $portable
    if (-not $dev) {
        Write-LfStep 'Заголовки MySQL ещё не подготовлены - запускаю upload_tools.ps1 (portable MySQL 8.0)...'
        $code = Invoke-LfNative -FilePath 'powershell.exe' -Arguments @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'upload_tools.ps1'), '-PrepareOnly')
        if ($code -ne 0) { Write-LfWarn "upload_tools.ps1 завершился с кодом $code" }
        $dev = Find-MySqlDev $portable
    }
    if (-not $dev) {
        foreach ($candidate in @(Get-ChildItem -Path 'C:\Program Files\MySQL\MySQL Server 8.*' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
            $dev = Find-MySqlDev $candidate.FullName
            if ($dev) { break }
        }
    }
    if (-not $dev) { throw 'Не найдены заголовки MySQL (include\mysql.h и lib\libmysql.lib). Запустите upload_tools.bat от имени администратора.' }
    Write-LfOk "MySQL для сборки: $($dev.Root)"
    return $dev
}

# ------------------------------------------------------------------ Сборка
function Get-DefaultJobs {
    $cores = [Environment]::ProcessorCount
    $ram = Get-LfRamGB
    $byRam = [math]::Floor($ram / 4)
    return [int][math]::Max(1, [math]::Min($cores, $byRam))
}

function Invoke-CMakeConfigure($CMake, $Vs, $Boost, $Ssl, $MySql, [bool]$UsePch) {
    $arguments = @(
        '-S', (ConvertTo-CMakePath $CoreDir), '-B', (ConvertTo-CMakePath $BuildDir),
        '-G', 'Visual Studio 17 2022', '-A', 'x64',
        "-DCMAKE_GENERATOR_INSTANCE=$(ConvertTo-CMakePath $Vs.installationPath)",
        "-DBOOST_ROOT=$(ConvertTo-CMakePath $Boost.Root)",
        "-DBOOST_LIBRARYDIR=$(ConvertTo-CMakePath $Boost.LibDir)",
        '-DBoost_COMPILER=-vc143', '-DBoost_NO_SYSTEM_PATHS=ON',
        "-DOPENSSL_ROOT_DIR=$(ConvertTo-CMakePath $Ssl.Root)",
        "-DOPENSSL_INCLUDE_DIR=$(ConvertTo-CMakePath $Ssl.Include)",
        "-DOPENSSL_SSL_LIBRARY=$(ConvertTo-CMakePath $Ssl.Ssl)",
        "-DOPENSSL_CRYPTO_LIBRARY=$(ConvertTo-CMakePath $Ssl.Crypto)",
        "-DMYSQL_INCLUDE_DIR=$(ConvertTo-CMakePath $MySql.Include)",
        "-DMYSQL_LIBRARY=$(ConvertTo-CMakePath $MySql.Library)",
        '-DSERVERS=1', '-DTOOLS=1', '-DSCRIPTS=static', '-DWITHOUT_GIT=1', '-DWITH_WARNINGS=0', '-Wno-dev'
    )
    if ($Boost.ConfigDir) { $arguments += "-DBoost_DIR=$(ConvertTo-CMakePath $Boost.ConfigDir)" }
    if ($UsePch) { $arguments += @('-DUSE_COREPCH=1', '-DUSE_SCRIPTPCH=1', '-DNOPCH=0') }
    else { $arguments += @('-DUSE_COREPCH=0', '-DUSE_SCRIPTPCH=0', '-DNOPCH=1') }
    return (Invoke-LfNative -FilePath $CMake -Arguments $arguments)
}

function Invoke-CMakeBuild([string]$CMake, [int]$ParallelJobs) {
    $arguments = @('--build', (ConvertTo-CMakePath $BuildDir), '--config', 'Release', '--parallel', "$ParallelJobs",
        '--', '/nologo', '/v:minimal', '/consoleloggerparameters:Summary;ForceNoAlign')
    $script:BuildErrors = New-Object System.Collections.Generic.List[string]
    $started = Get-Date
    $counter = 0
    Write-LfLog ("> cmake {0}" -f ($arguments -join ' '))
    $ErrorActionPreference = 'Continue'
    Enter-LfUtf8Output
    try {
        & $CMake @arguments 2>&1 | ForEach-Object {
            $line = "$_"
            $counter++
            Write-LfLog $line
            if ($line -match '(:\s+(fatal\s+)?error\s+[A-Z]+\d+)|(error MSB\d+)|(:\s+error\s*:)') {
                if ($script:BuildErrors.Count -lt 400) { $script:BuildErrors.Add($line.Trim()) }
                Write-Host ('  ' + $line.Trim()) -ForegroundColor Red
            }
            elseif ($line -match '\.vcxproj -> (.+)$') {
                Write-Host ('  [готово] ' + [System.IO.Path]::GetFileName($Matches[1].Trim())) -ForegroundColor Green
            }
            elseif ($counter % 250 -eq 0) {
                Write-Host ('  ... идёт компиляция: {0:hh\:mm\:ss}' -f ((Get-Date) - $started)) -ForegroundColor DarkGray
            }
        }
    }
    finally { Exit-LfUtf8Output }
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Write-LfLog "build exit code: $code"
    return [int]$code
}

function Test-MemoryError { return [bool](@($script:BuildErrors) -match 'C1060|C1076|C3859|C1002|C1001|out of heap|virtual memory|heap space') }
function Test-PchError { return [bool](@($script:BuildErrors) -match 'cotire|\.pch|C1083.*PCH|C2857|C1853|C1854') }

function Copy-BuildOutputs($MySql, $Ssl) {
    $outDir = Join-Path $BuildDir 'bin\Release'
    if (-not (Test-Path -LiteralPath $outDir)) { $outDir = Join-Path $BuildDir 'bin' }
    if (-not (Test-Path -LiteralPath $outDir)) { throw "Не найдена папка с результатами сборки: $outDir" }

    $running = @(Get-Process -Name 'worldserver', 'bnetserver' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) { throw 'worldserver/bnetserver сейчас запущены и блокируют файлы. Запустите stop_server.bat и повторите.' }

    New-Item -ItemType Directory -Force -Path $ServerDir | Out-Null
    $missing = @()
    foreach ($name in ($RequiredExe + $OptionalExe)) {
        $exe = Join-Path $outDir "$name.exe"
        if (Test-Path -LiteralPath $exe) {
            Copy-Item -LiteralPath $exe -Destination $ServerDir -Force
            $pdb = Join-Path $outDir "$name.pdb"
            if (Test-Path -LiteralPath $pdb) { Copy-Item -LiteralPath $pdb -Destination $ServerDir -Force }
        }
        elseif ($RequiredExe -contains $name) { $missing += "$name.exe" }
        else { Write-LfWarn "$name.exe не собран (необязательный компонент)." }
    }
    if ($missing.Count -gt 0) { throw ("Сборка не создала: " + ($missing -join ', ')) }

    Get-ChildItem -LiteralPath $outDir -Filter '*.dll' -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $ServerDir -Force }
    foreach ($dist in @('worldserver.conf.dist', 'bnetserver.conf.dist')) {
        $src = Join-Path $outDir $dist
        if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath (Join-Path $ServerDir $dist))) { Copy-Item -LiteralPath $src -Destination $ServerDir }
    }
    # libmysql.dll обязан быть той же версии, что и заголовки (проверка TCE00011 в DatabaseWorkerPool).
    if (Test-Path -LiteralPath $MySql.Dll) { Copy-Item -LiteralPath $MySql.Dll -Destination $ServerDir -Force }
    else { Write-LfWarn "Не найден $($MySql.Dll) - скопируйте libmysql.dll в server\ вручную." }
    foreach ($dllName in @('libssl-3-x64.dll', 'libcrypto-3-x64.dll')) {
        $found = Get-ChildItem -LiteralPath $Ssl.Root -Recurse -Filter $dllName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { $found = Get-ChildItem -LiteralPath (Join-Path $MySql.Root 'bin') -Filter $dllName -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($found) { Copy-Item -LiteralPath $found.FullName -Destination $ServerDir -Force }
        else { Write-LfWarn "Не найден $dllName - сервер может не запуститься." }
    }
    # A fingerprint is written ONLY after successful compilation and copying both EXEs.
    # play.bat and setup.bat reject an older binary even if the sources were fixed.
    $freshnessCheck = Join-Path $ToolsDir 'check_build_freshness.ps1'
    & $freshnessCheck -Root $Root -ServerDir $ServerDir -Update
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось записать контрольные суммы сборки (server\build_sources.json).' }

    # Проверка библиотек: exe без своих DLL закрывается сразу. Недостающее берётся из tools\ и Visual Studio.
    $runtimeCheck = Join-Path $Root 'check_server_runtime.ps1'
    if (Test-Path -LiteralPath $runtimeCheck) {
        & $runtimeCheck -Root $Root -ServerDir $ServerDir
        if ($LASTEXITCODE -ne 0) { Write-LfWarn 'Не все библиотеки для запуска найдены - см. server\runtime_check.txt.' }
        else { Write-LfOk 'Библиотеки для запуска проверены: server\runtime_check.txt.' }
    }
}

# ------------------------------------------------------------------ Основной сценарий
$exitCode = 0
$started = Get-Date
try {
    Open-LfLog $LogFile
    Write-Host ''
    Write-Host '  LEGIONFORGE 7.3.5 - автоматическая компиляция сервера' -ForegroundColor White
    Write-Host "  Журнал: $LogFile" -ForegroundColor DarkGray
    Write-Host ''
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Требуется 64-битная Windows 10/11.' }
    if (-not (Test-LfAdmin)) { throw 'Нужны права администратора: запустите build_server.bat через "Запуск от имени администратора".' }
    if (-not (Test-Path -LiteralPath (Join-Path $CoreDir 'CMakeLists.txt'))) { throw "Не найден исходный код ядра: $CoreDir\CMakeLists.txt" }
    if ($Root -match '[^\x00-\x7F]' -or $Root.Contains(' ')) {
        Write-LfWarn "Путь проекта содержит пробелы или кириллицу ($Root). Если сборка упадёт - перенесите папку, например, в D:\legionforge."
    }

    $free = Get-LfFreeSpaceGB $Root
    $ram = Get-LfRamGB
    Write-LfStep ("Свободно на диске: {0} ГБ; ОЗУ: {1} ГБ; ядер ЦП: {2}" -f $free, $ram, [Environment]::ProcessorCount)
    if ($free -ge 0 -and $free -lt 10) { throw "Слишком мало места: $free ГБ. Для инструментов и сборки нужно около 30 ГБ." }
    if ($free -ge 0 -and $free -lt 30) { Write-LfWarn "Свободно $free ГБ - рекомендуется не менее 30 ГБ (Build Tools ~6, Boost ~3, папка build ~15)." }
    New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null

    Write-Host ''
    Write-LfStep 'Шаг 1/4. Подготовка портативных инструментов в tools\'
    $null = Get-LfSevenZip
    $cmake = Initialize-CMake
    $vs = Initialize-VisualStudio
    $boost = Initialize-Boost
    $ssl = Initialize-OpenSsl
    $mysql = Initialize-MySqlDev

    if ($PrepareOnly) {
        Write-LfOk 'Все инструменты подготовлены (режим -PrepareOnly, компиляция не запускалась).'
        exit 0
    }

    $env:BOOST_ROOT = $boost.Root
    $env:VSLANG = '1033'                    # сообщения компилятора на английском - их легко искать в интернете
    $env:MSBUILDDISABLENODEREUSE = '1'      # не оставлять висящие процессы MSBuild после сборки

    if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
        Write-LfStep 'Очистка папки build\ (параметр -Clean)...'
        Remove-Item -LiteralPath $BuildDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

    $usePch = -not $NoPch
    if ($Jobs -le 0) { $Jobs = Get-DefaultJobs }
    if ($ram -lt 12) { $env:_CL_ = '/MP{0}' -f [int][math]::Max(1, [math]::Floor($ram / 2)) }

    Write-Host ''
    Write-LfStep 'Шаг 2/4. Генерация проекта CMake (1-3 минуты)...'
    $code = Invoke-CMakeConfigure $cmake $vs $boost $ssl $mysql $usePch
    if ($code -ne 0) {
        Write-LfWarn 'Первая генерация не удалась - сбрасываю кэш CMake и пробую ещё раз без предкомпилированных заголовков...'
        Remove-Item -LiteralPath (Join-Path $BuildDir 'CMakeCache.txt'), (Join-Path $BuildDir 'CMakeFiles') -Recurse -Force -ErrorAction SilentlyContinue
        $usePch = $false
        $code = Invoke-CMakeConfigure $cmake $vs $boost $ssl $mysql $usePch
        if ($code -ne 0) { throw 'CMake не смог сгенерировать проект. Причина - в строках "CMake Error" выше и в build_log.txt.' }
    }
    Write-LfOk 'Проект сгенерирован.'

    Write-Host ''
    Write-LfStep ("Шаг 3/4. Компиляция (параллельных проектов: {0}, PCH: {1}). Обычно 30-90 минут..." -f $Jobs, $(if ($usePch) { 'да' } else { 'нет' }))
    $code = Invoke-CMakeBuild $cmake $Jobs
    $attempt = 1
    while ($code -ne 0 -and $attempt -le 2) {
        $attempt++
        if (Test-MemoryError) {
            Write-LfWarn 'Компилятору не хватило памяти - продолжаю в щадящем режиме (1 проект, 2 потока).'
            $Jobs = 1
            $env:_CL_ = '/MP2'
        }
        elseif ($usePch -and (Test-PchError)) {
            Write-LfWarn 'Сбой предкомпилированных заголовков - перегенерирую проект без PCH.'
            $usePch = $false
            $null = Invoke-CMakeConfigure $cmake $vs $boost $ssl $mysql $usePch
        }
        else { break }
        $code = Invoke-CMakeBuild $cmake $Jobs
    }
    if ($code -ne 0) {
        Write-Host ''
        Write-LfErr 'Компиляция завершилась с ошибкой. Первые ошибки:'
        @($script:BuildErrors) | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        throw "Сборка не удалась (код $code). Полный журнал: $LogFile"
    }
    Write-LfOk 'Компиляция завершена.'

    Write-Host ''
    Write-LfStep 'Шаг 4/4. Копирование программ и библиотек в server\'
    Copy-BuildOutputs $mysql $ssl
    $info = @(
        "LEGIONFORGE 7.3.5 build info"
        "Date:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Compiler:   $($vs.displayName) $($vs.installationVersion)"
        "CMake:      $CMakeVersion"
        "Boost:      $BoostVersion"
        "OpenSSL:    $($ssl.Root)"
        "MySQL dev:  $($mysql.Root)"
        "PCH:        $usePch"
    )
    [System.IO.File]::WriteAllLines((Join-Path $ServerDir 'build_info.txt'), $info, (New-Object System.Text.UTF8Encoding $false))
    $elapsed = (Get-Date) - $started
    Write-Host ''
    Write-LfOk ('Сервер скомпилирован за {0:hh\:mm\:ss}. Файлы в папке server\:' -f $elapsed)
    foreach ($name in ($RequiredExe + $OptionalExe)) {
        $path = Join-Path $ServerDir "$name.exe"
        if (Test-Path -LiteralPath $path) { Write-Host ("        {0,-24} {1}" -f "$name.exe", (Format-LfSize (Get-Item -LiteralPath $path).Length)) -ForegroundColor Green }
    }
}
catch {
    $exitCode = 1
    Write-Host ''
    Write-LfErr $_.Exception.Message
    Write-Host "  Журнал сборки: $LogFile" -ForegroundColor Yellow
}
finally {
    Close-LfLog
}
exit $exitCode
