@echo off
rem ============================================================
rem  ZapretEye (zeye) - shared paths
rem  Include with:  cd /d "%~dp0" ^&^& call paths.bat
rem  (run from the folder containing this file; %CD% is then lib\,
rem   so ZEYE_ROOT resolves to the repository root two levels up)
rem ============================================================

for %%I in ("%CD%\..\..") do set "ZEYE_ROOT=%%~fI"

set "ZEYE_SRC=%ZEYE_ROOT%\src"
set "ZEYE_ENGINE=%ZEYE_ROOT%\zapret-engine"
set "ZEYE_CONFIG=%ZEYE_ROOT%\config.json"
set "ZEYE_ICON=%ZEYE_ROOT%\assets\icon.ico"
set "ZEYE_WINWS=%ZEYE_ENGINE%\winws.exe"
set "ZEYE_USERLIST=%ZEYE_ENGINE%\lists\list-general-user.txt"
set "ZEYE_VERSIONFILE=%ZEYE_ENGINE%\version.txt"

rem Tools directory that must be on PATH for the "zeye" command
set "ZEYE_TOOLS_DIR=C:\zeye-tools"
set "ZEYE_PATHFILE=C:\zeye-tools\config-path.txt"

exit /b 0
