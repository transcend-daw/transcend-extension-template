<#
    test.ps1 - run this extension's tests in the Transcend installed on this computer.

        pwsh tools/test.ps1                     # every test in tests/
        pwsh tools/test.ps1 -Only "Fade In"     # just the tests whose name contains this
        pwsh tools/test.ps1 -Transcend <path>   # a Transcend somewhere else (or set TRANSCEND_EXE)

    The tests run inside Transcend's real script sandbox, against a pretend project (tests/project.json),
    with no window and no audio. Works in Windows PowerShell 5.1 and PowerShell 7.
    Exit code: 0 all passed, 1 a test failed, 2 the tests could not run.
#>
[CmdletBinding()]
param(
    [string]$Only = "",
    [string]$Transcend = ""
)

$root = Split-Path -Parent $PSScriptRoot
$package = Join-Path $root "package"

function Find-Transcend {
    if ($Transcend) { return $Transcend }
    if ($env:TRANSCEND_EXE) { return $env:TRANSCEND_EXE }
    $onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    if ($onWindows) {
        # The installer's uninstall entry knows where it put Transcend.
        $key = "Software\Microsoft\Windows\CurrentVersion\Uninstall\{7B3A9C41-5E6D-4A02-9F18-2C7D4E8B1A63}_is1"
        foreach ($hive in @("HKLM:", "HKCU:")) {
            $p = Get-ItemProperty -Path "$hive\$key" -ErrorAction SilentlyContinue
            if ($p -and $p.InstallLocation) {
                $exe = Join-Path $p.InstallLocation "Transcend.exe"
                if (Test-Path $exe) { return $exe }
            }
        }
        foreach ($dir in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA "Programs"))) {
            if ($dir) { $exe = Join-Path $dir "Transcend\Transcend.exe"; if (Test-Path $exe) { return $exe } }
        }
    } else {
        foreach ($app in @("/Applications/Transcend.app", (Join-Path $HOME "Applications/Transcend.app"))) {
            $exe = Join-Path $app "Contents/MacOS/Transcend"
            if (Test-Path $exe) { return $exe }
        }
    }
    return $null
}

$exe = Find-Transcend
if (-not $exe -or -not (Test-Path $exe)) {
    Write-Host "Transcend was not found. Install it, or point at it with -Transcend <path> or TRANSCEND_EXE." -ForegroundColor Red
    exit 2
}

$report = Join-Path ([IO.Path]::GetTempPath()) ("transcend-tests-" + [Guid]::NewGuid().ToString("N") + ".json")
$cmdArgs = @("--test-extension", $package, "--report", $report)
if ($Only) { $cmdArgs += @("--only", $Only) }

# Piping the output makes PowerShell wait for Transcend and hand its report over line by line (it is
# a windowed program, so without a pipe its output would go nowhere).
& $exe @cmdArgs 2>&1 | ForEach-Object {
    $line = "$_"
    if ($line -match '^\s+ok\s') { Write-Host $line -ForegroundColor Green }
    elseif ($line -match '^\s+FAIL\s') { Write-Host $line -ForegroundColor Red }
    else { Write-Host $line }
}
$code = $LASTEXITCODE
if (-not (Test-Path $report)) {
    Write-Host "Transcend did not run the tests (is it older than API level 12? update it)." -ForegroundColor Red
    exit 2
}
Remove-Item -Force $report -ErrorAction SilentlyContinue
exit $code
