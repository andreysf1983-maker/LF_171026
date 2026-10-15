param(
    [string]$ServerDir = "",
    [int]$Port = 1119,
    [int]$MaxWaitSec = 30
)

if (-not $ServerDir) {
    $ServerDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "server"
}

function Test-PortListen([int]$listenPort) {
    try {
        $listeners = @(Get-NetTCPConnection -LocalPort $listenPort -State Listen -ErrorAction SilentlyContinue)
        if ($listeners.Count -gt 0) { return $true }
    } catch { }

    $netstat = netstat -ano 2>$null | Select-String ":$listenPort" | Select-String "LISTENING"
    return [bool]$netstat
}

$deadline = (Get-Date).AddSeconds($MaxWaitSec)
while ((Get-Date) -lt $deadline) {
    if (Test-PortListen $Port) { exit 0 }
    Start-Sleep -Seconds 1
}

exit 1
