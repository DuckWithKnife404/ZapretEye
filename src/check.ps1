# ============================================================
#  ZapretEye (zeye) - strategy checker (HTTPS only, TCP 443)
#  For every strategy .bat in zapret-engine\:
#      start it hidden -> curl the check URL with a timeout
#      -> stop winws.exe -> verdict.
#  QUIC/UDP is NOT checked by design.
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File check.ps1
#              [-Engine <path>] [-Url <url>] [-Timeout <sec>]
# ============================================================
param(
    [string]$Engine  = '',
    [string]$Url     = 'https://www.youtube.com/',
    [int]   $Timeout = 5
)

$ErrorActionPreference = 'Continue'

try {
    if ([string]::IsNullOrEmpty($Engine)) {
        # Resolve the script dir robustly ($MyInvocation.MyCommand.Path is
        # empty when the file is dot-sourced).
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) { $scriptPath = (Get-PSCallStack)[0].ScriptName }
        $srcDir = Split-Path -Parent $scriptPath
        $root   = Split-Path -Parent $srcDir
        $Engine = Join-Path $root 'zapret-engine'
    }
    if (-not (Test-Path $Engine)) {
        Write-Host "[zeye] Движок не найден: $Engine — сначала обнови его."
        exit 1
    }

    # Strategy .bat files shipped by Flowseal + custom zeye-*.bat
    $files = Get-ChildItem -LiteralPath $Engine -Filter '*.bat' -File | Sort-Object Name

    # Exclude helper scripts that are not strategies
    $files = $files | Where-Object {
        $_.Name -notmatch '(?i)^(service|install|uninstall|update|check|tray)'
    }

    if (-not $files) {
        Write-Host '[zeye] Файлы стратегий (.bat) не найдены в движке.'
        exit 1
    }

    Write-Host ''
    Write-Host ('{0,-42} {1,-8} {2,-10} {3}' -f 'Стратегия', 'Код', 'Время,с', 'Вердикт')
    Write-Host ('-' * 78)

    foreach ($f in $files) {
        # stop leftovers from previous iteration (taskkill's "process not
        # found" stderr would abort the script under ErrorActionPreference=Stop)
        Get-Process -Name 'winws' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400

        # launch the strategy hidden
        $sh = New-Object -ComObject WScript.Shell
        $sh.CurrentDirectory = $Engine
        try { $sh.Run("""cmd.exe"" /c """"""$($f.FullName)""""""", 0, $false) } catch {}

        # give winws.exe a moment to come up
        Start-Sleep -Seconds 2

        # single HTTPS probe through the zapret tunnel
        # --noproxy '*': never reuse system proxy env vars for the probe
        $res = & curl.exe --noproxy '*' -o NUL -s -w '%{http_code} %{time_total}' --max-time $Timeout $Url 2>$null
        $parts = ($res + '') -split ' '
        $code  = $parts[0]
        $timeS = $parts[1]
        if (-not $timeS) { $timeS = '0' }
        $timeD = 0.0
        [void][double]::TryParse(($timeS -replace ',', '.'), [ref]$timeD)

        $ok = ($code -eq '200') -and ($timeD -lt $Timeout)
        $verdict = if ($ok) { 'РАБОТАЕТ' } else { 'НЕТ' }

        Write-Host ('{0,-42} {1,-8} {2,-10} {3}' -f $f.BaseName, $code, ('{0:N2}' -f $timeD), $verdict)

        # stop before testing the next strategy
        Get-Process -Name 'winws' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400
    }

    Write-Host ('-' * 78)
    Write-Host '[zeye] Проверено только HTTPS (TCP 443). QUIC/UDP не проверяется.'
    exit 0
}
catch {
    Write-Host "[zeye] ОШИБКА: $($_.Exception.Message)"
    exit 1
}
