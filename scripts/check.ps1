#Requires -Version 5.1
<#
.SYNOPSIS
    Project check pipeline: format, lint, project load, headless tests.

.DESCRIPTION
    Runs, in order:
      1. gdformat --check   (formatting is canonical)
      2. gdlint             (static analysis)
      3. headless project load, failing on any ERROR / SCRIPT ERROR
      4. GUT tests headless via the CLI runner

    Exits 0 only when every stage passes. Exits non-zero on the first
    failing stage summary, after reporting all results.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\check.ps1
#>

$ErrorActionPreference = 'Continue'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
Set-Location $projectRoot

$results = @()

function Add-Result {
    param([string]$Stage, [bool]$Ok, [string]$Detail)
    $script:results += [pscustomobject]@{ Stage = $Stage; Ok = $Ok; Detail = $Detail }
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- prerequisites
$godot = $env:GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = [Environment]::GetEnvironmentVariable('GODOT', 'User')
}
if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path $godot)) {
    Write-Host "GODOT is not set or points to a missing file." -ForegroundColor Red
    Write-Host "Set it with: [Environment]::SetEnvironmentVariable('GODOT','<path to *_console.exe>','User')"
    exit 1
}

# gdtoolkit installs into the uv tool bin directory.
$toolBin = Join-Path $env:USERPROFILE '.local\bin'
if ((Test-Path $toolBin) -and ($env:Path -notlike "*$toolBin*")) {
    $env:Path = "$toolBin;$env:Path"
}

foreach ($tool in @('gdformat', 'gdlint')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "$tool not found. Install with: uv tool install gdtoolkit" -ForegroundColor Red
        exit 1
    }
}

# Project GDScript only. Third-party addons are not ours to reformat.
$sourceDirs = @('scripts', 'ui', 'tests', 'scenes')
$gdFiles = @()
foreach ($dir in $sourceDirs) {
    if (Test-Path $dir) {
        $gdFiles += Get-ChildItem -Path $dir -Filter *.gd -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\addons\\' } |
            ForEach-Object { $_.FullName }
    }
}

# ------------------------------------------------------------------- 1. format
Write-Header "1/4 gdformat --check"
if ($gdFiles.Count -eq 0) {
    Write-Host "(no GDScript files to format yet)"
    Add-Result 'gdformat' $true 'no files'
} else {
    & gdformat --check @gdFiles
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Formatting OK ($($gdFiles.Count) files)" -ForegroundColor Green
        Add-Result 'gdformat' $true "$($gdFiles.Count) files"
    } else {
        Write-Host "Formatting violations found. Fix with: gdformat $($sourceDirs -join ' ')" -ForegroundColor Red
        Add-Result 'gdformat' $false 'needs formatting'
    }
}

# --------------------------------------------------------------------- 2. lint
Write-Header "2/4 gdlint"
if ($gdFiles.Count -eq 0) {
    Write-Host "(no GDScript files to lint yet)"
    Add-Result 'gdlint' $true 'no files'
} else {
    & gdlint @gdFiles
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Lint OK" -ForegroundColor Green
        Add-Result 'gdlint' $true 'clean'
    } else {
        Add-Result 'gdlint' $false 'violations'
    }
}

# ------------------------------------------------------------- 3. project load
Write-Header "3/4 headless project load"
$loadOutput = & $godot --headless --path $projectRoot --quit 2>&1 | Out-String
$loadExit = $LASTEXITCODE
$loadErrors = @($loadOutput -split "`r?`n" | Where-Object { $_ -match 'ERROR|SCRIPT ERROR' })

if ($loadExit -ne 0) {
    Write-Host $loadOutput
    Write-Host "Project load exited with code $loadExit" -ForegroundColor Red
    Add-Result 'project-load' $false "exit $loadExit"
} elseif ($loadErrors.Count -gt 0) {
    Write-Host "Errors reported during load:" -ForegroundColor Red
    $loadErrors | ForEach-Object { Write-Host "  $_" }
    Add-Result 'project-load' $false "$($loadErrors.Count) error lines"
} else {
    Write-Host "Project loads cleanly" -ForegroundColor Green
    Add-Result 'project-load' $true 'clean'
}

# -------------------------------------------------------------------- 4. tests
Write-Header "4/4 GUT tests (headless)"
$gutArgs = @(
    '--headless',
    '--path', $projectRoot,
    '-s', 'addons/gut/gut_cmdln.gd',
    '-gdir=res://tests',
    '-ginclude_subdirs',
    '-gexit',
    '-glog=1'
)
$gutOutput = & $godot @gutArgs 2>&1 | Out-String
$gutExit = $LASTEXITCODE

# GUT wraps its summary in ANSI colour codes; strip them before parsing.
$gutClean = $gutOutput -replace "\x1b\[[0-9;]*m", ''

$tests = 0
$passing = 0
$failing = 0
if ($gutClean -match '(?m)^Tests\s+(\d+)') { $tests = [int]$Matches[1] }
if ($gutClean -match 'Passing Tests\s+(\d+)') { $passing = [int]$Matches[1] }
if ($gutClean -match 'Failing Tests\s+(\d+)') { $failing = [int]$Matches[1] }

if ($gutExit -ne 0 -or $failing -gt 0 -or $tests -eq 0) {
    Write-Host $gutOutput
    Write-Host "GUT: tests=$tests passing=$passing failing=$failing exit=$gutExit" -ForegroundColor Red
    if ($tests -eq 0) { Write-Host "No tests were collected from res://tests." -ForegroundColor Red }
    Add-Result 'gut' $false "tests=$tests failing=$failing exit=$gutExit"
} else {
    Write-Host "GUT: tests=$tests passing=$passing failing=$failing" -ForegroundColor Green
    Add-Result 'gut' $true "tests=$tests passing=$passing"
}

# ------------------------------------------------------------------- summary
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
foreach ($r in $results) {
    $label = if ($r.Ok) { 'PASS' } else { 'FAIL' }
    $color = if ($r.Ok) { 'Green' } else { 'Red' }
    Write-Host ("  {0,-14} {1,-5} {2}" -f $r.Stage, $label, $r.Detail) -ForegroundColor $color
}
$failed = @($results | Where-Object { -not $_.Ok })
Write-Host "=========================================" -ForegroundColor Cyan

if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) stage(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All stages passed." -ForegroundColor Green
exit 0
