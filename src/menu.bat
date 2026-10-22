@echo off
rem ============================================================
rem  ZapretEye (zeye) - CMD panel (глазик + меню)
rem  Header is pure ASCII so it renders in any console codepage.
rem  First run  -> download engine (update.ps1) + choose strategy
rem  After start-> tray icon, 10s wait, then the window closes
rem  and winws.exe keeps working hidden.
rem ============================================================
title ZapretEye (zeye)
rem NOTE: keep the console codepage default (866) so chcp 65001
rem does not break Cyrillic output of child scripts (zeye.bat etc.).
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
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /i "winws.exe" >nul && (set "RUNSTATE=активен") || (set "RUNSTATE=остановлен")
if "%DSTRAT%"=="" (set "STATUS=Стратегия не выбрана") else (set "STATUS=Запущена стратегия: %DSTRAT% ^(авто^)  [winws.exe: %RUNSTATE%]")
echo   %STATUS%
set "LVER="
if exist "%ZEYE_VERSIONFILE%" set /p "LVER="<"%ZEYE_VERSIONFILE%"
if "%LVER%"=="" (set "VER=Движок: не установлен") else (set "VER=Движок: %LVER%")
echo   %VER%
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
if errorlevel 5 exit /b 0
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
if not "%DSTRAT%"=="" goto :launch
goto :pickstrategy

:pickstrategy
echo.
echo  Выбери стратегию по умолчанию (она станет автоматической):
echo.
set /a N=0
for %%F in ("%ZEYE_ENGINE%\*.bat") do (
    rem skip helper scripts that are not strategies (same rule as check.ps1)
    if /i not "%%~nxF"=="service.bat" if /i not "%%~nxF"=="uninstall_service.bat" if /i not "%%~nxF"=="update.bat" if /i not "%%~nxF"=="check.bat" (
        set /a N+=1
        set "P!N!=%%~nxF"
        echo    !N!. %%~nxF
    )
)
if %N%==0 ( echo  [zeye] .bat стратегии не найдены в движке. & pause & goto :header )
echo.
set /p "SEL=  Номер: "
set "PROFILE="
rem expand P1..PN after SEL is known
call set "PROFILE=%%P%SEL%%%"
if not defined PROFILE ( echo  [zeye] Неверный номер. & pause & goto :header )
if not exist "%ZEYE_ENGINE%\%PROFILE%" ( echo  [zeye] Файл не найден. & pause & goto :header )

set "DSTRAT=%PROFILE:.bat=%"
%PS% -File lib\config.ps1 set -Key default_strategy -Value "%DSTRAT%"

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
set /p "DOM=  Домен (например, domain.com): "
if "%DOM%"=="" goto :header
call "%ZEYE_SRC%\zeye.bat" add "%DOM%"
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
echo    default_strategy = %DSTRAT%
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
    set "DSTRAT="
    goto :pickstrategy
)

