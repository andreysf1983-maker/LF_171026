param(
    [string]$ServerDir = ""
)

$ErrorActionPreference = "Stop"
if (-not $ServerDir) { $ServerDir = Join-Path $PSScriptRoot "server" }
$ServerDir = (Resolve-Path -LiteralPath $ServerDir).Path
$DataDir = Join-Path $ServerDir "data"
$gen = Join-Path $ServerDir "mmaps_generator.exe"
$mapsDir = Join-Path $DataDir "maps"
$vmapsDir = Join-Path $DataDir "vmaps"
$mmapsDir = Join-Path $DataDir "mmaps"

if (-not (Test-Path $gen)) { throw "mmaps_generator.exe missing in server\" }
if (-not (Test-Path $mapsDir)) { throw "server\data\maps missing - extract maps first" }

New-Item -ItemType Directory -Force -Path $mmapsDir | Out-Null

$ids = New-Object "System.Collections.Generic.HashSet[int]"
Get-ChildItem -LiteralPath $mapsDir -Filter "*.map" | ForEach-Object {
    [void]$ids.Add([int]$_.Name.Substring(0, 4))
}
if (Test-Path $vmapsDir) {
    Get-ChildItem -LiteralPath $vmapsDir -Filter "*.vmtree" | ForEach-Object {
        [void]$ids.Add([int]$_.BaseName)
    }
}

$todo = $ids | Sort-Object | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $mmapsDir ("{0:D4}.mmap" -f $_)))
}

Write-Host ("Maps with tiles/vmaps: {0}" -f $ids.Count)
Write-Host ("Already have .mmap:    {0}" -f ($ids.Count - $todo.Count))
Write-Host ("Still to generate:     {0}" -f $todo.Count)

$n = 0
foreach ($id in $todo) {
    $n++
    Write-Host ("[{0}/{1}] map {2}" -f $n, $todo.Count, $id)
    $p = Start-Process -FilePath $gen -ArgumentList @("$id", "--silent") -WorkingDirectory $DataDir -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-Host ("  [!] map {0} exited {1}" -f $id, $p.ExitCode)
    }
}

$mm = @(Get-ChildItem $mmapsDir -Filter "*.mmtile" -ErrorAction SilentlyContinue).Count
Write-Host ("Done. mmtile count={0}" -f $mm)
$conf = Join-Path $ServerDir "worldserver.conf"
if (Test-Path $conf) {
    $text = Get-Content $conf -Raw
    $text = $text -replace "mmap\.enablePathFinding\s*=\s*0", "mmap.enablePathFinding = 1"
    Set-Content $conf -Value $text -NoNewline
}
