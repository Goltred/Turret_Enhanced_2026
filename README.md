# Turret Enhanced (2026 Version)

Enhances vanilla and addon turrets in UAVs and helicopters (ISR overlay, markers, slewing, measuring, laser drawing). Requires CBA_A3.

## Building (HEMTT)

Install [HEMTT](https://hemtt.dev) once: `winget install hemtt`

From the repository root:

| Command | What it does |
|---|---|
| `hemtt check` | Lints configs and SQF without building |
| `hemtt dev` | Fast dev build to `.hemttout/dev` (load it with `-mod=` or file patching) |
| `hemtt launch` | Dev build + starts Arma 3 with CBA and this mod loaded |
| `hemtt build` | Full build to `.hemttout/build` |
| `release.cmd` | Signed release with **your** key - see [Publishing](#publishing) |

## Original vs. 2026 Version changes

This is a fork of Turret Enhanced by Fat_Lurch (Erik Kofahl). The 2026 Version builds on the original code in
place - same folders, same functions - and only uses the `GLT` prefix for what it adds:

- **New functions** are named `GLT_fnc_<name>` (registered in `class GLT` in `config.cpp`, files in `addons/main/functions/`).
- **New variables, CBA settings, dialogs and Controls actions** use `GLT_` names.
- **Original functions keep their names.** Where their behaviour changed (e.g. `fatlurch_fnc_measDistance`,
  `fatlurch_fnc_mapSlew`, `fatlurch_fnc_isViewISR`) the change is made in the original function and marked with a
  `// GLT:` comment. The old `fatlurch_fnc_addMarkerBlk/Blu/Red` were removed; marking goes through `GLT_fnc_addMarker`.
- **Keybinds** are native Options > Controls actions (`CfgUserActions` in `config.cpp`), bindable to HOTAS.

## Layout

- `addons/main/` - the addon, packed as `turret_enhanced_2026_main.pbo` with the PBO prefix `Turret_Enhanced_2026`
  (`$PBOPREFIX$`). `config.cpp` never spells the prefix out: every path is `GLT_QPATH(functions\x.sqf)`, built from
  `GLT_PREFIX` in `addons/main/script_name.hpp`. To rename the prefix, change `GLT_PREFIX`, `$PBOPREFIX$` and the
  4 image paths in `mod.cpp`. SQF code has no paths in it (functions go through CfgFunctions).
- `addons/main/script_version.hpp` - mod version used by HEMTT. Keep `version` in `CfgPatches` (config.cpp) in sync.
- `media/` - Workshop screenshots (not packed).

## Publishing

1. Install Arma 3 Tools from Steam. Keep your `.biprivatekey` and its `.bikey` together, **outside** the repo.
2. One-time setup - choose the key:
   ```
   release.cmd -Configure
   ```
   Give the key file, or the folder it is in (you pick if there are several). DSSignFile is found
   automatically when Arma 3 Tools is installed. The choice goes into `tools/release.local.json`, which is
   git-ignored; the key itself is never copied.
3. Build a release: `release.cmd` (or double-click it).

| Command | What it does |
|---|---|
| `release.cmd -ShowConfig` | Shows the version, key and tools that would be used |
| `release.cmd -NoArchive` | Only builds the signed `@turret_enhanced_2026` folder, no zip |
| `release.cmd -OutputDir "D:\Arma3Mods"` | Creates `@turret_enhanced_2026` in another folder for this run (set it permanently with `-Configure`) |
| `release.cmd -KeyPath "E:\Keys\MyKey.biprivatekey"` | Uses another key for this run only |

The key can also come from the `GLT_TE_SIGN_KEY` environment variable (order: `-KeyPath`, then
`GLT_TE_SIGN_KEY`, then `tools/release.local.json`).

Output: `releases/@turret_enhanced_2026/` - the finished, signed mod (`addons/*.pbo` + `.bisign`,
`keys/<authority>.bikey`, `mod.cpp`...), ready to load in the launcher, upload with Arma 3 Publisher or copy to
a server. It is emptied and rebuilt on every run (close Arma / the launcher first if it is loaded). Plus
`releases/turret_enhanced_2026-<version>.zip` / `-latest.zip` containing that folder. Servers need the
`.bikey` from `keys/`. The version comes from `addons/main/script_version.hpp`.
