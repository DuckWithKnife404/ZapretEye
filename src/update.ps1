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

function Stop-EngineProcesses {
    # Safely stop winws.exe if it is running. Uses Get-Process/Stop-Process
    # instead of taskkill.exe: taskkill writes "ERROR: The process ... not
    # found." to stderr when the process isn't running, and that stderr output
    # becomes a terminating error under $ErrorActionPreference = 'Stop'.
    Get-Process -Name 'winws' -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
    }
}

function Copy-TreeOver([string]$From, [string]$To) {
    # Recursively copy $From over $To, skipping protected files.
    # NOTE: $_.Name -in $Array is PowerShell 3+ syntax; Windows PowerShell 5.1
    # has it, but older hosts (or a PS 2 engine forced by the environment)
    # silently throw here, which used to abort the copy halfway and leave an
    # engine folder with version.txt but no *.bat strategies. Use the portable
    # .Contains() call instead.
    $exclude = @($script:ExcludeFiles)
    if (-not (Test-Path -LiteralPath $To)) { New-Item -ItemType Directory -Path $To | Out-Null }
    Get-ChildItem -LiteralPath $From -Force | ForEach-Object {
        $dst = Join-Path $To $_.Name
        if ($_.PSIsContainer) {
            Copy-TreeOver $_.FullName $dst
        } else {
            if ($exclude.Contains($_.Name)) { return }
            if ($_.Name -like "$script:KeepBatPrefix*" -and (Test-Path -LiteralPath $dst)) { return }
            Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
        }
    }
}

function Test-EngineInstall([string]$EngineDir) {
    # True only when the engine folder really contains winws.exe (root or bin\)
    # AND at least one strategy .bat. Shared by the "already up to date" check
    # and the post-copy verification.
    if ([string]::IsNullOrEmpty($EngineDir) -or -not (Test-Path -LiteralPath $EngineDir)) { return $false }
    $winws = (Test-Path -LiteralPath (Join-Path $EngineDir 'bin\winws.exe')) -or
             (Test-Path -LiteralPath (Join-Path $EngineDir 'winws.exe'))
    if (-not $winws) { return $false }
    $bats = @(Get-ChildItem -LiteralPath $EngineDir -Filter '*.bat' -File -ErrorAction SilentlyContinue)
    return ($bats.Count -gt 0)
}

try {
    # ---- paths -------------------------------------------------
    # Resolve the script dir robustly ($MyInvocation.MyCommand.Path is
    # empty when the file is dot-sourced).
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { $scriptPath = (Get-PSCallStack)[0].ScriptName }
    $srcDir  = Split-Path -Parent $scriptPath                      # <root>\src
    $root    = Split-Path -Parent $srcDir                           # <root>
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

    # ---- pick the archive asset --------------------------------
    # Flowseal publishes .zip / .rar / .tar.gz for the SAME build. Only the
    # .zip can be unpacked with Expand-Archive, so prefer it explicitly by
    # extension (a loose '.zip' regex once matched nothing when the release
    # shipped only .rar + .tar.gz -> "В релизе не найден .zip архив").
    $assets   = @($release.assets)
    $zipAsset = $assets | Where-Object { $_.name -and $_.name.ToLower().EndsWith('.zip') } | Select-Object -First 1
    $altAsset = $assets | Where-Object { $_.name -and ($_.name.ToLower().EndsWith('.rar') -or $_.name.ToLower().EndsWith('.7z')) } | Select-Object -First 1

    if ($zipAsset) {
        $script:ArchiveKind = 'zip'
        $dlUrl = $zipAsset.browser_download_url
        $arch  = Join-Path $env:TEMP ('zapret-' + $latest + '.zip')
    } elseif ($altAsset) {
        # no zip available - fall back to WinRAR/7-Zip if the user has one
        $script:ArchiveKind = 'rar'
        $ext = [IO.Path]::GetExtension($altAsset.name)
        $dlUrl = $altAsset.browser_download_url
        $arch  = Join-Path $env:TEMP ('zapret-' + $latest + $ext)
    } else {
        throw 'В релизе нет ни .zip, ни .rar архива.'
    }

    # ---- compare with local version ----------------------------
    $local = ''
    if (Test-Path $verFile) { $local = ((Get-Content $verFile -First 1) + '').Trim() }

    Write-Host ('[zeye] Локальная версия: ' + $(if ($local) { $local } else { 'нет' }) + ' -> новая: ' + $latest)

    # ---- is the installed engine actually usable? --------------
    # If a previous run was interrupted mid-copy (or files were deleted by
    # hand), version.txt can claim the engine is current while winws.exe and
    # the strategy .bat files are gone. Then an early "Уже актуально" would
    # skip the download and menu.bat would fail with
    # ".bat стратегии не найдены в движке". So only trust version.txt when
    # the binaries are really on disk; otherwise force a redownload.
    $engineOk = Test-EngineInstall $engine

    if (($local -eq $latest) -and (-not $Force) -and $engineOk) {
        Write-Host "[zeye] Уже актуально: $latest"
        exit 0
    }
    if (($local -eq $latest) -and (-not $Force) -and -not $engineOk) {
        Write-Host '[zeye] Папка движка повреждена или пуста — скачиваю заново...'
    }

    # stop the engine while replacing binaries.
    # NOTE: do NOT use taskkill here - when winws.exe is not running it prints
    # "ERROR: The process "winws.exe" not found." to stderr, which under
    # $ErrorActionPreference='Stop' PowerShell turns into a terminating NativeCommandError.
    Stop-EngineProcesses

    # ---- download silently to %TEMP% ---------------------------
    $extract = Join-Path $env:TEMP ('zapret-extract-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    # --fail: without it curl exits 0 on HTTP errors (404/403 rate limit) and
    # the unpacker then chokes on an HTML error page instead of an archive.
    Invoke-Curl @('-L', '-sS', '--fail', '--max-time', '600', '-o', $arch, $dlUrl) | Out-Null
    if ((Get-Item $arch).Length -lt 10240) { throw 'Скачанный файл слишком мал — похоже, релиз не доступен.' }

    if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
    New-Item -ItemType Directory -Path $extract | Out-Null

    if ($script:ArchiveKind -eq 'zip') {
        Expand-Archive -Path $arch -DestinationPath $extract -Force
    } else {
        # .rar/.7z fallback: only possible with an external unpacker
        $unpack = $null
        foreach ($cand in @(
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
            "$env:ProgramFiles\WinRAR\Rar.exe",
            "${env:ProgramFiles(x86)}\WinRAR\Rar.exe",
            "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
        )) {
            if ($cand -and (Test-Path $cand)) { $unpack = $cand; break }
        }
        if (-not $unpack) {
            throw ('В релизе нет .zip (скачан ' + [IO.Path]::GetFileName($arch) +
                   '), а 7-Zip/WinRAR не найдены. Установи 7-Zip или скачай движок вручную.')
        }
        if ($unpack -match '7z\.exe$') {
            & $unpack 'x' "-o$extract" $arch '-y' | Out-Null
        } else {
            & $unpack 'x' '-y' $arch ($extract + '\') | Out-Null
        }
        if ($LASTEXITCODE -ne 0) { throw "Распаковка архива не удалась (exit $LASTEXITCODE)." }
    }

    # The archive contains a single top folder like "zapret-discord-youtube-1.10.2".
    # Some packers/older releases extract files straight into $extract, so only
    # descend when there is exactly ONE top-level directory and no loose files -
    # otherwise we would copy an empty dir and end up with an engine that has
    # version.txt but no *.bat strategies ("`.bat стратегии не найдены в движке`").
    $inner = Get-Item $extract
    $topDirs  = @(Get-ChildItem -LiteralPath $extract -Directory -ErrorAction SilentlyContinue)
    $topFiles = @(Get-ChildItem -LiteralPath $extract -File -ErrorAction SilentlyContinue)
    if ($topDirs.Count -eq 1 -and $topFiles.Count -eq 0) { $inner = $topDirs[0] }

    # ---- copy over zapret-engine\ with exceptions --------------
    Copy-TreeOver $inner.FullName $engine

    # ---- verify the install BEFORE writing version.txt ----------
    # If winws.exe or the strategy .bat files did not land in zapret-engine\,
    # claiming the version would make the next run print "Уже актуально" and
    # skip the redownload forever (that is exactly how "Движок: не установлен"
    # + ".bat стратегии не найдены в движке" appeared together).
    $batCount = @(Get-ChildItem -LiteralPath $engine -Filter '*.bat' -File -ErrorAction SilentlyContinue).Count
    if (-not (Test-EngineInstall $engine)) {
        throw ('Распаковано, но в zapret-engine\ нет winws.exe или .bat стратегий ' +
               '(файлов .bat: ' + $batCount + '). Проверь, не блокирует ли антивирус/SmartScreen копирование.')
    }
    Write-Host ('[zeye] Файлов стратегий: ' + $batCount + ', winws.exe: ок')

    # make sure the user list exists (add/remove writes into it)
    $userList = Join-Path $engine 'lists\list-general-user.txt'
    if (-not (Test-Path $userList)) {
        New-Item -ItemType Directory -Path (Split-Path $userList) -Force | Out-Null
        Set-Content -Path $userList -Value '' -Encoding UTF8 -NoNewline
    }

    # ---- record the installed version --------------------------
    Set-Content -Path $verFile -Value $latest -Encoding ASCII
    Remove-Item $arch -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[zeye] Движок обновлён до $latest"
    exit 0
}
catch {
    Write-Host "[zeye] ОШИБКА обновления: $($_.Exception.Message)"
    exit 1
}
