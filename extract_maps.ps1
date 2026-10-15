param(
    [Parameter(Mandatory = $true)]
    [string]$ClientDir,

    [Parameter(Mandatory = $true)]
    [string]$ServerDir,

    [ValidateSet("none", "priority", "all", "prompt")]
    [string]$MmapsMode = "prompt"
)

$ErrorActionPreference = "Stop"

# mapextractor already walks every Map.db2 entry. We verify continents (required)
# and a dungeon/raid from each expansion through Legion (warn if blank).
$VerifyMaps = @(
    # Continents - missing these = incomplete client, extract fails
    @{ Id = 0;    Name = "Eastern Kingdoms"; Exp = "Vanilla"; Required = $true;  MinTiles = 80 },
    @{ Id = 1;    Name = "Kalimdor";         Exp = "Vanilla"; Required = $true;  MinTiles = 80 },
    @{ Id = 530;  Name = "Outland";          Exp = "BC";      Required = $true;  MinTiles = 25 },
    @{ Id = 571;  Name = "Northrend";        Exp = "WotLK";   Required = $true;  MinTiles = 30 },
    @{ Id = 646;  Name = "Deepholm";         Exp = "Cata";    Required = $true;  MinTiles = 5 },
    @{ Id = 870;  Name = "Pandaria";         Exp = "MoP";     Required = $true;  MinTiles = 25 },
    @{ Id = 1116; Name = "Draenor";          Exp = "WoD";     Required = $true;  MinTiles = 25 },
    @{ Id = 1220; Name = "Broken Isles";     Exp = "Legion";  Required = $true;  MinTiles = 40 },
    @{ Id = 1669; Name = "Argus";            Exp = "Legion";  Required = $true;  MinTiles = 8 },

    # Vanilla instances (indoor WMO maps often have 0 .map tiles; vmaps count)
    @{ Id = 33;   Name = "Shadowfang Keep";        Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 34;   Name = "The Stockade";           Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 36;   Name = "Deadmines";              Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 43;   Name = "Wailing Caverns";        Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 47;   Name = "Razorfen Kraul";         Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 48;   Name = "Blackfathom Deeps";      Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 70;   Name = "Uldaman";                Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 90;   Name = "Gnomeregan";             Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 109;  Name = "Sunken Temple";          Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 129;  Name = "Razorfen Downs";         Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 189;  Name = "Scarlet Monastery";      Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 209;  Name = "Zul'Farrak";             Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 229;  Name = "Blackrock Spire";        Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 230;  Name = "Blackrock Depths";       Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 249;  Name = "Onyxia's Lair";          Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 289;  Name = "Scholomance";            Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 309;  Name = "Zul'Gurub";              Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 329;  Name = "Stratholme";             Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 349;  Name = "Maraudon";               Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 389;  Name = "Ragefire Chasm";         Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 409;  Name = "Molten Core";            Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 429;  Name = "Dire Maul";              Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 469;  Name = "Blackwing Lair";         Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 509;  Name = "Ruins of Ahn'Qiraj";     Exp = "Vanilla"; Required = $false; MinTiles = 0 },
    @{ Id = 531;  Name = "Temple of Ahn'Qiraj";    Exp = "Vanilla"; Required = $false; MinTiles = 0 },

    # Burning Crusade
    @{ Id = 532;  Name = "Karazhan";               Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 534;  Name = "Hyjal Summit";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 540;  Name = "Shattered Halls";        Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 542;  Name = "Blood Furnace";          Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 543;  Name = "Hellfire Ramparts";      Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 544;  Name = "Magtheridon's Lair";     Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 545;  Name = "The Steamvault";         Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 546;  Name = "The Underbog";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 547;  Name = "The Slave Pens";         Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 548;  Name = "Serpentshrine Cavern";   Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 550;  Name = "Tempest Keep";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 552;  Name = "The Arcatraz";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 553;  Name = "The Botanica";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 554;  Name = "The Mechanar";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 555;  Name = "Shadow Labyrinth";       Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 556;  Name = "Sethekk Halls";          Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 557;  Name = "Mana-Tombs";             Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 558;  Name = "Auchenai Crypts";        Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 560;  Name = "Old Hillsbrad";          Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 564;  Name = "Black Temple";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 565;  Name = "Gruul's Lair";           Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 568;  Name = "Zul'Aman";               Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 580;  Name = "Sunwell Plateau";        Exp = "BC"; Required = $false; MinTiles = 0 },
    @{ Id = 585;  Name = "Magisters' Terrace";     Exp = "BC"; Required = $false; MinTiles = 0 },

    # Wrath of the Lich King
    @{ Id = 533;  Name = "Naxxramas";              Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 574;  Name = "Utgarde Keep";           Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 575;  Name = "Utgarde Pinnacle";       Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 576;  Name = "The Nexus";              Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 578;  Name = "The Oculus";             Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 595;  Name = "Culling of Stratholme";  Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 599;  Name = "Halls of Stone";          Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 600;  Name = "Drak'Tharon Keep";       Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 601;  Name = "Azjol-Nerub";            Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 602;  Name = "Halls of Lightning";     Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 603;  Name = "Ulduar";                 Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 604;  Name = "Gundrak";                Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 608;  Name = "Violet Hold";            Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 615;  Name = "Obsidian Sanctum";       Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 616;  Name = "Eye of Eternity";        Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 619;  Name = "Ahn'kahet";              Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 624;  Name = "Vault of Archavon";      Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 631;  Name = "Icecrown Citadel";       Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 632;  Name = "Forge of Souls";         Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 649;  Name = "Trial of the Crusader";  Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 650;  Name = "Trial of the Champion";  Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 658;  Name = "Pit of Saron";           Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 668;  Name = "Halls of Reflection";    Exp = "WotLK"; Required = $false; MinTiles = 0 },
    @{ Id = 724;  Name = "Ruby Sanctum";           Exp = "WotLK"; Required = $false; MinTiles = 0 },

    # Cataclysm
    @{ Id = 643;  Name = "Throne of the Tides";    Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 644;  Name = "Halls of Origination";   Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 645;  Name = "Blackrock Caverns";      Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 657;  Name = "Vortex Pinnacle";        Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 669;  Name = "Blackwing Descent";      Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 670;  Name = "Grim Batol";             Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 671;  Name = "Bastion of Twilight";    Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 720;  Name = "Firelands";              Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 725;  Name = "The Stonecore";          Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 754;  Name = "Throne of the Four Winds"; Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 755;  Name = "Lost City of the Tol'vir"; Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 938;  Name = "End Time";               Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 939;  Name = "Well of Eternity";       Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 940;  Name = "Hour of Twilight";       Exp = "Cata"; Required = $false; MinTiles = 0 },
    @{ Id = 967;  Name = "Dragon Soul";            Exp = "Cata"; Required = $false; MinTiles = 0 },

    # Mists of Pandaria
    @{ Id = 959;  Name = "Shado-Pan Monastery";    Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 960;  Name = "Temple of the Jade Serpent"; Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 961;  Name = "Stormstout Brewery";     Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 962;  Name = "Gate of the Setting Sun"; Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 994;  Name = "Mogu'shan Palace";       Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 996;  Name = "Terrace of Endless Spring"; Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1001; Name = "Scarlet Halls";          Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1004; Name = "Scarlet Monastery";      Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1007; Name = "Scholomance";            Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1008; Name = "Mogu'shan Vaults";       Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1009; Name = "Heart of Fear";          Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1011; Name = "Siege of Niuzao Temple"; Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1098; Name = "Throne of Thunder";      Exp = "MoP"; Required = $false; MinTiles = 0 },
    @{ Id = 1136; Name = "Siege of Orgrimmar";     Exp = "MoP"; Required = $false; MinTiles = 0 },

    # Warlords of Draenor
    @{ Id = 1175; Name = "Bloodmaul Slag Mines";   Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1176; Name = "Shadowmoon Burial Grounds"; Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1182; Name = "Auchindoun";             Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1195; Name = "Iron Docks";             Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1205; Name = "Blackrock Foundry";      Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1208; Name = "Grimrail Depot";         Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1209; Name = "Skyreach";               Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1228; Name = "Highmaul";               Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1279; Name = "The Everbloom";          Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1358; Name = "Upper Blackrock Spire";  Exp = "WoD"; Required = $false; MinTiles = 0 },
    @{ Id = 1448; Name = "Hellfire Citadel";       Exp = "WoD"; Required = $false; MinTiles = 0 },

    # Legion
    @{ Id = 1456; Name = "Eye of Azshara";         Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1458; Name = "Neltharion's Lair";      Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1466; Name = "Darkheart Thicket";      Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1477; Name = "Halls of Valor";         Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1492; Name = "Maw of Souls";           Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1493; Name = "Vault of the Wardens";   Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1501; Name = "Black Rook Hold";        Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1516; Name = "The Arcway";             Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1544; Name = "Violet Hold";            Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1571; Name = "Court of Stars";         Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1651; Name = "Return to Karazhan";     Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1677; Name = "Cathedral of Eternal Night"; Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1753; Name = "Seat of the Triumvirate"; Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1520; Name = "Emerald Nightmare";      Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1530; Name = "The Nighthold";          Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1648; Name = "Trial of Valor";         Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1676; Name = "Tomb of Sargeras";       Exp = "Legion"; Required = $false; MinTiles = 0 },
    @{ Id = 1712; Name = "Antorus";                Exp = "Legion"; Required = $false; MinTiles = 0 }
)

# Pathfinding for every verified continent + playable instance. Test/dev maps stay skipped.
$PriorityMmapIds = @(
    $VerifyMaps | ForEach-Object { $_.Id }
)

function Write-Log([string]$message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $message
    Write-Host $line
    Add-Content -LiteralPath $script:LogFile -Value $line
}

function Invoke-Logged([string]$exe, [string[]]$exeArgs, [string]$workDir) {
    Write-Log ("RUN: {0} {1}" -f $exe, ($exeArgs -join " "))
    Write-Log ("CWD: {0}" -f $workDir)
    $p = Start-Process -FilePath $exe -ArgumentList $exeArgs -WorkingDirectory $workDir -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $script:ToolOut -RedirectStandardError $script:ToolErr
    if (Test-Path -LiteralPath $script:ToolOut) {
        Get-Content -LiteralPath $script:ToolOut | Add-Content -LiteralPath $script:LogFile
    }
    if (Test-Path -LiteralPath $script:ToolErr) {
        Get-Content -LiteralPath $script:ToolErr | Add-Content -LiteralPath $script:LogFile
    }
    Write-Log ("exit code {0}" -f $p.ExitCode)
    return $p.ExitCode
}

function Get-MapTileCount([string]$mapsDir, [int]$mapId) {
    $prefix = "{0:D4}_" -f $mapId
    return @(Get-ChildItem -LiteralPath $mapsDir -Filter ($prefix + "*.map") -ErrorAction SilentlyContinue).Count
}

function Test-HasVmap([string]$vmapsDir, [int]$mapId) {
    $tree = Join-Path $vmapsDir ("{0:D4}.vmtree" -f $mapId)
    return (Test-Path -LiteralPath $tree)
}

$ClientDir = (Resolve-Path -LiteralPath $ClientDir).Path
$ServerDir = (Resolve-Path -LiteralPath $ServerDir).Path
$DataDir   = Join-Path $ServerDir "data"
$WorkDir   = Join-Path $ServerDir "setup_tmp\vmap_work"
$script:LogFile = Join-Path $ServerDir "extraction_chain.log"
$script:ToolOut = Join-Path $ServerDir "setup_tmp\tool_out.txt"
$script:ToolErr = Join-Path $ServerDir "setup_tmp\tool_err.txt"

New-Item -ItemType Directory -Force -Path (Join-Path $ServerDir "setup_tmp") | Out-Null
Set-Content -LiteralPath $script:LogFile -Value ("extraction start {0}" -f (Get-Date))

Write-Host ""
Write-Host " ========================================================="
Write-Host "  Map / VMap extraction (Vanilla through Legion)"
Write-Host " ========================================================="
Write-Host ""
Write-Log "ClientDir = $ClientDir"
Write-Log "ServerDir = $ServerDir"
Write-Log "DataDir   = $DataDir"

$dataFolder = Join-Path $ClientDir "Data"
if (-not (Test-Path -LiteralPath $dataFolder -PathType Container)) {
    Write-Log "ERROR: Client Data folder not found: $dataFolder"
    Write-Host "  [!] The folder you pointed at is not a WoW client."
    Write-Host "      It must contain a Data\ directory (CASC)."
    exit 1
}

# Hellgarve / custom clients often ship CASC data without .build.info.
# CascLib will not report locales (and mapextractor exits) until this exists.
$buildInfo = Join-Path $ClientDir ".build.info"
if (-not (Test-Path -LiteralPath $buildInfo)) {
    $buildKey = $null
    $cdnKey = $null
    $installKey = $null
    $versionName = "7.3.5.25996"
    $configRoot = Join-Path $dataFolder "config"
    if (Test-Path -LiteralPath $configRoot) {
        Get-ChildItem -LiteralPath $configRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $head = Get-Content -LiteralPath $_.FullName -TotalCount 2 -ErrorAction SilentlyContinue
            $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $text) { return }
            if ($head -match "Build Configuration") {
                $buildKey = $_.Name
                if ($text -match "install\s*=\s*([0-9a-f]{32})") { $installKey = $Matches[1] }
                if ($text -match "build-name\s*=\s*WOW-(\d+)") { $versionName = "7.3.5.$($Matches[1])" }
            }
            elseif ($head -match "CDN Configuration") {
                $cdnKey = $_.Name
            }
        }
    }
    if ($buildKey -and $cdnKey) {
        if (-not $installKey) { $installKey = $buildKey }
        $header = "Branch!STRING:0|Active!DEC:1|Build Key!HEX:16|CDN Key!HEX:16|Install Key!HEX:16|IM Size!DEC:4|CDN Path!STRING:0|CDN Hosts!STRING:0|CDN Servers!STRING:0|Tags!STRING:0|Armadillo!STRING:0|Last Activated!STRING:0|Version Name!STRING:0|KeyRing!HEX:16"
        $row = "wow|1|$buildKey|$cdnKey|$installKey||tpr/wow|http://level3.blizzard.com http://us.cdn.blizzard.com||enUS|0||$versionName|"
        Set-Content -LiteralPath $buildInfo -Value ($header + "`n" + $row) -Encoding ASCII
        Write-Log "Wrote missing .build.info (build=$buildKey locale=enUS)"
        Write-Host "  [OK] Created client .build.info so CascLib can open this store."
    }
    else {
        Write-Log "WARNING: no CASC config hashes found; extract may fail with FILE_NOT_FOUND"
    }
}

$dataSize = (Get-ChildItem -LiteralPath $dataFolder -Recurse -File -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
if (-not $dataSize) { $dataSize = 0 }
$dataGb = [math]::Round($dataSize / 1GB, 2)
Write-Log ("Client Data size ~ {0} GB" -f $dataGb)
if ($dataGb -lt 20) {
    Write-Host "  [!] Client Data\ is only $dataGb GB. A full 7.3.5 client is usually 40+ GB."
    Write-Host "      Missing ADT tiles become invisible holes you fall through."
    Write-Log "WARNING: client Data looks incomplete"
}

$tools = @{
    mapextractor   = Join-Path $ServerDir "mapextractor.exe"
    vmap4extractor = Join-Path $ServerDir "vmap4extractor.exe"
    vmap4assembler = Join-Path $ServerDir "vmap4assembler.exe"
    mmaps_generator = Join-Path $ServerDir "mmaps_generator.exe"
}
foreach ($name in @("mapextractor", "vmap4extractor", "vmap4assembler")) {
    if (-not (Test-Path -LiteralPath $tools[$name])) {
        Write-Log "ERROR: missing $($tools[$name])"
        Write-Host "  [!] $($name).exe not found in server\. Run setup.bat to download binaries first."
        exit 1
    }
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# ---- maps + dbc + cameras + gt ----
# Write straight into server\data. Do NOT extract into the client and move.
Write-Host "  [*] Extracting maps + DBC (height data; missing tiles = fall through)"
Write-Host "      15-40 minutes depending on disk speed."
$code = Invoke-Logged $tools.mapextractor @("-i", $ClientDir, "-o", $DataDir) $ClientDir
if ($code -ne 0) {
    Write-Log "mapextractor failed"
    Write-Host "  [!] mapextractor exited $code. See $script:LogFile"
    exit 1
}

$mapsDir = Join-Path $DataDir "maps"
$dbcDir  = Join-Path $DataDir "dbc"
if (-not (Test-Path -LiteralPath $mapsDir)) {
    Write-Log "ERROR: maps folder was not created"
    Write-Host "  [!] mapextractor did not create data\maps. Client CASC open probably failed."
    exit 1
}

$totalMaps = @(Get-ChildItem -LiteralPath $mapsDir -Filter "*.map" -ErrorAction SilentlyContinue).Count
Write-Log ("Total .map tiles: {0}" -f $totalMaps)
if ($totalMaps -lt 200) {
    Write-Host "  [!] Only $totalMaps map tiles extracted. A full 7.3.5 extract is thousands."
    Write-Host "      Locale detection may have failed, or the client Data\ is incomplete."
    Write-Log "ERROR: tile count too low"
    exit 1
}

$verifyFailed = $false
$lastExp = ""
foreach ($m in $VerifyMaps) {
    if (-not $m.Required) { continue }
    $count = Get-MapTileCount $mapsDir $m.Id
    $ok = $count -ge $m.MinTiles
    Write-Log ("{0} [{1}] map {2} tiles={3} min={4} [{5}]" -f $m.Name, $m.Exp, $m.Id, $count, $m.MinTiles, $(if ($ok) { "OK" } else { "LOW" }))
    if ($m.Exp -ne $lastExp) {
        Write-Host ("  --- {0} ---" -f $m.Exp)
        $lastExp = $m.Exp
    }
    if (-not $ok) {
        Write-Host ("  [!] {0} (map {1}) has {2} tiles (need {3}+)." -f $m.Name, $m.Id, $count, $m.MinTiles)
        $verifyFailed = $true
    } else {
        Write-Host ("  [OK] {0}: {1} tiles" -f $m.Name, $count)
    }
}

$hasMapDb2 = @(Get-ChildItem -LiteralPath $dbcDir -Recurse -Filter "Map.db2" -ErrorAction SilentlyContinue).Count -gt 0
if (-not $hasMapDb2) {
    Write-Host "  [!] Map.db2 not found under data\dbc. DBC extract failed."
    Write-Log "ERROR: Map.db2 missing"
    $verifyFailed = $true
}

if ($verifyFailed) {
    Write-Host ""
    Write-Host "  Extraction ran, but a required continent is incomplete (Vanilla-Legion)."
    Write-Host "  Fix the client Data\ (full 7.3.5, not a partial Hellgarve copy) and re-run extract_maps.bat."
    Write-Host "  Log: $script:LogFile"
    exit 1
}
Write-Host "  [OK] Maps and DBC extracted ($totalMaps tiles)."

# ---- vmaps (building / WMO collision) ----
Write-Host ""
Write-Host "  [*] Extracting vmaps (indoor/WMO collision)"
if (Test-Path -LiteralPath $WorkDir) {
    Remove-Item -LiteralPath $WorkDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$code = Invoke-Logged $tools.vmap4extractor @("-d", $ClientDir) $WorkDir
if ($code -ne 0) {
    Write-Log "vmap4extractor failed"
    Write-Host "  [!] vmap4extractor exited $code. See $script:LogFile"
    exit 1
}

$buildings = Join-Path $WorkDir "Buildings"
if (-not (Test-Path -LiteralPath $buildings)) {
    Write-Log "ERROR: Buildings folder missing after vmap extract"
    Write-Host "  [!] vmap extractor produced no Buildings\ folder."
    exit 1
}

$vmapsDir = Join-Path $DataDir "vmaps"
New-Item -ItemType Directory -Force -Path $vmapsDir | Out-Null
$code = Invoke-Logged $tools.vmap4assembler @("Buildings", $vmapsDir) $WorkDir
if ($code -ne 0) {
    Write-Log "vmap4assembler failed"
    Write-Host "  [!] vmap4assembler exited $code."
    exit 1
}

$vmtree = @(Get-ChildItem -LiteralPath $vmapsDir -Filter "*.vmtree" -ErrorAction SilentlyContinue).Count
Write-Log ("vmtree count={0}" -f $vmtree)
if ($vmtree -lt 50) {
    Write-Host "  [!] Only $vmtree vmap trees assembled. Indoor collision will be missing."
    Write-Log "ERROR: vmap coverage too low"
    exit 1
}
Write-Host "  [OK] VMaps assembled ($vmtree trees)."
Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue

# Indoor dungeons are WMO-only: 0 .map tiles is normal if a .vmtree exists.
Write-Host ""
Write-Host "  [*] Verifying every playable continent + dungeon/raid (tiles or vmap)"
$missingInstances = @()
$lastExp = ""
$report = New-Object System.Collections.Generic.List[string]
$report.Add(("map coverage {0}" -f (Get-Date)))
foreach ($m in $VerifyMaps) {
    $count = Get-MapTileCount $mapsDir $m.Id
    $hasVmap = Test-HasVmap $vmapsDir $m.Id
    $ok = if ($m.Required) { $count -ge $m.MinTiles } else { ($count -gt 0) -or $hasVmap }
    $how = if ($count -gt 0 -and $hasVmap) { "tiles+vmap" } elseif ($count -gt 0) { "tiles" } elseif ($hasVmap) { "vmap" } else { "NONE" }
    Write-Log ("{0} [{1}] map {2} tiles={3} vmap={4} [{5}]" -f $m.Name, $m.Exp, $m.Id, $count, $hasVmap, $how)
    $report.Add(("{0,-5} {1,-28} {2,-8} tiles={3,-5} vmap={4,-5} {5}" -f $m.Id, $m.Name, $m.Exp, $count, $hasVmap, $how))
    if ($m.Exp -ne $lastExp) {
        Write-Host ("  --- {0} ---" -f $m.Exp)
        $lastExp = $m.Exp
    }
    if ($ok) {
        Write-Host ("  [OK] {0}: {1}" -f $m.Name, $how)
    } else {
        Write-Host ("  [!] {0} (map {1}) has no tiles and no vmap." -f $m.Name, $m.Id)
        if ($m.Required) { $verifyFailed = $true }
        else { $missingInstances += ("{0} ({1})" -f $m.Name, $m.Exp) }
    }
}
$reportPath = Join-Path $ServerDir "map_coverage.txt"
$report | Set-Content -LiteralPath $reportPath -Encoding ASCII
Write-Log ("Wrote {0}" -f $reportPath)
if ($missingInstances.Count -gt 0) {
    Write-Host ""
    Write-Host "  [!] These playable maps have neither height tiles nor vmaps:"
    foreach ($n in $missingInstances) { Write-Host ("      - {0}" -f $n) }
    Write-Log ("WARNING: uncovered instances: {0}" -f ($missingInstances -join ", "))
} else {
    Write-Host "  [OK] All listed playable maps have tiles and/or vmaps."
}
if ($verifyFailed) {
    Write-Host ""
    Write-Host "  A required continent is still incomplete after vmaps."
    Write-Host "  Log: $script:LogFile"
    exit 1
}

# ---- mmaps ----
if ($MmapsMode -eq "prompt") {
    Write-Host ""
    Write-Host "  Movement maps (mmaps) are for NPC pathfinding, not player fall-through."
    Write-Host "  [P] Priority continents + Legion (recommended, 30-90 min)"
    Write-Host "  [A] All maps (2-6 hours)"
    Write-Host "  [N] Skip"
    $choice = Read-Host "  Generate mmaps? [P/a/n]"
    if ($choice -match '^[Aa]') { $MmapsMode = "all" }
    elseif ($choice -match '^[Nn]') { $MmapsMode = "none" }
    else { $MmapsMode = "priority" }
}

if ($MmapsMode -ne "none") {
    if (-not (Test-Path -LiteralPath $tools.mmaps_generator)) {
        Write-Host "  [!] mmaps_generator.exe missing - skipping mmaps."
        Write-Log "mmaps_generator missing"
    } else {
        $mmapsDir = Join-Path $DataDir "mmaps"
        New-Item -ItemType Directory -Force -Path $mmapsDir | Out-Null
        if ($MmapsMode -eq "all") {
            Write-Host "  [*] Generating ALL mmaps (hours)..."
            $null = Invoke-Logged $tools.mmaps_generator @("--silent") $DataDir
        } else {
            Write-Host "  [*] Generating priority mmaps (Vanilla-Legion continents + dungeons/raids)..."
            foreach ($id in $PriorityMmapIds) {
                Write-Host ("      map {0}" -f $id)
                $null = Invoke-Logged $tools.mmaps_generator @("$id", "--silent") $DataDir
            }
        }
        $mmCount = @(Get-ChildItem -LiteralPath $mmapsDir -Filter "*.mmtile" -ErrorAction SilentlyContinue).Count
        Write-Log ("mmtile count={0}" -f $mmCount)
        Write-Host "  [OK] MMaps: $mmCount tiles."

        $conf = Join-Path $ServerDir "worldserver.conf"
        if (Test-Path -LiteralPath $conf) {
            $text = Get-Content -LiteralPath $conf -Raw
            $text = $text -replace "mmap\.enablePathFinding\s*=\s*0", "mmap.enablePathFinding = 1"
            Set-Content -LiteralPath $conf -Value $text -NoNewline
            Write-Log "Enabled mmap.enablePathFinding in worldserver.conf"
        }
    }
} else {
    Write-Host "  [*] Skipping mmaps. Players will still have collision if maps/vmaps verified."
}

Write-Host ""
Write-Host "  [OK] Extraction finished."
Write-Host "      Height tiles : $mapsDir"
Write-Host "      Collision    : $(Join-Path $DataDir 'vmaps')"
Write-Host "      Log          : $script:LogFile"
Write-Log "extraction complete"
exit 0
