@echo off
rem [GLT] Build, sign and pack Turret Enhanced (2026 Version).
rem   release.cmd              build a signed release
rem   release.cmd -Configure   choose the signing key (saved in tools\release.local.json)
rem   release.cmd -ShowConfig  show which key / tools would be used
rem   release.cmd -NoArchive   only build the signed @turret_enhanced_2026 folder, no zip
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\release.ps1" %*
set EXITCODE=%ERRORLEVEL%
if "%~1"=="" pause
exit /b %EXITCODE%
