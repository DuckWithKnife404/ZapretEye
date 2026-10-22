@echo off
rem ============================================================
rem  ZapretEye (zeye) - silent restart of winws.exe
rem  Reads the saved strategy from config.json and relaunches
rem  the engine hidden (no console window).
rem  Usage: call "%~dp0restart.bat" [--no-wait]
rem ============================================================
setlocal EnableExtensions

rem paths.bat resolves ZEYE_ROOT from the current directory, so run it in lib\
cd /d "%~dp0" && call paths.bat

rem ---- read default_strategy + last profile from config.json ----
set "STRAT="
set "PROFILE="
if exist "%ZEYE_CONFIG%" (
    for /f "usebackq tokens=2 delims==" %%A in (`findstr /c:"\"default_strategy\"" "%ZEYE_CONFIG%"`) do set "STRAT=%%~A"
    for /f "usebackq tokens=2 delims==" %%A in (`findstr /c:"\"last_profile\"" "%ZEYE_CONFIG%"`) do set "PROFILE=%%~A"
)
if not "%STRAT%"=="" set "STRAT=%STRAT: =%"

rem ---- stop current instance ----
taskkill /F /IM winws.exe >nul 2>&1

if not exist "%ZEYE_WINWS%" (
    echo [zeye] Движок не найден: "%ZEYE_WINWS%"
    echo [zeye] Сначала выполни обновление движка.
    exit /b 1
)

rem ---- resolve strategy .bat inside the engine folder ----
set "BATFILE="
if not "%PROFILE%"=="" if exist "%ZEYE_ENGINE%\%PROFILE%.bat" set "BATFILE=%ZEYE_ENGINE%\%PROFILE%.bat"
if not defined BATFILE if not "%STRAT%"=="" if exist "%ZEYE_ENGINE%\%STRAT%.bat" set "BATFILE=%ZEYE_ENGINE%\%STRAT%.bat"

if not defined BATFILE (
    echo [zeye] Стратегия не выбрана или её файл не найден в движке.
    echo [zeye] Открой menu.bat и выбери стратегию.
    exit /b 1
)

rem ---- launch hidden via a temporary VBScript wrapper ----
set "VBS=%TEMP%\zeye-run-winws.vbs"
> "%VBS%" echo Set sh = CreateObject("WScript.Shell")
>>"%VBS%" echo sh.CurrentDirectory = "%ZEYE_ROOT%"
>>"%VBS%" echo sh.Run """%BATFILE%""", 0, False

wscript.exe //nologo "%VBS%"
del "%VBS%" >nul 2>&1

if /i not "%~1"=="--no-wait" (
    rem wait a moment so winws.exe can load its lists before returning
    ping -n 6 127.0.0.1 >nul
)

exit /b 0
