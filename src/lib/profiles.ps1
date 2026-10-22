# ============================================================
#  ZapretEye (zeye) - list engine strategy profiles
#  Prints one line per *.bat strategy found in zapret-engine\:
#      <file-name>.bat|<arguments parsed from the winws.exe line>
#  Used by menu.bat (:pickstrategy) and zeye.bat (profiles).
#
#  Why a PS helper instead of a cmd "for %%F in (...)" loop:
#  cmd's globbing silently yields zero iterations when the console
#  codepage is 65001 (chcp) on some Windows builds, which made the
#  picker show ".bat стратегии не найдены в движке" even though the
#  files were on disk. Get-ChildItem (the same call check.ps1 uses)
#  is immune to that.
# ============================================================

$ErrorActionPreference = 'Stop'
try {
    $srcDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # <root>\src\lib
    $root   = Split-Path -Parent (Split-Path -Parent $srcDir)   # <root>
    $engine = Join-Path $root 'zapret-engine'

    if (-not (Test-Path -LiteralPath $engine)) { exit 0 }

    # helper scripts that ship inside the release but are not strategies
    $skipNames = @('service.bat', 'uninstall_service.bat', 'update.bat', 'check.bat',
                   'restart.bat', 'run_fast.bat', 'run_general.bat')
    # zeye's own helpers / leftovers copied into the engine folder
    $skipPrefixes = @('zeye-', '_zeye')

    foreach ($f in @(Get-ChildItem -LiteralPath $engine -Filter '*.bat' -File | Sort-Object Name)) {
        if ($f.Name -in $skipNames) { continue }
        if (@($skipPrefixes | Where-Object { $f.Name.ToLower().StartsWith($_) }).Count -gt 0) { continue }
        $argLine = ''
        try {
            # Flowseal profiles invoke the engine like:
            #   winws.exe --filter ... --strategy ...
            # take the first such line and strip everything up to the exe name.
            $line = Select-String -LiteralPath $f.FullName -Pattern 'winws(\.exe)?' -SimpleMatch:$false |
                    Select-Object -First 1
            if ($line) {
                $t = $line.Line.Trim()
                $i = $t.ToLower().IndexOf('winws')
                if ($i -ge 0) {
                    $rest = $t.Substring($i)
                    $j = $rest.IndexOf('.exe')
                    if ($j -ge 0) { $rest = $rest.Substring($j + 4) } else { $rest = $rest.Substring(5) }
                    $argLine = $rest.Trim().TrimStart('"').Trim()
                    # drop a trailing redirection/rem part for readability
                    foreach ($cut in @('>', '^>', 'rem ', 'pause')) {
                        $k = $argLine.IndexOf($cut, [System.StringComparison]::OrdinalIgnoreCase)
                        if ($k -gt 0) { $argLine = $argLine.Substring(0, $k).Trim() }
                    }
                }
            }
        } catch { $argLine = '' }
        Write-Output ($f.Name + '|' + $argLine)
    }
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
