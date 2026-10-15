<#
.SYNOPSIS
    LEGIONFORGE 7.3.5 - префлайт SSL-пары bnetserver.

.DESCRIPTION
    Устраняет "Failed to initialize SSL context" на стороне окружения:
      1. Проверяет наличие bnetserver.cert.pem / bnetserver.key.pem в каталоге
         сервера (ядра ищут их ОТНОСИТЕЛЬНО ТЕКУЩЕГО КАТАЛОГА запуска).
      2. Проверяет, что сертификат и ключ - ОДНА пара (сравнение публичного
         ключа). Рассинхрон пары - самая частая причина после отсутствующих
         файлов.
      3. Проверяет срок действия и алгоритм подписи (OpenSSL 3.x отказывается
         работать с SHA-1 и с ключами < 2048 бит при SECLEVEL=1).
      4. При любой проблеме создаёт новую самоподписанную пару
         (RSA-2048, SHA-256, 10 лет), а старую сохраняет в *.bak-<дата>.

    Скрипт идемпотентен: если пара валидна - ничего не меняет.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_ssl_cert.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_ssl_cert.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ServerDir = '',
    [string]$OpenSsl = '',
    [int]$Days = 3650,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
if (-not (Test-Path -LiteralPath $ServerDir)) {
    New-Item -ItemType Directory -Force -Path $ServerDir | Out-Null
}

$cert = Join-Path $ServerDir 'bnetserver.cert.pem'
$key  = Join-Path $ServerDir 'bnetserver.key.pem'

function Write-Ok([string]$m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Err([string]$m)  { Write-Host "  [ОШИБКА] $m" -ForegroundColor Red }

function Find-OpenSsl {
    param([string]$Explicit)
    $candidates = @()
    if ($Explicit) { $candidates += $Explicit }
    $candidates += @(
        (Join-Path $Root 'tools\openssl\bin\openssl.exe'),
        (Join-Path $Root 'tools\openssl\openssl.exe'),
        (Join-Path $ServerDir 'openssl.exe'),
        (Join-Path $ServerDir 'libcrypto-3-x64.dll')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c) -and ($c -like '*.exe')) { return $c }
    }
    foreach ($name in @('openssl.exe', 'openssl')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    # OpenSSL обычно лежит рядом с самим bnetserver (libssl/libcrypto)
    foreach ($probe in @("$env:ProgramFiles\OpenSSL-Win64\bin\openssl.exe",
                         "${env:ProgramFiles(x86)}\OpenSSL-Win64\bin\openssl.exe")) {
        if (Test-Path -LiteralPath $probe) { return $probe }
    }
    return $null
}

$openssl = Find-OpenSsl -Explicit $OpenSsl
if (-not $openssl) {
    Write-Warn 'openssl.exe не найден: проверка пары будет только по наличию файлов.'
    Write-Warn 'Ядро (после патча SslContext.cpp) сгенерирует пару само при старте.'
}

function Test-Pair {
    if ($Force) { return $false }
    if (-not (Test-Path -LiteralPath $cert) -or -not (Test-Path -LiteralPath $key)) { return $false }
    if ((Get-Item -LiteralPath $cert).Length -lt 400) { return $false }
    if ((Get-Item -LiteralPath $key).Length -lt 400) { return $false }
    if (-not $openssl) { return $true }

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $certPub = (& $openssl x509 -in $cert -noout -pubkey 2>&1 | Out-String).Trim()
        $keyPub  = (& $openssl pkey -in $key -pubout 2>&1 | Out-String).Trim()
        if (-not $certPub -or $certPub -notmatch 'BEGIN PUBLIC KEY') {
            Write-Err "Не удалось прочитать сертификат: $($certPub.Split("`n")[0])"
            return $false
        }
        if (-not $keyPub -or $keyPub -notmatch 'BEGIN PUBLIC KEY') {
            Write-Err "Не удалось прочитать ключ: $($keyPub.Split("`n")[0])"
            return $false
        }
        if ($certPub -ne $keyPub) {
            Write-Err 'Сертификат и ключ НЕ СООТВЕТСТВУЮТ друг другу (разные пары).'
            return $false
        }
        $sig = (& $openssl x509 -in $cert -noout -text 2>&1 | Out-String)
        if ($sig -match 'Signature Algorithm:\s*(\S+)') {
            if ($Matches[1] -match 'sha1|md5') {
                Write-Err "Алгоритм подписи $($Matches[1]) отклоняется OpenSSL 3.x (SECLEVEL>=1)."
                return $false
            }
        }
        $dates = (& $openssl x509 -in $cert -noout -enddate 2>&1 | Out-String).Trim()
        if ($dates -match 'notAfter=(.+)$') {
            $exp = [datetime]::Parse($Matches[1].Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
            if ($exp -lt (Get-Date)) { Write-Err "Сертификат истёк $exp"; return $false }
            if ($exp -lt (Get-Date).AddDays(30)) { Write-Warn "Сертификат истекает $exp" }
        }
    }
    finally { $ErrorActionPreference = $prev }
    return $true
}

if (Test-Pair) {
    Write-Ok "SSL-пара в порядке: $cert"
    Write-Ok "Ключ:            $key"
    exit 0
}

# --- резервная копия и генерация -------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
foreach ($f in @($cert, $key)) {
    if (Test-Path -LiteralPath $f) {
        Copy-Item -LiteralPath $f -Destination ("{0}.bak-{1}" -f $f, $stamp) -Force
        Write-Warn "Старый файл сохранён как $(Split-Path -Leaf $f).bak-$stamp"
    }
}

if (-not $openssl) {
    Write-Err 'Без openssl.exe создать пару нельзя. Установите OpenSSL 3.x x64 или'
    Write-Err 'скопируйте bnetserver.cert.pem/bnetserver.key.pem из server\ вручную.'
    Write-Ok  'Патченое ядро сгенерирует пару автоматически при старте bnetserver.'
    exit 1
}

Write-Host '  [*] Генерирую самоподписанную пару (RSA-2048, SHA-256, срок:' $Days 'дней)...' -ForegroundColor Cyan
$subject = '/C=RU/O=LegionForge/OU=Battle.net/CN=LegionForge Battle.net Server'
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $openssl req -x509 -newkey rsa:2048 -sha256 -days $Days -nodes `
        -keyout $key -out $cert -subj $subject `
        -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' 2>&1 |
        ForEach-Object { Write-Host "      | $_" -ForegroundColor DarkGray }
    $code = $LASTEXITCODE
}
finally { $ErrorActionPreference = $prev }

if ($code -ne 0 -or -not (Test-Path -LiteralPath $cert) -or -not (Test-Path -LiteralPath $key)) {
    # старые версии openssl не знают -addext: пробуем без него
    Write-Warn 'Первая попытка не удалась, пробую без subjectAltName...'
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        & $openssl req -x509 -newkey rsa:2048 -sha256 -days $Days -nodes `
            -keyout $key -out $cert -subj $subject 2>&1 | Out-Null
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $prev }
}

if ($code -eq 0 -and (Test-Path -LiteralPath $cert) -and (Test-Path -LiteralPath $key)) {
    Write-Ok "Создан сертификат: $cert"
    Write-Ok "Создан ключ:       $key"
    exit 0
}

Write-Err "openssl вернул код $code - пара не создана."
exit 1
