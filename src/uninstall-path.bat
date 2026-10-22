@echo off
rem ============================================================
rem  ZapretEye (zeye) - rollback of install-path.ps1
rem  Removes C:\zeye-tools from the user PATH and deletes it.
rem ============================================================
chcp 65001 >nul
setlocal EnableExtensions

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$t='C:\zeye-tools';" ^
 "$p=[Environment]::GetEnvironmentVariable('Path','User');" ^
 "$n=($p -split ';' | Where-Object { $_ -and ($_ -ne $t) }) -join ';';" ^
 "[Environment]::SetEnvironmentVariable('Path',$n,'User');" ^
 "if (Test-Path $t) { Remove-Item -Recurse -Force $t };" ^
 "Write-Host '[zeye] C:\zeye-tools удалён из PATH и очищен.'"

echo [zeye] Готово. Перезапусти CMD, чтобы изменения PATH вступили в силу.
exit /b 0
