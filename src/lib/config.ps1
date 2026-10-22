# ============================================================
#  ZapretEye (zeye) - config.json helpers
#  Called from batch as: powershell -File config.ps1 <get|set> ...
#  config.json is edited programmatically only (see design doc).
# ============================================================
param(
    [Parameter(Mandatory = $true)][string]$Action,
    [string]$Key = '',
    [string]$Value = '',
    [string]$Path = ''
)

$ErrorActionPreference = 'Stop'

try {
    if ([string]::IsNullOrEmpty($Path)) {
        # default: repo root config.json (this file lives in <root>\src\)
        $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
        $Path = Join-Path $root 'config.json'
    }

    function Read-Config([string]$p) {
        if (-not (Test-Path $p)) { return $null }
        $raw = Get-Content -Raw -Encoding UTF8 $p
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    }

    switch ($Action.ToLower()) {

        'get' {
            $cfg = Read-Config $Path
            if ($null -eq $cfg) { exit 0 }
            $prop = $cfg.PSObject.Properties[$Key]
            if ($null -ne $prop -and "$($prop.Value)" -ne '') { Write-Output ([string]$prop.Value) }
            exit 0
        }

        'set' {
            $cfg = Read-Config $Path
            if ($null -eq $cfg) { $cfg = [pscustomobject]@{} }
            if ($null -eq $cfg.PSObject.Properties[$Key]) {
                $cfg | Add-Member -NotePropertyName $Key -NotePropertyValue $Value
            } else {
                $cfg.$Key = $Value
            }
            $json = $cfg | ConvertTo-Json -Depth 10
            # No-BOM UTF-8 so cmd findstr / type keep working on the file
            [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
            exit 0
        }

        'ensure' {
            # create config.json with defaults if missing
            if (-not (Test-Path $Path)) {
                $defaults = [ordered]@{
                    default_strategy = ''
                    check_url        = 'https://www.youtube.com/'
                    check_timeout    = 5
                    tray_icon        = 'assets\icon.ico'
                    engine_dir       = 'zapret-engine'
                }
                $json = [pscustomobject]$defaults | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
                Write-Output "[zeye] Создан $Path"
            }
            exit 0
        }

        default {
            Write-Error "Unknown action: $Action (expected get|set|ensure)"
            exit 2
        }
    }
}
catch {
    Write-Error $_
    exit 1
}
