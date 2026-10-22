@echo off
rem ============================================================
rem  ZapretEye (zeye) - CMD panel (глазик + меню)
rem  The eye/logo block is pure ASCII; the rest needs UTF-8 + chcp 65001.
rem  First run  -> download engine (update.ps1) + choose strategy
rem  After start-> tray icon, 10s wait, then the window closes
rem  and winws.exe keeps working hidden.
rem ============================================================
title ZapretEye (zeye)
rem NOTE: the .bat sources are saved as UTF-8. cmd.exe reads them in the
rem active console codepage, so we switch to 65001 *before* any Cyrillic
rem output happens (otherwise the menu shows cp866 mojibake). Works with
rem the default raster font and with Consolas/Lucida Console.
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0" && call "lib\paths.bat"

set "PS=powershell -NoProfile -ExecutionPolicy Bypass"

rem ---- ensure config.json exists -------------------------------
if not exist "%ZEYE_CONFIG%" %PS% -File lib\config.ps1 ensure

:header
cls
echo.
echo                          .-.
echo                        __( o )__
echo                          '-'
echo.
echo              Z A P R E T   E Y E
echo         Flowseal and DuckWithKnife404
echo.
echo  =========================================
rem read the saved strategy via config.ps1 (JSON-safe: findstr+delims== would
rem truncate values and cannot reassemble multi-line pretty-printed JSON)
set "DSTRAT="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File lib\config.ps1 get -Key default_strategy`) do set "DSTRAT=%%A"
set "RUNSTATE=остановлен"
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /i "winws.exe" >nul && set "RUNSTATE=активен"
if "!DSTRAT!"=="" (set "STATUS=Стратегия не выбрана") else (set "STATUS=Запущена стратегия: !DSTRAT! (авто)  [winws.exe: !RUNSTATE!]")
echo   !STATUS!
set "LVER="
if exist "%ZEYE_VERSIONFILE%" set /p "LVER="<"%ZEYE_VERSIONFILE%"
if "!LVER!"=="" (set "VER=Движок: не установлен") else (set "VER=Движок: !LVER!")
echo   !VER!
echo  =========================================
echo.

:menu
echo    1. Запустить стратегию
echo    2. Проверить стратегии
echo    3. Добавить домен
echo    4. Настройки
echo    5. Выход
echo.
choice /c 12345 /n /m "  Выбор: "
if errorlevel 5 ( endlocal & exit /b 0 )
if errorlevel 4 goto :settings
if errorlevel 3 goto :adddomain
if errorlevel 2 goto :check
if errorlevel 1 goto :run

:run
rem ---- engine missing? download it first -----------------------
if not exist "%ZEYE_WINWS%" (
    echo.
    echo  [zeye] Движок не найден. Скачиваю релиз Flowseal/zapret...
    %PS% -File update.ps1
    if errorlevel 1 (
        echo  [zeye] Не удалось скачать движок. Проверь интернет.
        pause & goto :header
    )
)

rem ---- first run: pick a strategy (it becomes the automatic one)
if not "!DSTRAT!"=="" goto :launch
goto :pickstrategy

rem ============================================================
rem  Strategy picker. NOTE: the old implementation used a cmd
rem  "for %%F in ("%ZEYE_ENGINE%\*.bat")" glob, which silently made
rem  zero iterations under console codepage 65001 on some Windows
rem  builds -> ".bat стратегии не найдены в движке" even though the
rem  files were on disk. The listing is now done by lib\profiles.ps1
rem  (Get-ChildItem - the same call check.ps1 uses successfully).
rem  Each line of its output is "<file>.bat|<arguments>", so PROFILE_N
rem  keeps holding the real file name (with .bat) exactly as before.
rem ============================================================
:pickstrategy
set "DSTRAT="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File lib\config.ps1 get -Key default_strategy`) do set "DSTRAT=%%A"
echo.
echo  Выбери стратегию по умолчанию (она станет автоматической):
echo.
set /a N=0
rem  pass the engine folder explicitly: if menu.bat is launched from a copy
rem  of the repo (or profiles.ps1 was moved), walking up from the script's
rem  own location would point at the wrong zapret-engine\ and the list
rem  would come back empty even though the .bat files exist.
for /f "usebackq tokens=1* delims=|" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass -File lib\profiles.ps1 -EngineDir "%ZEYE_ENGINE%"`) do (
    set /a N+=1
    set "PROFILE_!N!=%%F"
    set "ARGS_!N!=%%G"
    if not "%%G"=="" (echo    !N!. %%F  [%%G]) else (echo    !N!. %%F)
)
if %N%==0 ( echo  [zeye] .bat стратегии не найдены в движке. & pause & goto :header )
echo.
set "SEL="
set /p "SEL=  Номер: "
rem expand PROFILE_1..PROFILE_N now that SEL is known (delayed expansion)
set "PROFILE=!PROFILE_%SEL%!"
if not defined PROFILE ( echo  [zeye] Неверный номер. & pause & goto :header )
if not exist "%ZEYE_ENGINE%\%PROFILE%" ( echo  [zeye] Файл не найден. & pause & goto :header )

set "DSTRAT=%PROFILE:.bat=%"
%PS% -File lib\config.ps1 set -Key default_strategy -Value "%DSTRAT%"
%PS% -File lib\config.ps1 set -Key last_profile -Value "%PROFILE%"

rem ---- first run: register the "zeye" command in PATH ----------
echo  [zeye] Регистрирую команду zeye в PATH...
%PS% -File install-path.ps1

:launch
echo.
echo  [zeye] Запускаю стратегию %DSTRAT% скрыто...
call "lib\restart.bat" --no-wait
if errorlevel 1 ( pause & goto :header )

rem ---- tray icon (detached, survives this window) --------------
set "VBS=%TEMP%\zeye-tray-launch.vbs"
> "%VBS%" echo Set sh = CreateObject("WScript.Shell")
>>"%VBS%" echo sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%ZEYE_SRC%\tray.ps1""", 0, False
wscript.exe //nologo "%VBS%"
del "%VBS%" >nul 2>&1

echo  [zeye] Иконка в трее. Проверка через 10 секунд...
timeout /t 10 /nobreak >nul

rem ---- close the CMD window; winws.exe keeps running hidden ----
exit

:check
echo.
echo  [zeye] Проверка стратегий (HTTPS, таймаут из config)...
%PS% -File check.ps1
echo.
pause
goto :header

:adddomain
echo.
set "DOM="
set /p "DOM=  Домен (например, domain.com): "
if "!DOM!"=="" goto :header
call "%ZEYE_SRC%\zeye.bat" add "!DOM!"
echo.
pause
goto :header

:settings
echo.
echo  Текущие настройки:
set "CURL_="
set "CTO="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File lib\config.ps1 get -Key check_url`) do set "CURL_=%%A"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File lib\config.ps1 get -Key check_timeout`) do set "CTO=%%A"
echo    check_url        = %CURL_%
echo    check_timeout    = %CTO%
echo    default_strategy = !DSTRAT!
echo.
echo    s. Сменить стратегию по умолчанию
echo    u. Обновить движок сейчас
echo    i. Установить zeye в PATH (C:\zeye-tools)
echo    r. Остановить winws.exe
echo    0. Назад
echo.
choice /c SURI0 /n /m "  Выбор: "
if errorlevel 5 goto :header
if errorlevel 4 (
    taskkill /F /IM winws.exe >nul 2>&1
    echo  [zeye] winws.exe остановлен.
    pause & goto :header
)
if errorlevel 3 (
    %PS% -File install-path.ps1
    pause & goto :header
)
if errorlevel 2 (
    %PS% -File update.ps1
    pause & goto :header
)
if errorlevel 1 (
    rem re-read config.json inside :pickstrategy, so the header stays correct
    goto :pickstrategy
)

