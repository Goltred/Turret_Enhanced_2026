<#
    One-time migration of the Turret_Enhanced repo to the HEMTT layout.

    Run from anywhere inside the repo:
        powershell -ExecutionPolicy Bypass -File tools\migrate-to-hemtt.ps1

    What it does (moves use `git mv` so file history is kept):
        data\, images\                       -> addons\main\
        dialogs\changeAltitude\, changeLoiter\ -> tools\gui-editor\   (GUI editor projects)
        notes / editor project files         -> docs\notes\
        removes the old root-level addon files (config.cpp, XEH_*.sqf, functions\, dialogs\)
        whose updated copies are already in addons\main\
        removes files the addon no longer uses: the temporary addons\main\glt\ folder, the 3D laser
        beam, the Marker Setup window and the old createMarkerBlack/Blue/Red

    Safe to run twice: anything already moved is skipped.
#>

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path '.git'))                    { throw 'Run this from the Turret_Enhanced git repository.' }
if (-not (Test-Path 'addons/main/config.cpp'))  { throw 'addons/main/config.cpp is missing - the HEMTT files must be added first.' }

function Test-Tracked([string]$Path) {
    $out = git ls-files -- $Path
    return [bool]$out
}

function Move-Path([string]$From, [string]$To) {
    if (-not (Test-Path -LiteralPath $From)) { Write-Host "  skip (not found): $From"; return }
    if (Test-Path -LiteralPath $To)          { Write-Host "  skip (already exists): $To"; return }
    $parent = Split-Path -Parent $To
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
    if (Test-Tracked $From) { git mv -- $From $To } else { Move-Item -LiteralPath $From -Destination $To }
    Write-Host "  moved:   $From -> $To"
}

function Remove-OldPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (Test-Tracked $Path) { git rm -r -f -q -- $Path | Out-Null }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    Write-Host "  removed: $Path"
}

Write-Host 'Moving textures into the addon...'
Move-Path 'data'   'addons/main/data'
Move-Path 'images' 'addons/main/images'

Write-Host 'Moving GUI editor projects...'
Move-Path 'dialogs/changeAltitude' 'tools/gui-editor/changeAltitude'
Move-Path 'dialogs/changeLoiter'   'tools/gui-editor/changeLoiter'

Write-Host 'Moving notes...'
foreach ($f in @('_Notes.txt', '_LaserNotes.txt', '_Turret_Slew_Notes.txt', 'Text input notes.txt',
                 'textures.lst', 'Turret_Enhanced.tproj', 'mission.sqm', 'Lent Code')) {
    Move-Path $f (Join-Path 'docs/notes' $f)
}

Write-Host 'Removing old root-level addon files (updated copies are in addons/main)...'
foreach ($p in @('config.cpp', 'XEH_preInit.sqf', 'XEH_postInit.sqf', 'functions', 'dialogs')) {
    Remove-OldPath $p
}

Write-Host 'Removing files no longer used by the addon...'
foreach ($p in @('addons/main/glt',                                   # temporary folder, merged back into functions/ and dialogs/
                 'addons/main/functions/drawLasers3D.sqf',            # 3D laser beam (removed)
                 'addons/main/functions/markerSetup.sqf',             # Marker Setup window (removed)
                 'addons/main/dialogs/markerSetup.h',
                 'addons/main/functions/createMarkerBlack.sqf',       # replaced by GLT_fnc_addMarker (marker slots 1-4)
                 'addons/main/functions/createMarkerBlue.sqf',
                 'addons/main/functions/createMarkerRed.sqf')) {
    Remove-OldPath $p
}

Write-Host ''
Write-Host 'Done. Next:'
Write-Host '  git add -A'
Write-Host '  hemtt check'
Write-Host '  git status   (renames show up as R)'
