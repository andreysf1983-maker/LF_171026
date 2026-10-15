param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [string]$SavedPathFile = ""
)

$ErrorActionPreference = "SilentlyContinue"

$exeNames = @(
    "Wow.exe",
    "Wow-64.exe",
    "Hellgarve.Legion-64.exe",
    "WowB.exe",
    "WowT.exe"
)

function Test-ClientExe([string]$path) {
    if (-not $path) { return $false }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $name = [IO.Path]::GetFileName($path)
    return $exeNames -contains $name
}

function Search-Dir([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }

    foreach ($name in $exeNames) {
        $direct = Join-Path $dir $name
        if (Test-Path -LiteralPath $direct -PathType Leaf) { return $direct }
    }

    $hit = Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $exeNames -contains $_.Name } |
        Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

if ($SavedPathFile -and (Test-Path -LiteralPath $SavedPathFile -PathType Leaf)) {
    $saved = (Get-Content -LiteralPath $SavedPathFile -TotalCount 1)
    if ($saved) {
        $saved = $saved.Trim().Trim('"')
        if (Test-ClientExe $saved) {
            Write-Output $saved
            exit 0
        }
        if (Test-Path -LiteralPath $saved -PathType Container) {
            $fromSaved = Search-Dir $saved
            if ($fromSaved) {
                Write-Output $fromSaved
                exit 0
            }
        }
    }
}

if (Test-ClientExe $Root) {
    Write-Output $Root
    exit 0
}

$searchRoots = @(
    (Join-Path $Root "client_"),
    (Join-Path $Root "WoW_Client"),
    $Root
)
foreach ($dir in $searchRoots) {
    $found = Search-Dir $dir
    if ($found) {
        Write-Output $found
        exit 0
    }
}

exit 1
