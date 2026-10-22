# ============================================================
#  ZapretEye (zeye) - engine auto-update (silent, no browser)
#  Downloads Flowseal/zapret-discord-youtube releases via the
#  GitHub API with curl.exe and unpacks them into zapret-engine\.
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File update.ps1 [-Force]
#
#  Exit codes: 0 = up to date / updated OK, 1 = error.
# ============================================================
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Invoke-Curl([string[]]$CurlArgs) {
    # Windows 10+ ships curl.exe; -sS = silent but still report errors
    & curl.exe @CurlArgs
    if ($LASTEXITCODE -ne 0) { throw "curl.exe failed (exit $LASTEXITCODE)" }
}

function Copy-TreeOver([string]$From, [string]$To) {
    # Recursively copy $From over $To, skipping protected files
    if (-not (Test-Path $To)) { New-Item -ItemType Directory -Path $To | Out-Null }
    Get-ChildItem -LiteralPath $From -Force | ForEach-Object {
        $dst = Join-Path $To $_.Name
        if ($_.PSIsContainer) {
            Copy-TreeOver $_.FullName $dst
        } else {
            if ($_.Name -in $script:ExcludeFiles) { return }
            if ($_.Name -like "$script:KeepBatPrefix*" -and (Test-Path $dst)) { return }
            Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
        }
    }
}

try {
    # ---- paths -------------------------------------------------
    $srcDir  = Split-Path -Parent $MyInvocation.MyCommand.Path   # <root>\src
    $root    = Split-Path -Parent $srcDir                        # <root>
    $engine  = Join-Path $root 'zapret-engine'
    $verFile = Join-Path $engine 'version.txt'

    $repoApi = 'https://api.github.com/repos/Flowseal/zapret-discord-youtube/releases/latest'

    # Never overwrite user data with release data:
    $script:ExcludeFiles  = @('list-general-user.txt', 'version.txt')
    $script:KeepBatPrefix = 'zeye-'   # custom strategies created by ZapretEye survive updates

    Write-Host '[zeye] Проверка обновлений движка Flowseal/zapret...'

    # ---- latest release info -----------------------------------
    $jsonRaw = (Invoke-Curl @('-sSL', '--max-time', '30', $repoApi)) -join "`n"
    $release = $jsonRaw | ConvertFrom-Json
    if (-not $release.tag_name) { throw 'GitHub API: не удалось получить информацию о релизе.' }

    $latest = $release.tag_name.TrimStart('v')
    $zipUrl = $null
    foreach ($a in $release.assets) {
        if ($a.name -match '\.zip$') { $zipUrl = $a.browser_download_url; break }
    }
    if (-not $zipUrl) { throw 'В релизе не найден .zip архив.' }

    # ---- compare with local version ----------------------------
    $local = ''
    if (Test-Path $verFile) { $local = ((Get-Content $verFile -First 1) + '').Trim() }

    if (($local -eq $latest) -and (-not $Force)) {
        Write-Host "[zeye] Уже актуально: $latest"
        exit 0
    }
    Write-Host ('[zeye] Локальная версия: ' + $(if ($local) { $local } else { 'нет' }) + ' -> новая: ' + $latest)

    # stop the engine while replacing binaries
    & taskkill.exe /F /IM winws.exe >$null 2>&1

    # ---- download silently to %TEMP% ---------------------------
    $zip     = Join-Path $env:TEMP ('zapret-' + $latest + '.zip')
    $extract = Join-Path $env:TEMP ('zapret-extract-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    Invoke-Curl @('-L', '-sS', '--fail', '--max-time', '600', '-o', $zip, $zipUrl) | Out-Null

    if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
    New-Item -ItemType Directory -Path $extract | Out-Null
    Expand-Archive -Path $zip -DestinationPath $extract -Force

    # The archive contains a single top folder like "zapret-discord-youtube-1.10.2"
    $inner = Get-ChildItem -Directory $extract | Select-Object -First 1
    if (-not $inner) { $inner = Get-Item $extract }

    # ---- copy over zapret-engine\ with exceptions --------------
    Copy-TreeOver $inner.FullName $engine

    # make sure the user list exists (add/remove writes into it)
    $userList = Join-Path $engine 'lists\list-general-user.txt'
    if (-not (Test-Path $userList)) {
        New-Item -ItemType Directory -Path (Split-Path $userList) -Force | Out-Null
        Set-Content -Path $userList -Value '' -Encoding UTF8 -NoNewline
    }

    # ---- record the installed version --------------------------
    Set-Content -Path $verFile -Value $latest -Encoding ASCII
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[zeye] Движок обновлён до $latest"
    exit 0
}
catch {
    Write-Host "[zeye] ОШИБКА обновления: $($_.Exception.Message)"
    exit 1
}
