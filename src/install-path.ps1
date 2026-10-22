# ============================================================
#  ZapretEye (zeye) - install engine path into C:\zeye-tools
#  Copies zeye.bat to C:\zeye-tools\, writes config-path.txt with
#  the real ZapretEye root and adds the folder to the user PATH.
#  Run once after cloning/updating the repo:
#      powershell -NoProfile -ExecutionPolicy Bypass -File src\install-path.ps1
# ============================================================
$ErrorActionPreference = 'Stop'

try {
    # Root of the repository (this script lives in <root>\src\)
    # Resolve the script dir robustly ($MyInvocation.MyCommand.Path is
    # empty when the file is dot-sourced).
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { $scriptPath = (Get-PSCallStack)[0].ScriptName }
    $srcDir   = Split-Path -Parent $scriptPath
    $zeyeRoot = Split-Path -Parent $srcDir

    $toolsDir = 'C:\zeye-tools'
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

    # Copy the CLI wrapper next to the path file
    Copy-Item -Path (Join-Path $srcDir 'zeye.bat') -Destination (Join-Path $toolsDir 'zeye.bat') -Force

    # Write the real repo root (NO BOM: cmd's `set /p` chokes on UTF-8 BOM).
    # zeye.bat reads this file to find zapret-engine/ wherever the repo lives.
    [System.IO.File]::WriteAllText((Join-Path $toolsDir 'config-path.txt'), $zeyeRoot, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[zeye] config-path.txt -> $zeyeRoot"

    # Add C:\zeye-tools to the USER PATH if missing
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';' | Where-Object { $_ -eq $toolsDir }) -notcontains $toolsDir) {
        $newPath = if ([string]::IsNullOrEmpty($userPath)) { $toolsDir } else { "$userPath;$toolsDir" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "[zeye] Добавлено в PATH: $toolsDir"
    } else {
        Write-Host "[zeye] Уже в PATH: $toolsDir"
    }
    # Make it visible for the current session too
    $env:Path = "$($env:Path);$toolsDir"

    Write-Host "[zeye] Готово. Команда доступна: zeye help"
    exit 0
}
catch {
    Write-Host "[zeye] ОШИБКА: $($_.Exception.Message)"
    exit 1
}
