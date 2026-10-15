# LEGIONFORGE 7.3.5 - общий модуль чтения заголовков DB2 (WDC1/WDC2/WDC3).
# Подключение:  . (Join-Path $PSScriptRoot 'lf_db2.ps1')
#
# Формат WDC1 (Legion 7.3.5):
#   char[4] magic 'WDC1'
#   uint32  recordCount, fieldCount, recordSize, stringTableSize,
#           tableHash, layoutHash, minId, maxId, locale, copyTableSize
#   uint16  flags, idIndex
#   uint32  totalFieldCount, bitpackedDataOffset, lookupColumnCount,
#           idTableSize, fieldStorageInfoSize, commonDataSize,
#           palletDataSize, sectionCount
#
# Возвращается PSCustomObject, даже если файл чужого формата (Magic = 'WDC2'...).

function Read-LfDb2Header {
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = [pscustomobject]@{
        File        = [System.IO.Path]::GetFileName($Path)
        FullName    = $Path
        Magic       = ''
        RecordCount = 0
        FieldCount  = 0
        RecordSize  = 0
        TableHash   = [uint32]0
        LayoutHash  = [uint32]0
        MinId       = 0
        MaxId       = 0
        Locale      = 0
        Length      = 0
        Ok          = $false
        Error       = ''
    }

    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        $result.Length = $fi.Length
        if ($fi.Length -lt 48) { $result.Error = 'файл короче заголовка'; return $result }

        $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        try {
            $br = New-Object System.IO.BinaryReader($fs)
            $magicBytes = $br.ReadBytes(4)
            $result.Magic = [System.Text.Encoding]::ASCII.GetString($magicBytes)
            $result.RecordCount = [int]$br.ReadUInt32()
            $result.FieldCount = [int]$br.ReadUInt32()
            $result.RecordSize = [int]$br.ReadUInt32()
            $null = $br.ReadUInt32()                  # stringTableSize
            $result.TableHash = $br.ReadUInt32()
            $result.LayoutHash = $br.ReadUInt32()
            $result.MinId = [int]$br.ReadUInt32()
            $result.MaxId = [int]$br.ReadUInt32()
            $result.Locale = [int]$br.ReadUInt32()
            $result.Ok = ($result.Magic -like 'WDC*' -or $result.Magic -like 'WDB*')
        }
        finally { $fs.Dispose() }
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

# Список идентификаторов рас, о которых знает ядро (парсится из SharedDefines.h).
function Get-LfCoreRaceIds {
    param([Parameter(Mandatory = $true)][string]$CoreDir)

    $file = Join-Path $CoreDir 'src\server\game\Miscellaneous\SharedDefines.h'
    $ids = @{}
    if (-not (Test-Path -LiteralPath $file)) { return $ids }
    $text = [System.IO.File]::ReadAllText($file)
    $block = [regex]::Match($text, 'enum\s+Races\s*(?::\s*\w+\s*)?\{([\s\S]*?)\};')
    if (-not $block.Success) { return $ids }
    foreach ($m in [regex]::Matches($block.Groups[1].Value, 'RACE_(\w+)\s*=\s*(\d+)')) {
        $ids[[int]$m.Groups[2].Value] = $m.Groups[1].Value
    }
    return $ids
}

# Справочник рас WoW по идентификаторам (включая расы новых дополнений,
# которые встречаются в кастомных клиентах вроде UWoW).
$script:LfKnownRaces = @{
    1  = @{ Name = 'Human';            Expansion = 'Classic'; Base = 1;  Faction = 'Alliance' }
    2  = @{ Name = 'Orc';              Expansion = 'Classic'; Base = 2;  Faction = 'Horde' }
    3  = @{ Name = 'Dwarf';            Expansion = 'Classic'; Base = 3;  Faction = 'Alliance' }
    4  = @{ Name = 'Night Elf';        Expansion = 'Classic'; Base = 4;  Faction = 'Alliance' }
    5  = @{ Name = 'Undead';           Expansion = 'Classic'; Base = 5;  Faction = 'Horde' }
    6  = @{ Name = 'Tauren';           Expansion = 'Classic'; Base = 6;  Faction = 'Horde' }
    7  = @{ Name = 'Gnome';            Expansion = 'Classic'; Base = 7;  Faction = 'Alliance' }
    8  = @{ Name = 'Troll';            Expansion = 'Classic'; Base = 8;  Faction = 'Horde' }
    9  = @{ Name = 'Goblin';           Expansion = 'Cataclysm'; Base = 9; Faction = 'Horde' }
    10 = @{ Name = 'Blood Elf';        Expansion = 'BC';      Base = 10; Faction = 'Horde' }
    11 = @{ Name = 'Draenei';          Expansion = 'BC';      Base = 11; Faction = 'Alliance' }
    22 = @{ Name = 'Worgen';           Expansion = 'Cataclysm'; Base = 22; Faction = 'Alliance' }
    24 = @{ Name = 'Pandaren (N)';     Expansion = 'MoP';     Base = 24; Faction = 'Neutral' }
    25 = @{ Name = 'Pandaren (A)';     Expansion = 'MoP';     Base = 25; Faction = 'Alliance' }
    26 = @{ Name = 'Pandaren (H)';     Expansion = 'MoP';     Base = 26; Faction = 'Horde' }
    27 = @{ Name = 'Nightborne';       Expansion = 'Legion/BfA'; Base = 10; Faction = 'Horde' }
    28 = @{ Name = 'Highmountain Tauren'; Expansion = 'Legion/BfA'; Base = 6; Faction = 'Horde' }
    29 = @{ Name = 'Void Elf';         Expansion = 'Legion/BfA'; Base = 10; Faction = 'Alliance' }
    30 = @{ Name = 'Lightforged Draenei'; Expansion = 'Legion/BfA'; Base = 11; Faction = 'Alliance' }
    31 = @{ Name = 'Zandalari Troll';  Expansion = 'BfA';     Base = 8;  Faction = 'Horde' }
    32 = @{ Name = 'Kul Tiran';        Expansion = 'BfA';     Base = 1;  Faction = 'Alliance' }
    33 = @{ Name = 'Thin Human (RP)';  Expansion = 'BfA';     Base = 1;  Faction = 'Alliance' }
    34 = @{ Name = 'Dark Iron Dwarf';  Expansion = 'BfA';     Base = 3;  Faction = 'Alliance' }
    35 = @{ Name = 'Vulpera';          Expansion = 'BfA';     Base = 8;  Faction = 'Horde' }
    36 = @{ Name = "Mag'har Orc";      Expansion = 'BfA';     Base = 2;  Faction = 'Horde' }
    37 = @{ Name = 'Mechagnome';       Expansion = 'BfA';     Base = 7;  Faction = 'Alliance' }
    52 = @{ Name = 'Dracthyr (A)';     Expansion = 'Dragonflight'; Base = 1; Faction = 'Alliance' }
    70 = @{ Name = 'Dracthyr (H)';     Expansion = 'Dragonflight'; Base = 2; Faction = 'Horde' }
}

function Get-LfKnownRace([int]$Id) {
    if ($script:LfKnownRaces.ContainsKey($Id)) { return $script:LfKnownRaces[$Id] }
    return @{ Name = ("Custom race #{0}" -f $Id); Expansion = 'Custom'; Base = 1; Faction = 'Unknown' }
}
