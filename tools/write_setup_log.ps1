[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [string]$Message = '',
    [string]$InputPath = '',
    [switch]$Initialize
)

$ErrorActionPreference = 'Stop'
$directory = Split-Path -Parent $LogPath
if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true

if ($Initialize) {
    $header = "LEGIONFORGE setup log - UTF-8`r`n[{0}] Installation started`r`n" -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss.fff')
    [System.IO.File]::WriteAllText($LogPath, $header, $utf8Bom)
}

if (-not [string]::IsNullOrWhiteSpace($Message)) {
    $line = "[{0}] {1}`r`n" -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss.fff'), $Message
    [System.IO.File]::AppendAllText($LogPath, $line, $utf8NoBom)
}

if ($InputPath -and (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    $bytes = [System.IO.File]::ReadAllBytes($InputPath)
    if ($bytes.Length -gt 0) {
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $text = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
        }
        else {
            # Batch scripts run under CP866; redirected console output is decoded from that same OEM page.
            try { $sourceEncoding = [System.Text.Encoding]::GetEncoding(866) }
            catch { $sourceEncoding = [System.Text.Encoding]::Default }
            $text = $sourceEncoding.GetString($bytes)
        }
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            if (-not $text.EndsWith("`n")) { $text += "`r`n" }
            [System.IO.File]::AppendAllText($LogPath, $text, $utf8NoBom)
        }
    }
}
