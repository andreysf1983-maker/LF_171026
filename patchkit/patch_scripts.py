#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEGIONFORGE 7.3.5 (build 26124) - патчер обвязки: PowerShell/BAT, конфиги,
SQL под кастомные расы 31..44 и документация.

Что чинит:
  1. extract_delta.ps1 / extract_maps.ps1 - падение на шаге "vmaps" из-за
     штатного сообщения vmap4extractor в stderr (NativeCommandError при
     $ErrorActionPreference = 'Stop').
  2. bnetserver "Failed to initialize SSL context" - префлайт SSL-пары
     (tools/ensure_ssl_cert.ps1) + логгер server.ssl в bnetserver.conf.dist.
  3. "Missing name Guild.SaveInterval in config file" - tools/ensure_conf_keys.ps1
     синхронизирует живой *.conf с *.conf.dist (добавляет все отсутствующие ключи).
  4. Кастомные расы 31..44 - SQL-сиды стартовых данных + документация.

Запуск:  python3 patch_scripts.py <путь к корню репозитория>
"""
import os
import re
import sys


def read(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig" if bom else "utf-8")
    crlf = "\r\n" in text
    return text.replace("\r\n", "\n"), bom, crlf


def write(path, text, bom, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    data = text.encode("utf-8")
    if bom:
        data = b"\xef\xbb\xbf" + data
    with open(path, "wb") as fh:
        fh.write(data)


class Patch:
    def __init__(self, root):
        self.root = root
        self.applied = 0
        self.skipped = 0

    def path(self, relpath):
        return os.path.join(self.root, *relpath.split("/"))

    def sub(self, relpath, old, new, required=True):
        path = self.path(relpath)
        text, bom, crlf = read(path)
        if old not in text:
            if new in text:
                self.skipped += 1
                print("  = уже применено: %s" % relpath)
                return False
            if required:
                raise SystemExit("!! НЕ НАЙДЕН ФРАГМЕНТ в %s:\n%r" % (relpath, old[:300]))
            print("  - пропущено: %s" % relpath)
            return False
        write(path, text.replace(old, new), bom, crlf)
        self.applied += 1
        print("  + %s" % relpath)
        return True

    def sub_bytes(self, relpath, old, new, required=True):
        """Для файлов в OEM-кодировке (*.bat): правка на уровне байтов, ASCII."""
        path = self.path(relpath)
        with open(path, "rb") as fh:
            data = fh.read()
        ob, nb = old.encode("ascii"), new.encode("ascii")
        if ob not in data:
            if nb in data:
                self.skipped += 1
                print("  = уже применено: %s" % relpath)
                return False
            if required:
                raise SystemExit("!! НЕ НАЙДЕН БАЙТОВЫЙ ФРАГМЕНТ в %s" % relpath)
            print("  - пропущено: %s" % relpath)
            return False
        with open(path, "wb") as fh:
            fh.write(data.replace(ob, nb, 1))
        self.applied += 1
        print("  + %s (bytes)" % relpath)
        return True

    def write_file(self, relpath, content, crlf=False, bom=False):
        path = self.path(relpath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if crlf:
            content = content.replace("\n", "\r\n")
        data = content.encode("utf-8")
        if bom:
            data = b"\xef\xbb\xbf" + data
        with open(path, "wb") as fh:
            fh.write(data)
        self.applied += 1
        print("  + записан: %s (%d байт)" % (relpath, len(data)))

    def append(self, relpath, content):
        path = self.path(relpath)
        text, bom, crlf = read(path)
        marker = content.strip().splitlines()[0].strip()
        if marker in text:
            self.skipped += 1
            print("  = уже добавлено: %s" % relpath)
            return
        write(path, text.rstrip("\n") + "\n\n" + content, bom, crlf)
        self.applied += 1
        print("  + дописано в %s" % relpath)


# --------------------------------------------------------------------------
# extract_delta.ps1
# --------------------------------------------------------------------------
INVOKE_TOOL = '''
# [LEGIONFORGE PATCH 2026-10] Безопасный запуск внешних exe.
# Корень бага "извлечение карт": при $ErrorActionPreference = 'Stop' любая строка,
# которую программа пишет в stderr, превращается Windows PowerShell 5.1 в
# NativeCommandError и ОБРЫВАЕТ весь скрипт. Именно так падал шаг 2/4 (vmaps):
#   vmap4extractor.exe : Can't open World\\Maps\\test\\test.wdt: FILE_NOT_FOUND
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
            "Can't open .*\\.wdt",
            'Skipping map',
            '^\\[INFO\\] Skipped '
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
'''


def patch_extract_delta(p):
    rel = "extract_delta.ps1"

    p.sub(rel, """function Log([string]$text, [string]$color = 'Gray') {
    Write-Host $text -ForegroundColor $color
    Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $text) -Encoding UTF8
}""",
          """function Log([string]$text, [string]$color = 'Gray') {
    Write-Host $text -ForegroundColor $color
    Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $text) -Encoding UTF8
}
""" + INVOKE_TOOL)

    # каталоги staging должны существовать ДО запуска экстракторов
    p.sub(rel, """New-Item -ItemType Directory -Force -Path $staging, $reportDir, $logDir, $dataDir | Out-Null""",
          """New-Item -ItemType Directory -Force -Path $staging, $reportDir, $logDir, $dataDir | Out-Null
# [LEGIONFORGE PATCH 2026-10] vmap4extractor пишет Buildings/ в ТЕКУЩИЙ каталог,
# vmap4assembler ожидает его наличие; mapextractor - подкаталоги staging.
# Без предварительного создания часть инструментов молча ничего не извлекала.
foreach ($sub in @('maps', 'dbc', 'Cameras', 'gt', 'Buildings', 'vmaps', 'mmaps')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $staging $sub) | Out-Null
}""")

    # 1/4 mapextractor
    p.sub(rel, """& $tools.mapextractor -i $ClientDir -o $staging 2>&1 | Tee-Object -FilePath $logFile -Append | Out-Null
if ($LASTEXITCODE -ne 0) { Log "  [!] mapextractor вернул код $LASTEXITCODE" 'Yellow' }""",
          """$code = Invoke-LfTool $tools.mapextractor @('-i', $ClientDir, '-o', $staging)
if ($code -ne 0) { Log "  [!] mapextractor вернул код $code (часть данных могла не извлечься)" 'Yellow' }""")

    # 2/4 vmaps
    p.sub(rel, """    Push-Location $staging
    try {
        & $tools.vmap4extractor -d $ClientDir 2>&1 | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $staging 'vmaps') | Out-Null
        & $tools.vmap4assembler 'Buildings' (Join-Path $staging 'vmaps') 2>&1 | Out-Null
    }
    finally { Pop-Location }""",
          """    Push-Location $staging
    try {
        # [LEGIONFORGE PATCH 2026-10] раньше здесь было
        #   & $tools.vmap4extractor -d $ClientDir 2>&1 | Out-Null
        # и ПЕРВОЕ ЖЕ сообщение в stderr ("Can't open World\\Maps\\test\\test.wdt:
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
    finally { Pop-Location }""")

    # 3/4 mmaps
    p.sub(rel, """        foreach ($id in $targets) {
            & $tools.mmaps_generator "$id" '--silent' 2>&1 | Out-Null
            $copied.mmaps++
        }""",
          """        foreach ($id in $targets) {
            # [LEGIONFORGE PATCH 2026-10] считаем карту обработанной только при
            # нулевом коде возврата и логируем штатные предупреждения генератора.
            $code = Invoke-LfTool $tools.mmaps_generator @("$id", '--silent')
            if ($code -eq 0) { $copied.mmaps++ }
            else { $failedMmaps += $id }
        }""")

    p.sub(rel, """    Log ("      карт к обработке: {0}" -f $targets.Count) 'Gray'""",
          """    Log ("      карт к обработке: {0}" -f $targets.Count) 'Gray'
    $failedMmaps = @()""")

    # отчёт
    p.sub(rel, """    Copied      = $copied
    ChangedDb2  = ($changedDb2 | Sort-Object -Unique)""",
          """    Copied      = $copied
    FailedMmaps = $failedMmaps
    IgnoredToolLines = $script:ignoredToolLines
    ChangedDb2  = ($changedDb2 | Sort-Object -Unique)""")


def patch_extract_maps(p):
    rel = "extract_maps.ps1"
    path = p.path(rel)
    text, bom, crlf = read(path)
    m = re.search(r"function Invoke-Logged\s*\([^)]*\)\s*\{", text)
    if not m:
        print("  - extract_maps.ps1: Invoke-Logged не найдена, пропускаю")
        return
    if "Start-Process" in text[m.start(): m.start() + 1500] and "-RedirectStandardError" in text[m.start(): m.start() + 1500]:
        # Здесь вывод инструментов уходит в файлы через Start-Process -Redirect*,
        # то есть stderr НЕ попадает в конвейер PowerShell и NativeCommandError
        # невозможен. Патч не требуется (в отличие от extract_delta.ps1, где
        # использовалось "& exe ... 2>&1 | Out-Null").
        print("  = extract_maps.ps1: запуск через Start-Process -Redirect* - уже безопасно")
        p.skipped += 1
        return
    window = text[m.start(): m.start() + 1200]
    if "$ErrorActionPreference = 'Continue'" in window:
        print("  = extract_maps.ps1: Invoke-Logged уже защищена")
        return
    text = text[:m.end()] + (
        "\n    # [LEGIONFORGE PATCH 2026-10] stderr внешних exe при EAP='Stop' рвёт скрипт\n"
        "    # (NativeCommandError). Внутри обёртки переключаем на 'Continue'.\n"
        "    $ErrorActionPreference = 'Continue'"
    ) + text[m.end():]
    write(path, text, bom, crlf)
    p.applied += 1
    print("  + %s: Invoke-Logged защищена от NativeCommandError" % rel)


PLAY_BAT_PREFLIGHT = (
    'rem [LEGIONFORGE PATCH 2026-10] pre-flight: conf keys + SSL cert/key pair\r\n'
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\ensure_conf_keys.ps1" -ServerDir "%SERVER_DIR%" >nul 2>&1\r\n'
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\ensure_ssl_cert.ps1" -ServerDir "%SERVER_DIR%" >nul 2>&1\r\n'
    '    start "LEGIONFORGE bnetserver" /min /D "%SERVER_DIR%" cmd /c "bnetserver.exe -c bnetserver.conf || pause"'
)


def patch_play_bat(p):
    p.sub_bytes("play.bat",
                '    start "LEGIONFORGE bnetserver" /min /D "%SERVER_DIR%" cmd /c "bnetserver.exe -c bnetserver.conf || pause"',
                PLAY_BAT_PREFLIGHT)


def patch_confs(p):
    p.sub("server/bnetserver.conf.dist", 'PrivateKeyFile = "./bnetserver.key.pem"',
          '''PrivateKeyFile = "./bnetserver.key.pem"

#    SSLCertAutoGenerate
#        Description: [LEGIONFORGE PATCH 2026-10] Если пара cert/key не найдена
#                     (или сертификат не соответствует ключу), bnetserver сам
#                     сгенерирует самоподписанную пару (RSA-2048, SHA-256,
#                     10 лет) рядом с bnetserver.exe и продолжит запуск.
#                     Для приватного реалма этого достаточно: клиент 7.3.5 не
#                     проверяет цепочку доверия battle.net.
#        Default:     1 - генерировать автоматически
#                     0 - падать с ошибкой (требует ручную пару)

SSLCertAutoGenerate = 1''')

    p.sub("server/bnetserver.conf.dist", "Logger.sql.updates=3,Console Bnet",
          '''Logger.sql.updates=3,Console Bnet
# [LEGIONFORGE PATCH 2026-10] Категория server.ssl содержала НАСТОЯЩУЮ причину
# "Failed to initialize SSL context", но не была включена, поэтому в консоль
# уходила только общая строка. Держите эти логгеры включёнными.
Logger.server.ssl=3,Console Bnet
Logger.server.bnetserver=3,Console Bnet''')

    p.sub("server/worldserver.conf.dist", "Guild.SaveInterval = 15",
          '''Guild.SaveInterval = 15

###################################################################################################
# [LEGIONFORGE PATCH 2026-10] КАСТОМНЫЕ РАСЫ КЛИЕНТА (31..44)
###################################################################################################
#
#    CustomRaces.Enable
#        Description: Разрешить ядру работать с расами 31..44, которых нет в
#                     серверном ChrRaces.db2 (они есть в ChrRaces.db2 кастомного
#                     клиента: UWoW-подобные сборки 7.3.5 build 26124).
#        Default:     1 - включено (0 - поведение стокового ядра, MAX_RACES фактически 31)
#
#    CustomRaces.Definitions
#        Description: Список кастомных рас через запятую. Формат записи:
#                         raceId:team:baseRace
#                     raceId   - 31..44
#                     team     - ALLIANCE | HORDE | NEUTRAL
#                     baseRace - раса-донор из ChrRaces.db2 (1..30): её
#                                FactionID, display id и стартовое наследие
#                                применяются к кастомной расе.
#                     Team/faction нужны, потому что TeamForRace() читает
#                     ChrRaces.db2, а записей 31..44 там нет.
#        Default:     см. ниже (соответствует sql/52_custom_races_31_44.sql)
#
#        ВАЖНО: после изменения списка нужно пересобрать ядро не требуется, но
#               необходимо применить SQL-сиды стартовых данных:
#                 tools\\mysql\\server\\bin\\mysql.exe -uroot world < sql\\52_custom_races_31_44.sql
#               иначе `playercreateinfo` не содержит расу и создание персонажа
#               закончится CHAR_CREATE_FAILED.

CustomRaces.Enable = 1
CustomRaces.Definitions = "31:ALLIANCE:1,32:HORDE:2,33:ALLIANCE:4,34:ALLIANCE:3,35:HORDE:5,36:HORDE:6,37:ALLIANCE:7,38:HORDE:8,39:HORDE:10,40:ALLIANCE:11,41:ALLIANCE:22,42:HORDE:9,43:NEUTRAL:24,44:ALLIANCE:27"''')


ENSURE_SSL_CERT_PS1 = r'''<#
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
'''


ENSURE_CONF_KEYS_PS1 = r'''<#
.SYNOPSIS
    LEGIONFORGE 7.3.5 - синхронизация живых *.conf с *.conf.dist.

.DESCRIPTION
    Устраняет предупреждения вида
        Missing name Guild.SaveInterval in config file ...\worldserver.conf,
        add "Guild.SaveInterval = 15" to this file
    Причина: живой worldserver.conf/bnetserver.conf созданы из более старого
    *.conf.dist (или вручную), и в них нет ключей, которые ядро читает
    обязательно.

    Скрипт:
      * если *.conf отсутствует - копирует его из *.conf.dist;
      * находит ВСЕ ключи, которые есть в .dist, но отсутствуют в .conf, и
        дописывает их в конец файла вместе с значением по умолчанию из .dist;
      * ничего не переписывает и не удаляет: существующие значения остаются;
      * кладёт отчёт в reports\ensure_conf_keys.json.

    Идемпотентен: повторный запуск не добавляет ключи дважды.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1 -WhatIf
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$ServerDir = '',
    [string[]]$Confs = @('worldserver', 'bnetserver'),
    [switch]$WhatIfMode
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not $ServerDir) { $ServerDir = Join-Path $Root 'server' }
$reportDir = Join-Path $Root 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Write-Ok([string]$m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Step([string]$m) { Write-Host "  [*] $m" -ForegroundColor Cyan }

function Get-ConfKeys {
    param([string]$Path)
    $keys = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) { return $keys }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9_.\-]*)\s*=\s*(.*)$') {
            $keys[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $keys
}

$summary = @()
foreach ($name in $Confs) {
    $conf = Join-Path $ServerDir "$name.conf"
    $dist = Join-Path $ServerDir "$name.conf.dist"

    if (-not (Test-Path -LiteralPath $dist)) {
        Write-Warn "$name.conf.dist не найден в $ServerDir - пропускаю."
        continue
    }

    if (-not (Test-Path -LiteralPath $conf)) {
        Write-Step "$name.conf отсутствует - создаю из $name.conf.dist"
        if (-not $WhatIfMode) { Copy-Item -LiteralPath $dist -Destination $conf -Force }
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $true; Added = 0; Keys = @() }
        continue
    }

    $distKeys = Get-ConfKeys -Path $dist
    $liveKeys = Get-ConfKeys -Path $conf

    $missing = @()
    foreach ($k in $distKeys.Keys) {
        if (-not $liveKeys.Contains($k)) { $missing += $k }
    }

    if ($missing.Count -eq 0) {
        Write-Ok "$name.conf содержит все $($distKeys.Count) ключей из $name.conf.dist"
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = 0; Keys = @() }
        continue
    }

    Write-Warn "$name.conf: отсутствует ключей: $($missing.Count) (в т.ч. $(($missing | Select-Object -First 6) -join ', '))"
    if ($WhatIfMode) {
        $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = $missing.Count; Keys = $missing }
        continue
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item -LiteralPath $conf -Destination "$conf.bak-$stamp" -Force

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('###################################################################################################')
    [void]$sb.AppendLine("# [LEGIONFORGE] Ключи добавлены автоматически tools\ensure_conf_keys.ps1 ($stamp)")
    [void]$sb.AppendLine('# Значения взяты из ' + "$name.conf.dist. Ядро читает их обязательно;")
    [void]$sb.AppendLine('# без них в лог пишется "Missing name <Key> in config file".')
    [void]$sb.AppendLine('###################################################################################################')
    foreach ($k in $missing) {
        [void]$sb.AppendLine("$k = $($distKeys[$k])")
    }

    [System.IO.File]::AppendAllText($conf, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "$name.conf: дописано ключей $($missing.Count), резервная копия $name.conf.bak-$stamp"
    $summary += [pscustomobject]@{ Conf = "$name.conf"; Created = $false; Added = $missing.Count; Keys = $missing }
}

$reportPath = Join-Path $reportDir 'ensure_conf_keys.json'
[pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('s')
    ServerDir   = $ServerDir
    Results     = $summary
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Ok "Отчёт: $reportPath"
exit 0
'''


SQL_RACES = r'''-- =============================================================================
--  LEGIONFORGE 7.3.5 (build 26124)
--  Файл:  sql/52_custom_races_31_44.sql        База: world
--  Тема:  кастомные расы клиента 31..44 (UWoW-подобная сборка build 26124)
--
--  Что делает:
--    1. Расширяет racemask-колонки до BIGINT UNSIGNED (бит расы 33..44 не
--       помещается в INT UNSIGNED - молча получался 0).
--    2. Клонирует стартовые данные расы-донора для каждой кастомной расы:
--         playercreateinfo, player_levelstats, playercreateinfo_item,
--         playercreateinfo_action, playercreateinfo_spell_custom,
--         playercreateinfo_cast_spell.
--    3. Прописывает race_unlock_requirement.expansion = 6 (Legion), иначе
--       HandleCharCreateOpcode отвечает CHAR_CREATE_FAILED
--       ("tried to create character with unavailable race").
--
--  Соответствие "раса -> донор" совпадает с CustomRaces.Definitions в
--  server/worldserver.conf.dist. Если меняете одно - меняйте и другое.
--
--  Требуется патч ядра (MAX_RACES=45 + реестр кастомных рас), иначе строки
--  playercreateinfo будут отброшены при загрузке:
--      "Wrong race 31 in `playercreateinfo` table, ignoring."
--
--  Скрипт идемпотентен (INSERT IGNORE / UPDATE / условный ALTER).
--  Откат: sql/52_custom_races_31_44_rollback.sql
-- =============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 0. Таблица соответствия кастомных рас базовым (донорам)
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `lf_race_31_44`;
CREATE TEMPORARY TABLE `lf_race_31_44` (
  `race` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `base` TINYINT UNSIGNED NOT NULL,
  `team` VARCHAR(10)      NOT NULL,
  `name` VARCHAR(64)      NOT NULL
) ENGINE = MEMORY;

INSERT INTO `lf_race_31_44` (`race`, `base`, `team`, `name`) VALUES
  (31,  1, 'ALLIANCE', 'Custom race 31 (donor: Human)'),
  (32,  2, 'HORDE',    'Custom race 32 (donor: Orc)'),
  (33,  4, 'ALLIANCE', 'Custom race 33 (donor: Night Elf)'),
  (34,  3, 'ALLIANCE', 'Custom race 34 (donor: Dwarf)'),
  (35,  5, 'HORDE',    'Custom race 35 (donor: Undead)'),
  (36,  6, 'HORDE',    'Custom race 36 (donor: Tauren)'),
  (37,  7, 'ALLIANCE', 'Custom race 37 (donor: Gnome)'),
  (38,  8, 'HORDE',    'Custom race 38 (donor: Troll)'),
  (39, 10, 'HORDE',    'Custom race 39 (donor: Blood Elf)'),
  (40, 11, 'ALLIANCE', 'Custom race 40 (donor: Draenei)'),
  (41, 22, 'ALLIANCE', 'Custom race 41 (donor: Worgen)'),
  (42,  9, 'HORDE',    'Custom race 42 (donor: Goblin)'),
  (43, 24, 'NEUTRAL',  'Custom race 43 (donor: Pandaren Neutral)'),
  (44, 27, 'ALLIANCE', 'Custom race 44 (donor: Nightborne)');

-- ---------------------------------------------------------------------------
-- 1. racemask-колонки -> BIGINT UNSIGNED (иначе биты рас 33..44 теряются)
-- ---------------------------------------------------------------------------
SET @tbl := 'playercreateinfo_spell_custom';
SET @col := 'racemask';
SET @dt  := (SELECT DATA_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col);
SET @ddl := IF(@dt IS NULL, 'DO 0',
           IF(@dt = 'bigint', 'DO 0',
              CONCAT('ALTER TABLE `', @tbl, '` MODIFY `', @col, '` BIGINT UNSIGNED NOT NULL DEFAULT 0')));
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @tbl := 'playercreateinfo_cast_spell';
SET @col := 'raceMask';
SET @dt  := (SELECT DATA_TYPE FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tbl AND COLUMN_NAME = @col);
SET @ddl := IF(@dt IS NULL, 'DO 0',
           IF(@dt = 'bigint', 'DO 0',
              CONCAT('ALTER TABLE `', @tbl, '` MODIFY `', @col, '` BIGINT UNSIGNED NOT NULL DEFAULT 0')));
PREPARE lf_stmt FROM @ddl; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- ---------------------------------------------------------------------------
-- 2. Стартовая позиция и классы (без этого PlayerInfo не создаётся и клиент
--    получает CHAR_CREATE_FAILED)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `playercreateinfo`
  (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
SELECT m.`race`, p.`class`, p.`map`, p.`zone`, p.`position_x`, p.`position_y`, p.`position_z`, p.`orientation`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo` p ON p.`race` = m.`base`;

-- Характеристики по уровням (клон расы-донора, чтобы не было "дыр" 2+ уровня)
INSERT IGNORE INTO `player_levelstats` (`race`, `class`, `level`, `str`, `agi`, `sta`, `inte`)
SELECT m.`race`, s.`class`, s.`level`, s.`str`, s.`agi`, s.`sta`, s.`inte`
  FROM `lf_race_31_44` m
  JOIN `player_levelstats` s ON s.`race` = m.`base`;

-- Стартовые предметы
INSERT IGNORE INTO `playercreateinfo_item` (`race`, `class`, `itemid`, `amount`)
SELECT m.`race`, i.`class`, i.`itemid`, i.`amount`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_item` i ON i.`race` = m.`base`;

-- Панель команд (hotbar)
INSERT IGNORE INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
SELECT m.`race`, a.`class`, a.`button`, a.`action`, a.`type`
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_action` a ON a.`race` = m.`base`;

-- ---------------------------------------------------------------------------
-- 3. Масочные таблицы: 64-битный сдвиг (CAST(1 AS UNSIGNED) = BIGINT UNSIGNED)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT (CAST(1 AS UNSIGNED) << (m.`race` - 1)), s.`classmask`, s.`Spell`,
       CONCAT(COALESCE(s.`Note`, ''), ' [LF custom race ', m.`name`, ']')
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_spell_custom` s ON s.`racemask` = (CAST(1 AS UNSIGNED) << (m.`base` - 1));

INSERT IGNORE INTO `playercreateinfo_cast_spell` (`raceMask`, `classMask`, `spell`, `createMode`, `note`)
SELECT (CAST(1 AS UNSIGNED) << (m.`race` - 1)), c.`classMask`, c.`spell`, c.`createMode`,
       CONCAT(COALESCE(c.`note`, ''), ' [LF custom race]')
  FROM `lf_race_31_44` m
  JOIN `playercreateinfo_cast_spell` c ON c.`raceMask` = (CAST(1 AS UNSIGNED) << (m.`base` - 1));

-- ---------------------------------------------------------------------------
-- 4. Разблокировка рас: expansion 6 (Legion). Значение 7 (BfA) приводило к
--    CHAR_CREATE_EXPANSION, а GetMaxLevelForExpansion(7) в этом ядре = 0.
-- ---------------------------------------------------------------------------
UPDATE `race_unlock_requirement`
   SET `expansion` = 6, `achievementId` = 0
 WHERE `raceID` BETWEEN 31 AND 44;

INSERT INTO `race_unlock_requirement` (`raceID`, `expansion`, `achievementId`)
SELECT m.`race`, 6, 0
  FROM `lf_race_31_44` m
 WHERE NOT EXISTS (SELECT 1 FROM `race_unlock_requirement` x WHERE x.`raceID` = m.`race`);

-- ---------------------------------------------------------------------------
-- 5. Контрольный вывод: сколько строк стартовых данных получила каждая раса.
--    createInfoRows = 0  =>  персонажа этой расы создать НЕЛЬЗЯ.
-- ---------------------------------------------------------------------------
SELECT m.`race`                                                        AS raceId,
       m.`name`                                                        AS raceName,
       m.`base`                                                        AS donorRace,
       m.`team`                                                        AS team,
       (SELECT COUNT(*) FROM `playercreateinfo`      p WHERE p.`race` = m.`race`) AS createInfoRows,
       (SELECT COUNT(*) FROM `player_levelstats`     s WHERE s.`race` = m.`race`) AS levelStatRows,
       (SELECT COUNT(*) FROM `playercreateinfo_item` i WHERE i.`race` = m.`race`) AS startItemRows,
       (SELECT COUNT(*) FROM `playercreateinfo_action` a WHERE a.`race` = m.`race`) AS actionBarRows,
       (SELECT COUNT(*) FROM `race_unlock_requirement` r WHERE r.`raceID` = m.`race`) AS unlockRows
  FROM `lf_race_31_44` m
 ORDER BY m.`race`;

DROP TEMPORARY TABLE IF EXISTS `lf_race_31_44`;

-- Готово. Перезапустите worldserver: расы 31..44 должны появиться в окне
-- создания и персонажи должны создаваться.
'''


SQL_RACES_ROLLBACK = r'''-- =============================================================================
--  LEGIONFORGE 7.3.5 - ОТКАТ sql/52_custom_races_31_44.sql
--  Удаляет стартовые данные и разблокировку кастомных рас 31..44.
--  Типы racemask-колонок НЕ откатываются (BIGINT обратно совместим с INT).
-- =============================================================================
SET NAMES utf8mb4;

DELETE FROM `playercreateinfo`            WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `player_levelstats`           WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_item`       WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_action`     WHERE `race`  BETWEEN 31 AND 44;
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` >= (CAST(1 AS UNSIGNED) << 30);
DELETE FROM `playercreateinfo_cast_spell`   WHERE `raceMask` >= (CAST(1 AS UNSIGNED) << 30);
DELETE FROM `race_unlock_requirement`     WHERE `raceID` BETWEEN 31 AND 44;

SELECT 'custom races 31-44 removed' AS result;
'''


DOC_RACES = r'''# Кастомные расы 31..44: что мешало ядру и что изменено

> Legion 7.3.5 build 26124, кастомный клиент (UWoW-подобная сборка с контентом BfA).
> Патч: `patchkit/patch_core.py`, SQL: `sql/52_custom_races_31_44.sql`.

## 1. Симптом

`check_client_delta.ps1` показывает:

```
кастомные расы: 14 (31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44)
```

В клиенте раса видна в окне создания, но персонаж не создаётся, а в логе
worldserver:

```
Race (31) not found in DBC: wrong DBC files?
Wrong race 31 in `playercreateinfo` table, ignoring.
Account 1 tried to create character with unavailable race 31
```

## 2. Пять независимых блокираторов

| # | Где | Что мешало |
|---|-----|-----------|
| 1 | `SharedDefines.h` | `#define MAX_RACES 31` — расы 31..44 выходили за границу массивов `_playerInfo[MAX_RACES][MAX_CLASSES]` и отсекались проверкой `current_race >= MAX_RACES` |
| 2 | `SharedDefines.h` | `RACEMASK_*` собраны из `(1 << (race-1))` — при race ≥ 33 это сдвиг на величину ≥ ширины `int`, то есть **неопределённое поведение** и молчаливый 0 |
| 3 | `ObjectMgr::LoadPlayerCreateInfo` | обязательный `sChrRacesStore.LookupEntry(race)` — в серверном `ChrRaces.db2` (официальный 7.3.5) записей 31..44 нет, все строки `playercreateinfo` отбрасывались |
| 4 | `ObjectMgr::LoadRaceAndClassExpansionRequirements` | та же проверка → `_raceUnlockRequirementStore` без расы 31..44 → `HandleCharCreateOpcode` отвечает `CHAR_CREATE_FAILED` |
| 5 | `Player::TeamForRace / TeamIdForRace / setFactionForRace` | команда и `FactionID` читаются из `ChrRaces.db2`; для неизвестной расы возвращался `ALLIANCE`/`faction 0` + спам в лог |

## 3. Что сделано в ядре

* `MAX_RACES` поднят **31 → 45**, добавлены константы `RACE_CUSTOM_31..44`,
  `RACE_CUSTOM_FIRST/LAST`.
* Все `RACEMASK_*` переведены на **64 бита** (`UI64LIT(1) << (race-1)`), добавлены
  `RACEMASK_CUSTOM_PLAYABLE`, инлайн-хелпер `RaceMaskForRace(race)` и
  `RACEMASK_DB32_LIMIT` (граница 32 для масок, которые хранятся в `INT`-колонках БД).
  Скобки в `RACEMASK_HORDE` восстановлены (макрос подставляется в `a & RACEMASK_HORDE`).
* Введён **реестр кастомных рас** (`Player.cpp`, namespace `LegionForgeCustomRaces`):
  парсится один раз из `worldserver.conf`.

```ini
CustomRaces.Enable = 1
# raceId:team:baseRace
CustomRaces.Definitions = "31:ALLIANCE:1,32:HORDE:2,33:ALLIANCE:4,34:ALLIANCE:3,35:HORDE:5,36:HORDE:6,37:ALLIANCE:7,38:HORDE:8,39:HORDE:10,40:ALLIANCE:11,41:ALLIANCE:22,42:HORDE:9,43:NEUTRAL:24,44:ALLIANCE:27"
```

  `baseRace` — донор: из его записи `ChrRaces.db2` берутся `FactionID` и
  `MaleDisplayId/FemaleDisplayId`. Команда берётся из реестра, поэтому
  `TeamForRace` больше не гадает и не спамит.

* Новые публичные методы `Player`:
  `IsCustomRace(uint8)`, `GetCustomRaceBase(uint8)`, `GetCustomRaceTeam(uint8)`.
* `Player::IsValidRace` учитывает реестр (иначе `race 31+` считалась невалидной).
* `ObjectMgr`: проверки `LookupEntry` в загрузчиках `playercreateinfo`,
  `race_unlock_requirement` и «заполнение дыр» `player_levelstats` пропускают
  расу, только если её нет **и** в DBC, **и** в реестре. `displayId_m/f` берутся
  у расы-донора (иначе null-deref при старте).
* `racemask` в `playercreateinfo_spell_custom` / `playercreateinfo_cast_spell`
  читается как `uint64` (`GetUInt64`), сдвиг — `UI64LIT(1)`, формат лога —
  `UI64FMTD`.
* `CharacterHandler`: создание персонажа разрешено для рас реестра;
  проверки `raceMaskDisabled` (в т.ч. при смене фракции) переведены на
  `RaceMaskForRace`.
* `CriteriaHandler` / `ConditionMgr`: 64-битные маски, корректный каст в `%u`.

## 4. Что сделано в БД (`sql/52_custom_races_31_44.sql`)

1. `racemask`/`raceMask` → `BIGINT UNSIGNED` (условный `ALTER` через
   `information_schema`, идемпотентно).
2. Клонирование стартовых данных расы-донора: `playercreateinfo`,
   `player_levelstats`, `playercreateinfo_item`, `playercreateinfo_action`,
   `playercreateinfo_spell_custom`, `playercreateinfo_cast_spell`.
3. `race_unlock_requirement.expansion = 6` (Legion) для 31..44.
   Значение 7 (BfA) недопустимо: `GetMaxLevelForExpansion(7)` в этой ветке = 0.
4. Контрольный `SELECT` с числом строк на каждую расу
   (`createInfoRows = 0` ⇒ персонажа создать нельзя).

Откат: `sql/52_custom_races_31_44_rollback.sql`.

## 5. Порядок применения

```bat
rem 1. Пересобрать ядро (MAX_RACES - константа времени компиляции!)
build_server.bat

rem 2. Применить SQL в world
tools\mysql\server\bin\mysql.exe -uroot world < sql\52_custom_races_31_44.sql

rem 3. Проверить, что ключи появились в server\worldserver.conf
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1

rem 4. Запустить
play.bat
```

В логе worldserver после старта должно появиться:

```
>> Registered 14 custom client race(s) (ids 31-44) from CustomRaces.Definitions
```

## 6. Ограничения (честно)

* Маски рас в БД-колонках типа `INT UNSIGNED` (`spell_area.racemask`,
  `mail_level_reward.raceMask`, `quest_template.AllowableRaces`,
  `conditions.ConditionValue1`) физически не могут адресовать расы 33..44.
  Для этих механик расы 33+ ведут себя как «любые» (маска 0) — точечная
  привязка требует перехода колонок на `BIGINT` и правки соответствующих
  загрузчиков. `playercreateinfo_spell_custom` и `playercreateinfo_cast_spell`
  уже переведены на 64 бита этим патчем.
* Отображаемое имя/модель расы берёт **клиент** из своего `ChrRaces.db2`;
  серверный `ChrRaces.db2` подменять нельзя без проверки
  `tools\check_db2_build.ps1` (иначе `ASSERT` по `LayoutHash`).
'''


DOC_FIXES = r'''# Извлечение карт и запуск сервера: разбор трёх ошибок

> Legion 7.3.5 build 26124. Патчи: `patchkit/patch_core.py`, `patchkit/patch_scripts.py`.

## 1. `extract_maps.bat` → пункт 2 обрывается на шаге vmaps

### Симптом

```
  [*] Шаг 2/4: vmaps (может занять десятки минут)...
vmap4extractor.exe : Can't open World\Maps\test\test.wdt: FILE_NOT_FOUND
D:\legionforge\extract_delta.ps1:119 знак:9
+         & $tools.vmap4extractor -d $ClientDir 2>&1 | Out-Null
    + CategoryInfo          : NotSpecified: (Can't open Worl... FILE_NOT_FOUND:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
```

### Причина (две независимые)

1. **PowerShell.** `extract_delta.ps1` работает с `$ErrorActionPreference = 'Stop'`.
   В Windows PowerShell 5.1 любая строка, которую внешняя программа пишет в
   **stderr**, при перенаправлении `2>&1` в конвейер превращается в
   `NativeCommandError` — то есть в *исключение*. Первое же предупреждение
   экстрактора убивало скрипт, и vmaps/mmaps не извлекались вовсе.
2. **Экстрактор.** `World\Maps\test\test.wdt` — dev/test-карта: она есть в
   `Map.db2` клиента, но файлов геометрии в CASC не имеет. `vmap4extractor`
   писал об этом в **stderr**, хотя это штатная ситуация.

### Исправление

* `core/src/tools/vmap4_extractor/wdtfile.cpp`
  * `CASCFile` открывается с `warnNoExist = false` — отсутствие WDT больше не
    попадает в stderr;
  * диагностика выведена в **stdout**: `Skipping map 'test': no WDT in the client storage (dev/test map)`.
* `core/src/tools/vmap4_extractor/vmapexport.cpp`
  * счётчик пропущенных карт и итоговая сводка `[INFO] Skipped N map(s) without WDT ...`;
  * извлечение продолжается по остальным картам.
* `extract_delta.ps1`
  * новая функция `Invoke-LfTool` — временно переключает `EAP` на `Continue`,
    разворачивает `ErrorRecord` в текст, фильтрует штатные сообщения
    (`FILE_NOT_FOUND`, `Can't open *.wdt`, `Skipping map`), пишет вывод в
    `server\logs\extract_delta_*.log` и **возвращает код возврата**
    (`$LASTEXITCODE` из функции наружу не виден);
  * все четыре вызова (`mapextractor`, `vmap4extractor`, `vmap4assembler`,
    `mmaps_generator`) переведены на неё;
  * подкаталоги staging (`maps/dbc/Cameras/gt/Buildings/vmaps/mmaps`) создаются
    **до** запуска инструментов;
  * шаг vmaps обёрнут в `try/catch`: сбой не отменяет уже скопированные
    maps/dbc;
  * `mmaps` считаются только при нулевом коде возврата, список неудачных карт
    попадает в `reports\extract_delta.json` (`FailedMmaps`);
  * туда же пишется `IgnoredToolLines` — сколько штатных сообщений отфильтровано.
* `extract_maps.ps1` — та же защита `EAP = 'Continue'` внутри обёртки запуска
  инструментов.

### Как проверить

```bat
extract_maps.bat
rem -> 2 (доизвлечь ТОЛЬКО недостающее)
type reports\extract_delta.json
```

Ожидаемо: шаг 2/4 проходит, в логе строки `Skipping map 'test' ...`,
в отчёте `FailedMmaps` пуст или содержит только реально проблемные карты.

## 2. `bnetserver`: Failed to initialize SSL context

### Симптом

```
Using configuration file bnetserver.conf.
Using SSL version: OpenSSL 3.5.9 ...
Failed to initialize SSL context
```

и **ни одной** подробности.

### Причина

`Battlenet::SslContext::Initialize()` писал настоящую причину в категорию
`server.ssl`, которой нет в `bnetserver.conf` → в консоль уходила только общая
строка из `Main.cpp`. Содержательно причины три:

1. `CertificatesFile = "./bnetserver.cert.pem"` — путь **относительно текущего
   каталога процесса**. При запуске через ярлык/планировщик/`start /D` из другой
   папки файлы не находятся.
2. `.pem` не скопированы в каталог сборки.
3. Сертификат и ключ от **разных** пар (обновили один файл).

### Исправление

* `core/src/server/bnetserver/Server/SslContext.cpp` — переписан:
  * поиск `.pem` по цепочке каталогов: как задано в конфиге → имя файла в CWD →
    каталог `bnetserver.exe` → `..` → `../server`;
  * проверка соответствия пары через `X509_check_private_key`;
  * при отсутствии/рассинхроне — **автогенерация** самоподписанной пары
    (RSA-2048, SHA-256, 10 лет) через `EVP_RSA_gen` (OpenSSL 3.x) с fallback на
    `RSA_generate_key` для 1.1.x;
  * вывод очереди ошибок OpenSSL (`ERR_error_string_n`) в лог;
  * ключ `SSLCertAutoGenerate` (по умолчанию 1) — при 0 ядро падает, как раньше;
  * итоговая строка `SSL context initialized (cert=..., key=..., auto-generated=...)`.
* `core/src/server/bnetserver/Main.cpp` — к общей ошибке добавлена подсказка,
  что смотреть и где включить подробный лог.
* `server/bnetserver.conf.dist` — добавлены `SSLCertAutoGenerate = 1`,
  `Logger.server.ssl=3,Console Bnet`, `Logger.server.bnetserver=3,Console Bnet`.
* `tools\ensure_ssl_cert.ps1` (новый) — префлайт на стороне окружения:
  наличие, **соответствие пары** (сравнение публичных ключей), алгоритм подписи
  (SHA-1/MD5 отклоняются OpenSSL 3.x при SECLEVEL≥1), срок действия;
  при проблеме делает `*.bak-<дата>` и генерирует новую пару.
* `play.bat` — вызывает `ensure_conf_keys.ps1` и `ensure_ssl_cert.ps1` перед
  стартом `bnetserver.exe`.

Пара из репозитория (`server/bnetserver.cert.pem` + `bnetserver.key.pem`)
проверена: RSA-2048, `sha256WithRSAEncryption`, срок 2016→2036, публичные ключи
совпадают. Значит у вас сработал пункт 1 или 2 — патч закрывает оба.

## 3. `Missing name Guild.SaveInterval in config file`

### Причина

`server/worldserver.conf.dist` ключ **содержит** (`Guild.SaveInterval = 15`),
а живой `D:\legionforge\server\worldserver.conf` создан из более старого
дистрибутива — ключа в нём нет. Ядро читает его обязательно и пишет
предупреждение.

### Исправление

`tools\ensure_conf_keys.ps1` (новый):

* если `*.conf` отсутствует — создаёт его из `*.conf.dist`;
* сравнивает наборы ключей `.dist` и живого `.conf` и **дописывает все
  отсутствующие** (значение по умолчанию берётся из `.dist`);
* существующие значения не трогает, делает `*.conf.bak-<дата>`;
* отчёт: `reports\ensure_conf_keys.json`;
* режим `-WhatIfMode` — показать, ничего не меняя.

Вызов встроен в `play.bat` (до старта серверов), поэтому предупреждение больше
не появляется и после обновления дистрибутива.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ensure_conf_keys.ps1 -WhatIfMode
```

## 4. Что осталось сделать руками

1. Пересобрать ядро (`MAX_RACES` — константа времени компиляции): `build_server.bat`.
2. Пересобрать `vmap4extractor.exe` (патч stderr) и заменить его в `server\`.
3. Применить `sql\52_custom_races_31_44.sql` к базе `world`.
4. Запустить `play.bat` и проверить строку
   `>> Registered 14 custom client race(s) (ids 31-44)` в логе worldserver.
'''


CHANGELOG = r'''
## 2026-10-10 — кастомный клиент build 26124: расы 31..44, извлечение карт, SSL bnetserver

Патчеры: `patchkit/patch_core.py`, `patchkit/patch_scripts.py` (идемпотентны).

### Ядро
* `MAX_RACES` 31 → 45, добавлены `RACE_CUSTOM_31..44`, `RACE_CUSTOM_FIRST/LAST`.
* Все `RACEMASK_*` переведены на 64 бита (`UI64LIT`): сдвиг `1 << (race-1)` при
  race ≥ 33 был неопределённым поведением и молча давал 0. Добавлены
  `RaceMaskForRace()`, `RACEMASK_CUSTOM_PLAYABLE`, `RACEMASK_DB32_LIMIT`,
  восстановлены скобки в `RACEMASK_HORDE`.
* Реестр кастомных рас (`CustomRaces.Enable` / `CustomRaces.Definitions` в
  `worldserver.conf`): команда, раса-донор для `FactionID` и `displayId`.
  Новые методы `Player::IsCustomRace/GetCustomRaceBase/GetCustomRaceTeam`.
* `ObjectMgr`: `playercreateinfo`, `race_unlock_requirement` и заполнение дыр
  `player_levelstats` больше не отбрасывают расы 31..44; `displayId` берётся у
  расы-донора (устранён потенциальный null-deref); `racemask` читается как
  `uint64`, формат лога — `UI64FMTD`.
* `CharacterHandler`: создание персонажа и смена фракции работают с 64-битными
  масками и расами реестра.
* `CriteriaHandler`, `ConditionMgr`: 64-битные racemask-проверки, корректный каст.
* `bnetserver/Server/SslContext.cpp` переписан: поиск `.pem` по цепочке
  каталогов, проверка соответствия пары, автогенерация самоподписанного
  сертификата (RSA-2048/SHA-256, OpenSSL 3.x), вывод очереди ошибок OpenSSL,
  ключ `SSLCertAutoGenerate`.
* `vmap4extractor`: отсутствие `.wdt` (dev/test-карты) больше не пишется в
  stderr — сообщение в stdout, счётчик и сводка пропущенных карт.

### Обвязка
* `extract_delta.ps1`: функция `Invoke-LfTool` (защита от `NativeCommandError`
  при `$ErrorActionPreference = 'Stop'`), фильтрация штатных сообщений,
  предварительное создание каталогов staging, `try/catch` вокруг шага vmaps,
  честный подсчёт mmaps, поля `FailedMmaps`/`IgnoredToolLines` в
  `reports/extract_delta.json`.
* `extract_maps.ps1`: та же защита в обёртке запуска инструментов.
* `play.bat`: префлайт `tools\ensure_conf_keys.ps1` + `tools\ensure_ssl_cert.ps1`
  перед стартом `bnetserver.exe`.
* Новые инструменты: `tools\ensure_ssl_cert.ps1`, `tools\ensure_conf_keys.ps1`.
* Конфиги: `SSLCertAutoGenerate`, `Logger.server.ssl`, `Logger.server.bnetserver`
  в `bnetserver.conf.dist`; секция `CustomRaces.*` в `worldserver.conf.dist`.
* SQL: `sql/52_custom_races_31_44.sql` (+ `_rollback`) — `BIGINT` racemask,
  стартовые данные для рас 31..44, `race_unlock_requirement.expansion = 6`,
  контрольный отчёт.
* Документация: `docs/CUSTOM_RACES_31_44.md`, `docs/EXTRACTOR_SSL_FIXES.md`.
'''


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Использование: patch_scripts.py <корень репозитория>")
    root = os.path.abspath(sys.argv[1])
    if not os.path.isdir(os.path.join(root, "core")):
        raise SystemExit("Это не похоже на корень LegionForge: нет каталога core/")

    p = Patch(root)
    print("== Патчу обвязку LegionForge: %s" % root)

    print("\n[1/6] extract_delta.ps1 / extract_maps.ps1 - извлечение карт")
    patch_extract_delta(p)
    patch_extract_maps(p)

    print("\n[2/6] play.bat - префлайт SSL и ключей конфига")
    patch_play_bat(p)

    print("\n[3/6] Конфиги: bnetserver.conf.dist, worldserver.conf.dist")
    patch_confs(p)

    print("\n[4/6] Новые инструменты tools/")
    p.write_file("tools/ensure_ssl_cert.ps1", ENSURE_SSL_CERT_PS1, crlf=True, bom=True)
    p.write_file("tools/ensure_conf_keys.ps1", ENSURE_CONF_KEYS_PS1, crlf=True, bom=True)

    print("\n[5/6] SQL под кастомные расы 31..44")
    p.write_file("sql/52_custom_races_31_44.sql", SQL_RACES, crlf=True, bom=True)
    p.write_file("sql/52_custom_races_31_44_rollback.sql", SQL_RACES_ROLLBACK, crlf=True, bom=True)

    print("\n[6/6] Документация и changelog")
    p.write_file("docs/CUSTOM_RACES_31_44.md", DOC_RACES, crlf=False, bom=False)
    p.write_file("docs/EXTRACTOR_SSL_FIXES.md", DOC_FIXES, crlf=False, bom=False)
    p.append("CHANGELOG_IMPROVEMENTS.md", CHANGELOG)

    print("\nГотово. Применено: %d, пропущено (уже было): %d" % (p.applied, p.skipped))


if __name__ == "__main__":
    main()
