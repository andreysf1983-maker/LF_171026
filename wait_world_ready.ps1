<#
    LEGIONFORGE readiness gate for worldserver (fixed 2026-10-13).

    WHY THIS FILE WAS THE FAILURE POINT
    ------------------------------------
    The previous version was a SINGLE one-shot check executed immediately
    after "start worldserver.exe". World load on this core takes 1-4 minutes
    (240 DB2 stores ~117 s + World initialization ~224 s), so the script
    always returned "not ready" and play.bat printed
    "[WARNING] worldserver did not confirm readiness" even though the server
    started fine and reached "(worldserver-daemon) ready...".
    On top of that the status regex "worldserver-daemon\\) ready" was
    malformed (literal backslash + unmatched parenthesis) and threw a
    .NET regex exception, which aborted the script before the port fallback
    could ever run.

    NEW BEHAVIOUR
    -------------
    * Polls until -TimeoutSec (default 900 s) expires.
    * Literal string search (.Contains), no regex escaping pitfalls.
    * Readiness = "worldserver-daemon) ready" in the log tail OR port 8085
      listening.
    * Crash detection: worldserver process gone + no ready marker -> "crashed"
      with the last log lines printed.
    * Compatible CLI: -ProgressOnly prints the raw status word, exit code
      0 = ready, 1 = not ready, 2 = crashed.
#>
param(
    [string]$ServerDir = "",
    [int]$Port = 8085,
    [int]$TimeoutSec = 900,
    [switch]$ProgressOnly
)

if (-not $ServerDir) {
    $ServerDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "server"
}

$logPath = Join-Path $ServerDir "Server.log"
$readyLiteral = "worldserver-daemon) ready"
$initializedLiteral = "World initialized"

function Get-LogTail {
    param([string]$Path, [int]$Chars)

    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object System.IO.StreamReader($stream)
            try {
                $all = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            if ($all.Length -gt $Chars) { return $all.Substring($all.Length - $Chars) }
            return $all
        } finally {
            $stream.Dispose()
        }
    } catch {
        return ((Get-Content -LiteralPath $Path -Tail 60 -ErrorAction SilentlyContinue) -join "`n")
    }
}

function Test-PortListen {
    param([int]$ListenPort)
    try {
        $listeners = @(Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction SilentlyContinue)
        if ($listeners.Count -gt 0) { return $true }
    } catch { }
    $netstat = netstat -ano 2>$null | Select-String ":$ListenPort" | Select-String "LISTENING"
    return [bool]$netstat
}

function Test-WorldServerAlive {
    return (@(Get-Process -Name "worldserver" -ErrorAction SilentlyContinue).Count -gt 0)
}

$status = "loading"
$how = ""
$deadline = (Get-Date).AddSeconds([Math]::Max(30, $TimeoutSec))

while ($true) {
    $tail = Get-LogTail -Path $logPath -Chars 262144

    if ($tail -and $tail.Contains($readyLiteral)) {
        $status = "ready"; $how = "log"; break
    }
    if (Test-PortListen -ListenPort $Port) {
        # give the daemon a moment so that "port" never precedes actual init completion
        Start-Sleep -Milliseconds 500
        $status = "ready"; $how = "port"; break
    }

    if (-not (Test-WorldServerAlive)) {
        if ($tail -and $tail.Contains($readyLiteral)) { $status = "ready"; $how = "log"; break }
        # process gone without ever saying ready -> report crash context
        $status = "crashed"; break
    }

    if ((Get-Date) -ge $deadline) {
        if ($tail -and $tail.Contains($initializedLiteral)) { $status = "initialized" }
        break
    }

    Start-Sleep -Seconds 3
}

if ($ProgressOnly) {
    Write-Output $status
    if ($status -eq "ready") { exit 0 } elseif ($status -eq "crashed") { exit 2 } else { exit 1 }
}

switch ($status) {
    "ready" {
        Write-Output $how
        exit 0
    }
    "crashed" {
        Write-Host "  [!] worldserver has terminated before reaching ready state. Last log lines:" -ForegroundColor Red
        (Get-LogTail -Path $logPath -Chars 4000) -split "`n" | Select-Object -Last 25 | ForEach-Object { Write-Host "      $_" }
        exit 2
    }
    "initialized" {
        Write-Output "log-partial"
        exit 1
    }
    default {
        Write-Output "loading-timeout"
        exit 1
    }
}
