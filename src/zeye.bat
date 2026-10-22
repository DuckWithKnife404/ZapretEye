@echo off
rem ============================================================
rem  ZapretEye (zeye) - CLI wrapper
rem  Commands: add | remove | list | help | start | stop | restart
rem  Lives in C:\zeye-tools\ after install-path.ps1 copies it there.
rem  The real engine path is read from C:\zeye-tools\config-path.txt,
rem  written by install-path.ps1 (this avoids broken %~dp0.. copies).
rem ============================================================
rem NOTE: keep the file UTF-8 and switch the console to 65001 before any
rem Cyrillic output, otherwise cmd.exe decodes the source as cp866 and the
rem user sees mojibake.
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

rem ---- locate the ZapretEye root ----
set "ZEYE_ROOT="
if exist "%~dp0config-path.txt" (
    set /p "ZEYE_ROOT="<"%~dp0config-path.txt"
)
if not defined ZEYE_ROOT (
    for %%I in ("%~dp0..") do set "ZEYE_ROOT=%%~fI"
)

set "ENGINE=%ZEYE_ROOT%\zapret-engine"
set "USERLIST=%ENGINE%\lists\list-general-user.txt"
set "LIB=%ZEYE_ROOT%\src\lib"

set "CMD=%~1"
if "%CMD%"=="" goto :usage

if /i "%CMD%"=="add"     goto :add
if /i "%CMD%"=="remove"  goto :remove
if /i "%CMD%"=="del"     goto :remove
if /i "%CMD%"=="list"    goto :list
if /i "%CMD%"=="start"   goto :start
if /i "%CMD%"=="stop"    goto :stop
if /i "%CMD%"=="restart" goto :restart
if /i "%CMD%"=="help"    goto :usage
if /i "%CMD%"=="/?"      goto :usage

echo [zeye] Неизвестная команда: %CMD%
goto :usage

:add
set "DOMAIN=%~2"
if "%DOMAIN%"=="" (
    echo [zeye] Использование: zeye add "domain.com"
    exit /b 2
)
call :sanitize "%DOMAIN%" || exit /b 2
if not exist "%ENGINE%" (
    echo [zeye] Движок не установлен. Сначала обнови движок через menu.bat
    exit /b 1
)
if not exist "%USERLIST%" (
    if not exist "%ENGINE%\lists" mkdir "%ENGINE%\lists"
    type nul > "%USERLIST%"
)
findstr /x /i /c:"%DOMAIN%" "%USERLIST%" >nul 2>&1
if %errorlevel%==0 (
    echo [zeye] Домен уже в списке: %DOMAIN%
    exit /b 0
)
>> "%USERLIST%" echo %DOMAIN%
echo [zeye] Добавлен: %DOMAIN%
goto :restart_quiet

:remove
set "DOMAIN=%~2"
if "%DOMAIN%"=="" (
    echo [zeye] Использование: zeye remove "domain.com"
    exit /b 2
)
if not exist "%USERLIST%" (
    echo [zeye] Файл списка не найден: "%USERLIST%"
    exit /b 1
)
findstr /x /i /v /c:"%DOMAIN%" "%USERLIST%" > "%USERLIST%.tmp" 2>nul
move /y "%USERLIST%.tmp" "%USERLIST%" >nul 2>&1
echo [zeye] Удалён из списка: %DOMAIN%
goto :restart_quiet

:list
if not exist "%USERLIST%" (
    echo [zeye] Пользовательских доменов пока нет.
    exit /b 0
)
echo [zeye] Пользовательские домены ^(list-general-user.txt^):
echo ------------------------------------------------------------
type "%USERLIST%"
echo ------------------------------------------------------------
exit /b 0

:start
call "%LIB%\restart.bat"
exit /b %errorlevel%

:stop
taskkill /F /IM winws.exe >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" (echo [zeye] winws.exe остановлен.) else (echo [zeye] winws.exe не запущен.)
exit /b 0

:restart
call "%LIB%\restart.bat"
exit /b %errorlevel%

:restart_quiet
rem Silent restart so the new domain applies immediately.
if not exist "%LIB%\restart.bat" (
    echo [zeye] ВНИМАНИЕ: src\lib\restart.bat не найден, перезапуск пропущен.
    exit /b 0
)
call "%LIB%\restart.bat" --no-wait >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" (
    echo [zeye] winws.exe перезапущен - изменения применены.
) else (
    echo [zeye] Не удалось перезапустить winws.exe. Выбери стратегию в menu.bat.
)
exit /b 0

:sanitize
rem Reject anything that is not a plain hostname/domain.
set "D=%~1"
if "%D%"=="" (
    echo [zeye] Пустой домен. Пример: zeye add "domain.com"
    exit /b 2
)
set "CLEAN=%D%"
rem strip every allowed char; if anything is left -> illegal symbol present.
rem The list must be case-sensitive: %VAR:old=new% substitution is CI in cmd,
rem so both cases are listed explicitly (a-z and A-Z).
for %%S in (a b c d e f g h i j k l m n o p q r s t u v w x y z ^
            A B C D E F G H I J K L M N O P Q R S T U V W X Y Z ^
            0 1 2 3 4 5 6 7 8 9 . _ -) do call set "CLEAN=%%CLEAN:%%S=%%"
if not "%CLEAN%"=="" (
    echo [zeye] Недопустимый символ в домене: %D%
    exit /b 2
)
if /i "%D%"=="con" (
    echo [zeye] Зарезервированное имя Windows нельзя использовать как домен: %D%
    exit /b 2
)
if "%D:~0,1%"=="." (
    echo [zeye] Домен не может начинаться с точки: %D%
    exit /b 2
)
rem trailing dot is allowed on purpose: "example.com." is a valid FQDN (root hint)
exit /b 0

:usage
echo.
echo  ZapretEye (zeye) - обёртка над Flowseal/zapret
echo.
echo  Использование:
echo    zeye add "domain.com"      добавить домен и применить сразу
echo    zeye remove "domain.com"   убрать домен и применить сразу
echo    zeye list                  показать пользовательские домены
echo    zeye start                 запустить/перезапустить winws.exe скрытно
echo    zeye stop                  остановить winws.exe
echo    zeye restart               тихий перезапуск winws.exe
echo    zeye help                  эта справка
echo.
exit /b 0
