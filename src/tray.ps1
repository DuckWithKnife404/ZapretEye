# ============================================================
#  ZapretEye (zeye) - tray icon (PowerShell + NotifyIcon)
#  Icon: assets\icon.ico. Context menu:
#    Открыть панель   -> menu.bat
#    Статус           -> running strategy / stopped (BalloonTip)
#    Перезапустить    -> silent restart of winws.exe
#    Выход            -> stop winws.exe, remove the icon
#  The CMD window is closed by menu.bat; winws.exe runs hidden.
#
#  Usage (launched detached by menu.bat / restart flow):
#    wscript //nologo tray-launch.vbs   OR
#    powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File tray.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- locate paths (this file lives in <root>\src\) -------------
# Resolve the script dir robustly: $MyInvocation.MyCommand.Path is empty
# when the file is dot-sourced, so fall back to Get-PSCallStack[0].
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = (Get-PSCallStack)[0].ScriptName }
$srcDir = Split-Path -Parent $scriptPath
$root   = Split-Path -Parent $srcDir
$engine      = Join-Path $root 'zapret-engine'
$iconPath    = Join-Path $root 'assets\icon.ico'
$configPath  = Join-Path $root 'config.json'

# ---- read config values ----------------------------------------
function Get-Cfg([string]$Key, [string]$Default) {
    try {
        if (Test-Path $configPath) {
            $cfg = (Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json)
            $v = $cfg.$Key
            if ($null -ne $v -and "$v" -ne '') { return "$v" }
        }
    } catch {}
    return $Default
}

function Get-StrategyName {
    $s = Get-Cfg 'default_strategy' ''
    if ($s -eq '') { return 'не выбрана' }
    return $s
}

function Test-EngineRunning {
    $null -ne (Get-Process -Name 'winws' -ErrorAction SilentlyContinue)
}

function Restart-Engine {
    & taskkill.exe /F /IM winws.exe >$null 2>&1
    Start-Sleep -Milliseconds 500
    $bat = (Get-Cfg 'last_profile' '') + '.bat'
    $strat = (Get-Cfg 'default_strategy' '').Replace(' ', '') + '.bat'
    $target = $null
    foreach ($cand in @((Join-Path $engine $bat), (Join-Path $engine $strat))) {
        if ($cand -and (Test-Path $cand)) { $target = $cand; break }
    }
    if (-not $target) { return $false }
    $sh = New-Object -ComObject WScript.Shell
    $sh.CurrentDirectory = $root
    $sh.Run("""cmd.exe"" /c """"""$target""""""", 0, $false)
    return $true
}

# ---- build the tray icon ---------------------------------------
$notify = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $iconPath) {
    # Load the .ico without locking the file (clone the handle)
    $iconTmp = New-Object System.Drawing.Icon($iconPath)
    $notify.Icon = [System.Drawing.Icon]::FromHandle($iconTmp.Handle)
} else {
    $notify.Icon = [System.Drawing.SystemIcons]::Application
}
$notify.Visible = $true
$notify.Text = 'ZapretEye (zeye)'

$menu = New-Object System.Windows.Forms.ContextMenuStrip

# Open panel
$miPanel = $menu.Items.Add('Открыть панель')
$miPanel.add_Click({
    $sh = New-Object -ComObject WScript.Shell
    $sh.Run("""cmd.exe"" /c """"""$(Join-Path $srcDir 'menu.bat')""""""", 1, $false)
}.GetNewClosure())

# Status
$miStatus = $menu.Items.Add('Статус')
$miStatus.add_Click({
    if (Test-EngineRunning) {
        $msg = "Запущена стратегия: $(Get-StrategyName)"
    } else {
        $msg = 'winws.exe не запущен'
    }
    $notify.ShowBalloonTip(3000, 'ZapretEye', $msg, [System.Windows.Forms.ToolTipIcon]::Info)
}.GetNewClosure())

$menu.Items.Add('-') | Out-Null

# Restart
$miRestart = $menu.Items.Add('Перезапустить')
$miRestart.add_Click({
    $ok = Restart-Engine
    $msg = if ($ok) { 'winws.exe перезапущен' } else { 'Стратегия не выбрана — запусти menu.bat' }
    $notify.ShowBalloonTip(3000, 'ZapretEye', $msg, [System.Windows.Forms.ToolTipIcon]::Info)
}.GetNewClosure())

$menu.Items.Add('-') | Out-Null

# Exit
$miExit = $menu.Items.Add('Выход')
$miExit.add_Click({
    & taskkill.exe /F /IM winws.exe >$null 2>&1
    $script:exiting = $true
    $notify.Visible = $false
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
}.GetNewClosure())

$notify.ContextMenuStrip = $menu

# Startup balloon
if (Test-EngineRunning) {
    $notify.ShowBalloonTip(2500, 'ZapretEye', "Запущена стратегия: $(Get-StrategyName)", [System.Windows.Forms.ToolTipIcon]::Info)
} else {
    $notify.ShowBalloonTip(2500, 'ZapretEye', 'winws.exe не запущен — открой панель.', [System.Windows.Forms.ToolTipIcon]::Warning)
}

# ---- message loop ----------------------------------------------
while (-not $script:exiting) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 200
}

$notify.Visible = $false
$notify.Dispose()
