<#
    check_extension.ps1 - the automated checks every extension on the Get Extensions shelf passes.

        pwsh check_extension.ps1 -Folder <package folder>                 # check it (Reviewed rules)
        pwsh check_extension.ps1 -Folder <package folder> -Community      # check it as a Community package
        pwsh check_extension.ps1 -Folder <package folder> -Pack out.tpkg  # check it and build the .tpkg

    ONE FILE, THREE USERS, SO THE ANSWER CANNOT DIFFER BETWEEN THEM:
      * publish_extension.ps1 dot-sources it (Reviewed -Folder, and -SyncCommunity, which re-checks every
        Community release before it is listed);
      * the community template's release workflow runs it on the author's tag, so a package the shelf
        would refuse fails in the author's own CI with the same sentence;
      * the index repo's pull-request check runs it on the release a pull request names.
    The template and the index repo carry a COPY (packaging/extensions/build_template.ps1 puts it
    there, with the API level stamped below); when the rules change here, rebuild them.

    Works in Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux (GitHub's runners).

    Exit codes: 0 passed (and packed), 1 refused (one sentence says why).
#>

[CmdletBinding()]
param(
    [string]$Folder = "",
    [switch]$Community,
    [string]$Pack = "",
    [int]$MaxApiLevel = 0
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# The newest API level the app implements. In the source tree it is read from extensions_gate.h; a copy
# outside it (the template, the index repo) uses the number stamped here by build_template.ps1.
$TxStampedApiLevel = 14

$TxKnownPayloads = @("theme", "layout", "icons", "presets", "scripts", "fonts")
$TxAssetExt      = @(".png", ".jpg", ".jpeg", ".svg", ".ttf", ".otf", ".webp", ".bmp", ".wav", ".flac")
$TxMaxAsset      = 4MB
$TxMaxArchive    = 64MB

function Get-TxApiLevel {
    $gate = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "TranscendUI_CPP/extensions_gate.h"
    if (Test-Path $gate) {
        $m = [regex]::Match([IO.File]::ReadAllText($gate), 'kApiLevel\s*=\s*(\d+)')
        if ($m.Success) { return [int]$m.Groups[1].Value }
    }
    return $TxStampedApiLevel
}

function Test-IdUsable([string]$id) {
    return ($id -and $id.Length -le 128 -and -not $id.StartsWith(".") -and -not $id.Contains("..") -and $id -match '^[A-Za-z0-9._-]+$')
}

function Test-TxHas($obj, [string]$name) { return ($obj.PSObject.Properties.Name -contains $name) -and $obj.$name }

# The checks. Throws one sentence when the package is refused; returns the manifest when it passes.
function Test-Package([string]$dir, [bool]$community, [int]$apiLevel = 0) {
    if ($apiLevel -le 0) { $apiLevel = Get-TxApiLevel }
    if (-not (Test-Path $dir -PathType Container)) { throw "there is no folder at $dir" }
    $mf = Join-Path $dir "manifest.json"
    if (-not (Test-Path $mf)) { throw "no manifest.json" }
    try { $m = [IO.File]::ReadAllText($mf) | ConvertFrom-Json } catch { throw "manifest.json is not valid JSON" }
    if (-not (Test-TxHas $m "format") -or $m.format -ne "transcend.package") { throw "manifest.json is not a transcend.package" }
    foreach ($k in @("id", "name", "version", "provides")) {
        if (-not (Test-TxHas $m $k)) { throw "manifest.json has no $k" }
    }
    if (-not (Test-IdUsable $m.id)) { throw "the id '$($m.id)' is not usable" }
    if ($community -and $m.id -like "com.transcend.*") { throw "the id prefix 'com.transcend.' is kept for Transcend's own extensions; pick an id of your own (for example io.github.<you>.<name>)" }
    if ($m.version -notmatch '^\d+(\.\d+){0,3}([-+][0-9A-Za-z.-]+)?$') { throw "the version '$($m.version)' is not a version number (for example 1.0.0)" }
    $provides = @($m.provides)
    $actual = @()
    if (Test-Path (Join-Path $dir "theme.json"))  { $actual += "theme" }
    if (Test-Path (Join-Path $dir "layout.json")) { $actual += "layout" }
    foreach ($d in @("icons", "presets", "scripts", "fonts")) {
        $p = Join-Path $dir $d
        if ((Test-Path $p) -and @(Get-ChildItem -Recurse -File $p).Count) { $actual += $d }
    }
    foreach ($p in $provides) { if ($TxKnownPayloads -notcontains $p) { throw "it provides '$p', which no build knows" } }
    foreach ($p in $provides) { if ($actual -notcontains $p) { throw "it says it provides '$p' and does not" } }
    foreach ($p in $actual)   { if ($provides -notcontains $p) { throw "it carries '$p' it does not declare" } }
    $perms = @()
    if ($m.PSObject.Properties.Name -contains "permissions") { $perms = @($m.permissions) }
    if ($community -and ($perms -contains "network")) { throw "a Community package may not ask for network access" }
    if ($actual -contains "scripts") {
        $lvl = 0; if ($m.PSObject.Properties.Name -contains "apiLevel") { $lvl = [int]$m.apiLevel }
        if ($lvl -lt 1) { throw "it carries scripts and names no apiLevel" }
        if ($lvl -gt $apiLevel) { throw "it needs API level $lvl; Transcend implements $apiLevel" }
        if (-not (Test-TxHas $m "entry") -or -not (Test-Path (Join-Path $dir $m.entry))) { throw "its entry script is missing" }
    }
    foreach ($f in Get-ChildItem -Recurse -File $dir) {
        if ($TxAssetExt -contains $f.Extension.ToLower() -and $f.Length -gt $TxMaxAsset) { throw "$($f.Name) is over 4 MB" }
    }
    return $m
}

# A ZIP of the folder's CONTENTS with forward-slash names (PowerShell 5.1's Compress-Archive writes
# backslashes, which no ZIP reader should accept). Dot-files and node_modules stay out.
function New-Tpkg([string]$dir, [string]$out) {
    if (Test-Path $out) { Remove-Item -Force $out }
    $root = (Resolve-Path $dir).Path.TrimEnd('\', '/')
    $outFull = [IO.Path]::GetFullPath($out)
    $fs = [IO.File]::Open($outFull, [IO.FileMode]::CreateNew)
    $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in Get-ChildItem -Recurse -File $root | Sort-Object FullName) {
            if ($f.FullName -eq $outFull) { continue }
            $rel = $f.FullName.Substring($root.Length + 1).Replace("\", "/")
            if ($rel -match '(^|/)\.' -or $rel -match '(^|/)node_modules/') { continue }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $rel, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
    if ((Get-Item $outFull).Length -gt $TxMaxArchive) { throw "the archive is over 64 MB" }
}

# Run as a script (not dot-sourced): check, and pack if asked.
if ($MyInvocation.InvocationName -ne '.' -and $Folder) {
    try {
        $m = Test-Package $Folder ([bool]$Community) $MaxApiLevel
        Write-Host ("passed: {0} {1} ({2})" -f $m.name, $m.version, $m.id)
        if ($Pack) {
            New-Tpkg $Folder $Pack
            Write-Host ("packed: {0} ({1:N0} bytes)" -f $Pack, (Get-Item $Pack).Length)
        }
        exit 0
    } catch {
        Write-Host ("refused: " + $_.Exception.Message)
        exit 1
    }
}
