<#
.SYNOPSIS
    Builds, signs and packs Turret Enhanced (2026 Version) for publishing.

.DESCRIPTION
    [GLT] Goltred update - not part of the original Turret Enhanced by Fat_Lurch.

    HEMTT 1.22 can only sign with its own .hemttprivatekey format (or a throwaway key per build),
    so this script signs with your existing .biprivatekey using DSSignFile from Arma 3 Tools:

      1. hemtt release --no-sign --no-archive   -> .hemttout\release
      2. copies it to the mod folder             -> <output folder>\@<prefix>   (default releases\@turret_enhanced_2026)
      3. DSSignFile <key> <pbo>                  -> .pbo.<authority>.bisign next to every PBO
      4. copies the matching .bikey              -> @<prefix>\keys\
      5. DSCheckSignatures                       -> verifies the PBOs against that .bikey
      6. zips @<prefix>                          -> releases\<prefix>-<version>.zip (+ -latest.zip)
         (<prefix> = prefix in .hemtt\project.toml, currently turret_enhanced_2026)

    The @<prefix> folder is the finished, signed mod: load it in the launcher, point Arma 3 Publisher
    at it, or copy it to a server. It is emptied and rebuilt on every run.

    Which key to use is resolved in this order:
      -KeyPath parameter  >  GLT_TE_SIGN_KEY environment variable  >  tools\release.local.json
    Run with -Configure once to pick the key (and DSSignFile if it is not auto-detected); the
    choice is saved in tools\release.local.json, which is git-ignored. The key itself is never
    copied anywhere.

.PARAMETER Configure
    Interactive setup: choose the key (a .biprivatekey file, or a folder to pick one from) and
    the DSSignFile.exe location. Saves tools\release.local.json and exits.

.PARAMETER ShowConfig
    Prints the settings that would be used and exits.

.PARAMETER KeyPath
    .biprivatekey file, or a folder containing one, to use for this run only.

.PARAMETER DSSignFile
    Full path to DSSignFile.exe for this run only (default: Arma 3 Tools, auto-detected).

.PARAMETER OutputDir
    Folder in which @<prefix> is created, for this run only (default: releases\ in the repo, or the
    folder chosen with -Configure).

.PARAMETER NoArchive
    Skip the zip; only the @<prefix> folder is produced.

.PARAMETER NoBin
    Passed to HEMTT: don't binarize (faster, for test packs).

.EXAMPLE
    tools\release.ps1 -Configure
.EXAMPLE
    tools\release.ps1
.EXAMPLE
    tools\release.ps1 -KeyPath "E:\Keys\Goltred" -NoArchive
#>
[CmdletBinding()]
param(
    [switch]$Configure,
    [switch]$ShowConfig,
    [string]$KeyPath,
    [string]$DSSignFile,
    [string]$OutputDir,
    [switch]$NoArchive,
    [switch]$NoBin
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ConfigFile = Join-Path $PSScriptRoot 'release.local.json'
$HemttOut   = Join-Path $RepoRoot '.hemttout\release'
$ReleaseDir = Join-Path $RepoRoot 'releases'
# Mod folder / zip names follow HEMTT: the project prefix in .hemtt\project.toml
$ZipBase = 'turret_enhanced_2026'
$projectToml = Join-Path $RepoRoot '.hemtt\project.toml'
if (Test-Path -LiteralPath $projectToml) {
    foreach ($line in Get-Content -LiteralPath $projectToml) {
        if ($line -match '^\s*prefix\s*=\s*"([^"]+)"') { $ZipBase = $Matches[1]; break }
    }
}
$ModFolder = "@$ZipBase"
$UpstreamKeyName = 'Fat_Lurch_TurretEnhanced'   # published in the upstream git history - never sign with it

function Write-Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Fail([string]$Text) { Write-Host ''; Write-Host "ERROR: $Text" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- settings

function Read-LocalConfig {
    if (Test-Path -LiteralPath $ConfigFile) {
        try { return Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json }
        catch { Fail "Could not read $ConfigFile ($($_.Exception.Message)). Run: tools\release.ps1 -Configure" }
    }
    return $null
}

function Find-DSSignFile {
    $candidates = @()
    foreach ($reg in @('HKCU:\Software\Bohemia Interactive\arma 3 tools', 'HKLM:\SOFTWARE\WOW6432Node\Bohemia Interactive\arma 3 tools')) {
        try {
            $p = (Get-ItemProperty -Path $reg -Name 'path' -ErrorAction Stop).path
            if ($p) { $candidates += (Join-Path $p 'DSSignFile\DSSignFile.exe') }
        } catch { }
    }
    try {
        $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -ErrorAction Stop).SteamPath
        if ($steam) { $candidates += (Join-Path $steam 'steamapps\common\Arma 3 Tools\DSSignFile\DSSignFile.exe') }
    } catch { }
    $candidates += 'C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\DSSignFile\DSSignFile.exe'
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path } }
    return $null
}

# A folder is accepted if it holds exactly one .biprivatekey (otherwise -Configure lets you pick)
function Resolve-KeyFile([string]$Path) {
    if (-not $Path) { return $null }
    $Path = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not (Test-Path -LiteralPath $Path)) { Fail "Key path not found: $Path" }
    $item = Get-Item -LiteralPath $Path
    if (-not $item.PSIsContainer) {
        if ($item.Extension -ne '.biprivatekey') { Fail "Not a .biprivatekey file: $Path" }
        return $item.FullName
    }
    $keys = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.biprivatekey' -File)
    if ($keys.Count -eq 0) { Fail "No .biprivatekey in folder: $($item.FullName)" }
    if ($keys.Count -gt 1) {
        Fail ("Several keys in $($item.FullName): " + (($keys | ForEach-Object Name) -join ', ') +
              ". Point at the file itself, or run tools\release.ps1 -Configure to pick one.")
    }
    return $keys[0].FullName
}

function Find-Hemtt {
    $local = Join-Path $RepoRoot 'hemtt.exe'
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command hemtt -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# ---------------------------------------------------------------- -Configure

if ($Configure) {
    $current = Read-LocalConfig
    Write-Host "Turret Enhanced (2026 Version) - release setup" -ForegroundColor Cyan
    Write-Host "Settings are saved to $ConfigFile (git-ignored). The key is only referenced, never copied."
    Write-Host ''

    $default = if ($current -and $current.keyPath) { $current.keyPath } else { '' }
    $answer = Read-Host "Private key: .biprivatekey file or the folder it is in$(if ($default) { " [$default]" })"
    if (-not $answer) { $answer = $default }
    $answer = $answer.Trim('"', ' ')
    if (-not $answer) { Fail 'No key given.' }
    if (-not (Test-Path -LiteralPath $answer)) { Fail "Not found: $answer" }

    $item = Get-Item -LiteralPath $answer
    if ($item.PSIsContainer) {
        $keys = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.biprivatekey' -File)
        if ($keys.Count -eq 0) { Fail "No .biprivatekey in $($item.FullName)" }
        if ($keys.Count -eq 1) { $keyFile = $keys[0].FullName }
        else {
            Write-Host 'Keys found:'
            for ($i = 0; $i -lt $keys.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $keys[$i].Name) }
            $n = Read-Host 'Which one? (number)'
            $idx = 0
            if (-not [int]::TryParse($n, [ref]$idx) -or $idx -lt 1 -or $idx -gt $keys.Count) { Fail 'Invalid choice.' }
            $keyFile = $keys[$idx - 1].FullName
        }
    } else {
        $keyFile = Resolve-KeyFile $item.FullName
    }

    $keyBase = [IO.Path]::GetFileNameWithoutExtension($keyFile)
    $bikey = Join-Path (Split-Path -Parent $keyFile) "$keyBase.bikey"
    if (-not (Test-Path -LiteralPath $bikey)) {
        Write-Host "WARNING: $keyBase.bikey was not found next to the private key. It is needed for the release." -ForegroundColor Yellow
    }

    $ds = if ($current -and $current.dsSignFile) { $current.dsSignFile } else { Find-DSSignFile }
    $dsAnswer = Read-Host "DSSignFile.exe (Arma 3 Tools)$(if ($ds) { " [$ds]" } else { ' - not auto-detected, enter the path' })"
    if ($dsAnswer) { $ds = $dsAnswer.Trim('"', ' ') }
    if (-not $ds -or -not (Test-Path -LiteralPath $ds)) { Fail "DSSignFile.exe not found: $ds  (install Arma 3 Tools from Steam)" }

    $out = if ($current -and $current.outputDir) { $current.outputDir } else { '' }
    $outAnswer = Read-Host "Folder to create $ModFolder in [$(if ($out) { $out } else { 'releases folder of the repo' })] (Enter = keep, '-' = repo releases folder)"
    if ($outAnswer -eq '-') { $out = '' }
    elseif ($outAnswer) { $out = $outAnswer.Trim('"', ' ') }
    if ($out -and -not (Test-Path -LiteralPath $out -PathType Container)) { Fail "Folder not found: $out" }

    [pscustomobject]@{ keyPath = $keyFile; dsSignFile = (Resolve-Path -LiteralPath $ds).Path; outputDir = $out } |
        ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8

    Write-Host ''
    Write-Host "Saved. Key: $keyFile" -ForegroundColor Green
    Write-Host 'Build a release with: tools\release.ps1   (or release.cmd)'
    exit 0
}

# ---------------------------------------------------------------- resolve settings

$config = Read-LocalConfig
$keySource = 'parameter -KeyPath'
if (-not $KeyPath) { $KeyPath = $env:GLT_TE_SIGN_KEY; $keySource = 'environment variable GLT_TE_SIGN_KEY' }
if (-not $KeyPath -and $config) { $KeyPath = $config.keyPath; $keySource = $ConfigFile }
if (-not $KeyPath) { Fail 'No signing key configured. Run: tools\release.ps1 -Configure   (or pass -KeyPath / set GLT_TE_SIGN_KEY)' }
$KeyFile = Resolve-KeyFile $KeyPath

if (-not $DSSignFile -and $config -and $config.dsSignFile) { $DSSignFile = $config.dsSignFile }
if (-not $DSSignFile) { $DSSignFile = Find-DSSignFile }
if (-not $DSSignFile -or -not (Test-Path -LiteralPath $DSSignFile)) {
    Fail 'DSSignFile.exe not found. Install Arma 3 Tools (Steam) or run: tools\release.ps1 -Configure'
}
$DSCheck = Join-Path (Split-Path -Parent $DSSignFile) 'DSCheckSignatures.exe'

if (-not $OutputDir -and $config -and $config.outputDir) { $OutputDir = $config.outputDir }
if (-not $OutputDir) { $OutputDir = $ReleaseDir }
$OutputDir = [Environment]::ExpandEnvironmentVariables($OutputDir)
$BuildDir = Join-Path $OutputDir $ModFolder      # the finished, signed mod folder

$Hemtt = Find-Hemtt
if (-not $Hemtt) { Fail 'HEMTT not found. Install it with: winget install hemtt' }

$KeyBase = [IO.Path]::GetFileNameWithoutExtension($KeyFile)

$versionFile = Join-Path $RepoRoot 'addons\main\script_version.hpp'
$v = @{}
foreach ($line in Get-Content -LiteralPath $versionFile) {
    if ($line -match '^\s*#define\s+(MAJOR|MINOR|PATCH)\s+(\d+)') { $v[$Matches[1]] = $Matches[2] }
}
$Version = "$($v.MAJOR).$($v.MINOR).$($v.PATCH)"

Write-Host 'Turret Enhanced (2026 Version) - release' -ForegroundColor Cyan
Write-Host "  Version    : $Version"
Write-Host "  Mod folder : $BuildDir"
Write-Host "  Key        : $KeyFile"
Write-Host "  Key from   : $keySource"
Write-Host "  DSSignFile : $DSSignFile"
Write-Host "  HEMTT      : $Hemtt"
if ($ShowConfig) { exit 0 }

# ---------------------------------------------------------------- safety checks

if ($KeyBase -ieq $UpstreamKeyName) {
    Fail ("$UpstreamKeyName.biprivatekey is public in the upstream git history, so anyone can sign PBOs with it. " +
          'Create your own key (Arma 3 Tools > DSUtils, or DSCreateKey.exe) and use that one.')
}
$repoFull = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\') + '\'
if ($KeyFile.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host 'WARNING: the private key is inside the repository folder. It is git-ignored, but keeping it outside the repo is safer.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 1. build

Write-Step 'Building with HEMTT (unsigned, no archive)'
$hemttArgs = @('release', '--no-sign', '--no-archive')
if ($NoBin) { $hemttArgs += '--no-bin' }
Push-Location $RepoRoot
try {
    & $Hemtt @hemttArgs
    if ($LASTEXITCODE -ne 0) { Fail "HEMTT failed (exit code $LASTEXITCODE)." }
} finally { Pop-Location }

if (-not (Test-Path -LiteralPath (Join-Path $HemttOut 'addons'))) { Fail "HEMTT output not found in $HemttOut" }

# ---------------------------------------------------------------- 2. mod folder

Write-Step "Creating $BuildDir"
if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
if (Test-Path -LiteralPath $BuildDir) {
    try { Remove-Item -LiteralPath $BuildDir -Recurse -Force }
    catch { Fail "Could not empty $BuildDir - is Arma 3 (or the launcher / Publisher) using it? ($($_.Exception.Message))" }
}
Copy-Item -LiteralPath $HemttOut -Destination $BuildDir -Recurse

$addonsDir = Join-Path $BuildDir 'addons'
$pbos = @(Get-ChildItem -LiteralPath $addonsDir -Filter '*.pbo' -File -ErrorAction SilentlyContinue)
if ($pbos.Count -eq 0) { Fail "No PBOs found in $addonsDir" }

# ---------------------------------------------------------------- 3. sign

Write-Step "Signing $($pbos.Count) PBO(s) with $KeyBase"
Get-ChildItem -LiteralPath $addonsDir -Filter '*.bisign' -File | Remove-Item -Force
$keysDir = Join-Path $BuildDir 'keys'
if (Test-Path -LiteralPath $keysDir) { Remove-Item -LiteralPath $keysDir -Recurse -Force }

$authority = $null
foreach ($pbo in $pbos) {
    & $DSSignFile $KeyFile $pbo.FullName
    if ($LASTEXITCODE -ne 0) { Fail "DSSignFile failed on $($pbo.Name) (exit code $LASTEXITCODE)." }
    $sig = @(Get-ChildItem -LiteralPath $addonsDir -Filter "$($pbo.Name).*.bisign" -File)
    if ($sig.Count -ne 1) { Fail "No signature was created for $($pbo.Name)." }
    # <addon>.pbo.<authority>.bisign - the authority is the key name stored inside the private key
    $authority = $sig[0].Name.Substring($pbo.Name.Length + 1, $sig[0].Name.Length - $pbo.Name.Length - 1 - '.bisign'.Length)
    Write-Host "  $($sig[0].Name)"
}

# ---------------------------------------------------------------- 4. public key

$keyDir = Split-Path -Parent $KeyFile
$bikey = $null
foreach ($name in @("$authority.bikey", "$KeyBase.bikey")) {
    $p = Join-Path $keyDir $name
    if (Test-Path -LiteralPath $p) { $bikey = $p; break }
}
if (-not $bikey) { Fail "Public key not found: expected $authority.bikey next to $KeyFile" }
New-Item -ItemType Directory -Path $keysDir | Out-Null
Copy-Item -LiteralPath $bikey -Destination (Join-Path $keysDir "$authority.bikey")
Write-Step "Added keys\$authority.bikey"

# ---------------------------------------------------------------- 5. verify

if (Test-Path -LiteralPath $DSCheck) {
    Write-Step 'Verifying signatures (DSCheckSignatures)'
    # Windows PowerShell turns redirected stderr into errors; don't let that abort the script
    $ErrorActionPreference = 'Continue'
    $out = & $DSCheck $addonsDir $keysDir 2>&1 | Out-String
    $checkExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Write-Host $out.Trim()
    if ($checkExit -ne 0 -or $out -match '(?i)wrong|invalid|missing|not signed|mismatch|cannot') {
        Write-Host 'WARNING: the signature check may have reported a problem - read the output above.' -ForegroundColor Yellow
        Write-Host '         (Is the .bikey the pair of this private key?)' -ForegroundColor Yellow
    }
} else {
    Write-Host "(DSCheckSignatures.exe not found next to DSSignFile - verification skipped)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 6. archive

if (-not $NoArchive) {
    Write-Step 'Creating archives'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path -LiteralPath $ReleaseDir)) { New-Item -ItemType Directory -Path $ReleaseDir | Out-Null }
    $zipVersion = Join-Path $ReleaseDir "$ZipBase-$Version.zip"
    $zipLatest  = Join-Path $ReleaseDir "$ZipBase-latest.zip"
    if (Test-Path -LiteralPath $zipVersion) { Remove-Item -LiteralPath $zipVersion -Force }

    $buildFull = (Resolve-Path -LiteralPath $BuildDir).Path.TrimEnd('\')
    $zip = [IO.Compression.ZipFile]::Open($zipVersion, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in Get-ChildItem -LiteralPath $buildFull -Recurse -File) {
            $rel = $f.FullName.Substring($buildFull.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $f.FullName, "$ModFolder/$rel", [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }
    Copy-Item -LiteralPath $zipVersion -Destination $zipLatest -Force
    Write-Host "  $zipVersion"
    Write-Host "  $zipLatest"
}

Write-Host ''
Write-Host "Done. Signed mod: $BuildDir" -ForegroundColor Green
Write-Host "Servers need keys\$authority.bikey. Keep the private key out of the repo and never share it."
