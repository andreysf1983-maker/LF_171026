param(
    [Parameter(Mandatory = $true)]
    [string]$ClientDir
)

$ErrorActionPreference = "Continue"
$names = @("Wow.exe", "Wow-64.exe", "Hellgarve.Legion-64.exe", "WowB.exe", "WowT.exe")
$pattern = [Text.Encoding]::ASCII.GetBytes("legion.fstorm.eu")
# Must be same byte length as legion.fstorm.eu (16 chars): IP + padding spaces
$replace = [Text.Encoding]::ASCII.GetBytes("127.0.0.1       ")
if ($replace.Length -ne $pattern.Length) {
    Write-Host "  [!] Internal patcher length mismatch ($($replace.Length) vs $($pattern.Length))"
}

$patchedAny = $false
foreach ($name in $names) {
    $path = Join-Path $ClientDir $name
    if (-not (Test-Path -LiteralPath $path)) { continue }

    $bytes = [IO.File]::ReadAllBytes($path)
    $hit = $false
    $limit = $bytes.Length - $pattern.Length
    for ($i = 0; $i -le $limit; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $pattern.Length; $j++) {
            if ($bytes[$i + $j] -ne $pattern[$j]) { $ok = $false; break }
        }
        if ($ok) {
            for ($j = 0; $j -lt $replace.Length; $j++) { $bytes[$i + $j] = $replace[$j] }
            $hit = $true
        }
    }

    if ($hit) {
        [IO.File]::WriteAllBytes($path, $bytes)
        Write-Host "  [OK] Patched $name to 127.0.0.1"
        $patchedAny = $true
    }
}

if (-not $patchedAny) {
    Write-Host "  [!] legion.fstorm.eu not found in client exes (already patched or a different build)"
}

# Hellgarve stores the login portal in WTF, not only in the exe.
$wtfDir = Join-Path $ClientDir "WTF"
if (Test-Path -LiteralPath $wtfDir) {
    $wtfFiles = @(Get-ChildItem -LiteralPath $wtfDir -Filter "*.wtf" -File -ErrorAction SilentlyContinue)
    foreach ($wtf in $wtfFiles) {
        $text = Get-Content -LiteralPath $wtf.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        $new = $text
        $new = $new -replace 'SET portal "[^"]+"', 'SET portal "127.0.0.1:1119"'
        $new = $new -replace 'legion\.fstorm\.eu', '127.0.0.1'
        if ($new -ne $text) {
            Set-Content -LiteralPath $wtf.FullName -Value $new -NoNewline
            Write-Host ("  [OK] Portal in {0} -> 127.0.0.1:1119" -f $wtf.Name)
        }
    }
}

$configWtf = Join-Path $wtfDir "Config.wtf"
if (-not (Test-Path -LiteralPath $configWtf)) {
    New-Item -ItemType Directory -Force -Path $wtfDir | Out-Null
    Set-Content -LiteralPath $configWtf -Value "SET portal `"127.0.0.1:1119`"`r`nSET textLocale `"enUS`"`r`nSET audioLocale `"enUS`"`r`n"
    Write-Host "  [OK] Wrote WTF\Config.wtf portal 127.0.0.1:1119"
}
