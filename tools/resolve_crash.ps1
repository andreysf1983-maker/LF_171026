[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CrashLog,
    [string]$Executable = '',
    [string]$Root = ''
)

# LEGIONFORGE 7.3.5 - расшифровка адресов из крэш-лога в имена функций.
#
# ЗАЧЕМ. WheatyExceptionReport пишет адреса стека в виде "01:0000000000F3F674" -
# секция PE и смещение внутри неё. Если рядом с worldserver.exe НЕТ worldserver.pdb,
# имена функций в лог не попадают (именно так выглядел дамп от 10.10.2026).
# После пересборки (теперь Release собирается с /Zi и /DEBUG - см.
# core/cmake/compiler/msvc/settings.cmake) PDB появляется, и этот скрипт
# превращает адреса старых и новых логов в "Функция+смещение [файл:строка]".
#
# ВАЖНО: PDB подходит ТОЛЬКО к exe из той же сборки. Лог от бинарника без PDB
# расшифровать нельзя - пересоберите и дождитесь следующего падения.
#
# Запуск (Windows, рядом с сервером):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\resolve_crash.ps1 -CrashLog server\Crashes\<файл>.txt
#
# Выход: 0 - все адреса разобраны; 2 - PDB не найден; 1 - прочие ошибки.

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $Executable) { $Executable = Join-Path $Root 'server\worldserver.exe' }

if (-not (Test-Path -LiteralPath $CrashLog -PathType Leaf)) {
    Write-Host "  [!] Крэш-лог не найден: $CrashLog"
    exit 1
}
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    Write-Host "  [!] Не найден exe: $Executable"
    exit 1
}
$pdbPath = [System.IO.Path]::ChangeExtension($Executable, '.pdb')

# ---------- 1. Секции PE: "01:OFFSET" -> RVA ----------
function Get-PeSections([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x40 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw "${Path}: нет сигнатуры MZ" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    if ([BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x00004550) { throw "${Path}: нет сигнатуры PE" }
    $numSections = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
    $optSize = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
    $secBase = $peOffset + 24 + $optSize
    $sections = @()
    for ($i = 0; $i -lt $numSections; $i++) {
        $off = $secBase + 40 * $i
        $name = [System.Text.Encoding]::ASCII.GetString($bytes, $off, 8).TrimEnd([char]0)
        $sections += [pscustomobject]@{
            Index = $i + 1
            Name = $name
            VirtualSize = [BitConverter]::ToUInt32($bytes, $off + 8)
            VirtualAddress = [BitConverter]::ToUInt32($bytes, $off + 12)
        }
    }
    return $sections
}

$sections = Get-PeSections $Executable
Write-Host ("  [*] {0}: секций PE: {1} ({2})" -f (Split-Path -Leaf $Executable), $sections.Count, (($sections | ForEach-Object { $_.Name }) -join ', '))

# ---------- 2. Адреса из крэш-лога ----------
$exeName = [System.IO.Path]::GetFileName($Executable)
$pattern = '(?<sec>\d{2,4}):(?<off>[0-9A-Fa-f]{8,16})'
$targets = New-Object System.Collections.Generic.List[object]
$lineNo = 0
foreach ($line in [System.IO.File]::ReadLines($CrashLog)) {
    $lineNo++
    if ($line -notmatch [regex]::Escape($exeName)) { continue }
    foreach ($m in [regex]::Matches($line, $pattern)) {
        $sec = [int]$m.Groups['sec'].Value
        $off = [Convert]::ToUInt64($m.Groups['off'].Value, 16)
        $section = $sections | Where-Object { $_.Index -eq $sec } | Select-Object -First 1
        if (-not $section) { continue }
        $targets.Add([pscustomobject]@{
            Line = $lineNo; Text = $line.Trim()
            Section = $sec; Offset = $off
            Rva = [uint64]$section.VirtualAddress + $off
        })
    }
}
if ($targets.Count -eq 0) {
    Write-Host "  [!] В логе нет адресов вида NN:OFFSET со ссылкой на $exeName"
    exit 1
}
Write-Host ("  [*] Найдено адресов для разбора: {0}" -f $targets.Count)

# ---------- 3. dbghelp: RVA -> имя функции ----------
if (-not $IsWindows -and $env:OS -ne 'Windows_NT') {
    Write-Host '  [!] Разбор символов работает только на Windows (dbghelp.dll).'
    Write-Host '      Секции и RVA вычислены; запустите скрипт на машине с сервером.'
    $targets | ForEach-Object { Write-Host ("      строка {0}: секция {1} смещение 0x{2:X} -> RVA 0x{3:X}" -f $_.Line, $_.Section, $_.Offset, $_.Rva) }
    exit 1
}
if (-not (Test-Path -LiteralPath $pdbPath -PathType Leaf)) {
    Write-Host "  [!] Нет файла символов: $pdbPath"
    Write-Host '      Этот лог от сборки без PDB расшифровать нельзя.'
    Write-Host '      Пересоберите сервер (build_worldserver.bat) - Release теперь кладёт worldserver.pdb'
    Write-Host '      рядом с exe, и СЛЕДУЮЩИЙ крэш-лог сам покажет имена функций.'
    exit 2
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DbgHelp
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct SYMBOL_INFO
    {
        public uint SizeOfStruct; public uint TypeIndex; public ulong Reserved1; public ulong Reserved2;
        public uint Index; public uint Size; public ulong ModBase; public uint Flags;
        public ulong Value; public ulong Address; public uint Register; public uint Scope; public uint Tag;
        public uint NameLen; public uint MaxNameLen;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 1024)] public string Name;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct IMAGEHLP_LINE64
    {
        public uint SizeOfStruct; public IntPtr Key; public uint LineNumber; public IntPtr FileName; public ulong Address;
    }
    [DllImport("dbghelp.dll", SetLastError = true)] public static extern bool SymInitialize(IntPtr hProcess, string UserSearchPath, bool fInvadeProcess);
    [DllImport("dbghelp.dll", SetLastError = true)] public static extern bool SymCleanup(IntPtr hProcess);
    [DllImport("dbghelp.dll", SetLastError = true)] public static extern uint SymSetOptions(uint SymOptions);
    [DllImport("dbghelp.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern ulong SymLoadModuleEx(IntPtr hProcess, IntPtr hFile, string ImageName, string ModuleName, ulong BaseOfDll, uint DllSize, IntPtr Data, uint Flags);
    [DllImport("dbghelp.dll", SetLastError = true)] public static extern bool SymFromAddr(IntPtr hProcess, ulong Address, out ulong Displacement, ref SYMBOL_INFO Symbol);
    [DllImport("dbghelp.dll", SetLastError = true)] public static extern bool SymGetLineFromAddr64(IntPtr hProcess, ulong Address, out uint Displacement, ref IMAGEHLP_LINE64 Line);
}
'@

$process = [IntPtr]::new([System.Diagnostics.Process]::GetCurrentProcess().Id)
[void][DbgHelp]::SymSetOptions(0x00000004 -bor 0x00000010)   # DEFERRED_LOADS | LOAD_LINES
if (-not [DbgHelp]::SymInitialize($process, (Split-Path -Parent $Executable), $false)) {
    Write-Host '  [!] SymInitialize не удался.'
    exit 1
}
try {
    $base = [DbgHelp]::SymLoadModuleEx($process, [IntPtr]::Zero, $Executable, $null, 0x10000000, 0, [IntPtr]::Zero, 0)
    if ($base -eq 0) { Write-Host '  [!] SymLoadModuleEx не удался (PDB не подходит к exe?).'; exit 2 }

    Write-Host ''
    Write-Host '  Расшифровка:'
    $resolved = 0
    foreach ($t in $targets) {
        $addr = $base + $t.Rva
        $sym = New-Object DbgHelp+SYMBOL_INFO
        $sym.SizeOfStruct = 88; $sym.MaxNameLen = 1000
        $disp = [uint64]0
        $name = $null
        if ([DbgHelp]::SymFromAddr($process, $addr, [ref]$disp, [ref]$sym)) {
            $name = ('{0}+0x{1:X}' -f $sym.Name, $disp)
            $resolved++
        }
        $lineInfo = ''
        $li = New-Object DbgHelp+IMAGEHLP_LINE64
        $li.SizeOfStruct = [System.Runtime.InteropServices.Marshal]::SizeOf([type][DbgHelp+IMAGEHLP_LINE64])
        $ld = [uint32]0
        if ([DbgHelp]::SymGetLineFromAddr64($process, $addr, [ref]$ld, [ref]$li) -and $li.FileName -ne [IntPtr]::Zero) {
            $file = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($li.FileName)
            $lineInfo = (' [{0}:{1}]' -f $file, $li.LineNumber)
        }
        if ($name) {
            Write-Host ("    {0:d2}:{1:X12}  ->  {2}{3}" -f $t.Section, $t.Offset, $name, $lineInfo)
        } else {
            Write-Host ("    {0:d2}:{1:X12}  ->  (символ не найден, RVA 0x{2:X})" -f $t.Section, $t.Offset, $t.Rva)
        }
    }
    Write-Host ''
    Write-Host ("  [OK] Разобрано {0} из {1} адресов." -f $resolved, $targets.Count)
    if ($resolved -eq 0) { exit 2 }
    exit 0
}
finally {
    [void][DbgHelp]::SymCleanup($process)
}
