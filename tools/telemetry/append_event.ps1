param(
    [Parameter(Mandatory = $true)][string]$RunDir,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$Cat,
    [Parameter(Mandatory = $true)][string]$Evt,
    [string]$Exe = ""
)

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$data = "{}"
if ($Exe) {
    $data = (@{ exe = $Exe } | ConvertTo-Json -Compress)
}
$line = '{"ts":"' + $ts + '","run":"' + $RunId + '","seq":0,"lvl":"info","cat":"' + $Cat + '","evt":"' + $Evt + '","data":' + $data + ',"src":"play.bat"}'
$path = Join-Path $RunDir "events.jsonl"
[System.IO.File]::AppendAllText($path, $line + "`n")
