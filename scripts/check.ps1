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

    Exits 0 only when every stage passes. Exits non-zero when a stage fails,
    after reporting every stage it ran.

.PARAMETER Quick
    Format and lint only. Use after each edit; takes a couple of seconds.

.PARAMETER Test
    Format, lint and only the test files whose name contains these strings.
    Skips the headless load, since the tests load the project anyway.

.PARAMETER NoTests
    Everything except the GUT tests.

.PARAMETER NoLoad
    Everything except the headless project load.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1 -Quick
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1 -Test rope
#>

param(
    [switch]$Quick,
    [switch]$NoTests,
    [switch]$NoLoad,
    [string[]]$Test = @()
)

$ErrorActionPreference = 'Continue'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
Set-Location $projectRoot

$runLoad = $true
$runTests = $true
if ($Quick) {
    $runLoad = $false
    $runTests = $false
}
if ($NoLoad) { $runLoad = $false }
if ($NoTests) { $runTests = $false }
if ($Test.Count -gt 0) { $runLoad = $false }

$results = @()

function Add-Result {
    param([string]$Stage, [bool]$Ok, [string]$Detail, [string]$Duration)
    $script:results += [pscustomobject]@{ Stage = $Stage; Ok = $Ok; Detail = $Detail; Time = $Duration }
}

function Format-Duration {
    param([long]$Milliseconds)
    if ($Milliseconds -lt 1000) { return "${Milliseconds}ms" }
    return ('{0:N1}s' -f ($Milliseconds / 1000.0))
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

# ---------------------------------------------------------------- prerequisites
if ($runLoad -or $runTests) {
    $godot = $env:GODOT
    if ([string]::IsNullOrWhiteSpace($godot)) {
        $godot = [Environment]::GetEnvironmentVariable('GODOT', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path $godot)) {
        Write-Host "GODOT is not set or points to a missing file." -ForegroundColor Red
        Write-Host "Set it with: [Environment]::SetEnvironmentVariable('GODOT','<path to *_console.exe>','User')"
        exit 1
    }
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

$stageTotal = 2
if ($runLoad) { $stageTotal++ }
if ($runTests) { $stageTotal++ }
$stageIndex = 0

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
$stageIndex++
Write-Header "$stageIndex/$stageTotal gdformat --check"
$timer = [System.Diagnostics.Stopwatch]::StartNew()
if ($gdFiles.Count -eq 0) {
    Write-Host "(no GDScript files to format yet)"
    Add-Result 'gdformat' $true 'no files' (Format-Duration $timer.ElapsedMilliseconds)
} else {
    & gdformat --check @gdFiles
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Formatting OK ($($gdFiles.Count) files)" -ForegroundColor Green
        Add-Result 'gdformat' $true "$($gdFiles.Count) files" (Format-Duration $timer.ElapsedMilliseconds)
    } else {
        Write-Host "Formatting violations found. Fix with: gdformat $($sourceDirs -join ' ')" -ForegroundColor Red
        Add-Result 'gdformat' $false 'needs formatting' (Format-Duration $timer.ElapsedMilliseconds)
    }
}

# --------------------------------------------------------------------- 2. lint
$stageIndex++
Write-Header "$stageIndex/$stageTotal gdlint"
$timer = [System.Diagnostics.Stopwatch]::StartNew()
if ($gdFiles.Count -eq 0) {
    Write-Host "(no GDScript files to lint yet)"
    Add-Result 'gdlint' $true 'no files' (Format-Duration $timer.ElapsedMilliseconds)
} else {
    & gdlint @gdFiles
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Lint OK" -ForegroundColor Green
        Add-Result 'gdlint' $true 'clean' (Format-Duration $timer.ElapsedMilliseconds)
    } else {
        Add-Result 'gdlint' $false 'violations' (Format-Duration $timer.ElapsedMilliseconds)
    }
}

# ------------------------------------------------------------- 3. project load
if ($runLoad) {
    $stageIndex++
    Write-Header "$stageIndex/$stageTotal headless project load"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $loadOutput = & $godot --headless --path $projectRoot --quit 2>&1 | Out-String
    $loadExit = $LASTEXITCODE
    $loadErrors = @($loadOutput -split "`r?`n" | Where-Object { $_ -match 'ERROR|SCRIPT ERROR' })

    if ($loadExit -ne 0) {
        Write-Host $loadOutput
        Write-Host "Project load exited with code $loadExit" -ForegroundColor Red
        Add-Result 'project-load' $false "exit $loadExit" (Format-Duration $timer.ElapsedMilliseconds)
    } elseif ($loadErrors.Count -gt 0) {
        Write-Host "Errors reported during load:" -ForegroundColor Red
        $loadErrors | ForEach-Object { Write-Host "  $_" }
        Add-Result 'project-load' $false "$($loadErrors.Count) error lines" (Format-Duration $timer.ElapsedMilliseconds)
    } else {
        Write-Host "Project loads cleanly" -ForegroundColor Green
        Add-Result 'project-load' $true 'clean' (Format-Duration $timer.ElapsedMilliseconds)
    }
}

# -------------------------------------------------------------------- 4. tests
if ($runTests) {
    $stageIndex++
    Write-Header "$stageIndex/$stageTotal GUT tests (headless)"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    $gutArgs = @(
        '--headless',
        '--path', $projectRoot,
        '-s', 'addons/gut/gut_cmdln.gd'
    )

    $testFiles = @()
    foreach ($filter in $Test) {
        if (Test-Path $filter) {
            $testFiles += (Resolve-Path $filter).Path
        } else {
            $testFiles += Get-ChildItem -Path 'tests' -Filter "*$filter*.gd" -Recurse -File -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName }
        }
    }

    if ($testFiles.Count -eq 0 -and $Test.Count -gt 0) {
        Write-Host "No test files match: $($Test -join ', ')" -ForegroundColor Red
        exit 2
    }

    if ($testFiles.Count -gt 0) {
        foreach ($file in $testFiles) {
            $relative = $file.Substring($projectRoot.Length) -replace '^[\\/]+', '' -replace '\\', '/'
            $gutArgs += "-gtest=res://$relative"
            Write-Host "  $relative"
        }
    } else {
        $gutArgs += @('-gdir=res://tests', '-ginclude_subdirs')
    }
    $gutArgs += @('-gexit', '-glog=1')

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
        if ($tests -eq 0) { Write-Host "No tests were collected." -ForegroundColor Red }
        Add-Result 'gut' $false "tests=$tests failing=$failing exit=$gutExit" (Format-Duration $timer.ElapsedMilliseconds)
    } else {
        Write-Host "GUT: tests=$tests passing=$passing failing=$failing" -ForegroundColor Green
        Add-Result 'gut' $true "tests=$tests passing=$passing" (Format-Duration $timer.ElapsedMilliseconds)
    }
}

# ------------------------------------------------------------------- summary
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Cyan
foreach ($r in $results) {
    $label = if ($r.Ok) { 'PASS' } else { 'FAIL' }
    $color = if ($r.Ok) { 'Green' } else { 'Red' }
    Write-Host ("  {0,-14} {1,-5} {2,-22} {3}" -f $r.Stage, $label, $r.Detail, $r.Time) -ForegroundColor $color
}
$failed = @($results | Where-Object { -not $_.Ok })
Write-Host "=========================================" -ForegroundColor Cyan

if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) stage(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All stages passed." -ForegroundColor Green
exit 0
