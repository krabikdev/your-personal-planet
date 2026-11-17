#Requires -Version 5.1
<#
.SYNOPSIS
    Create (or refresh) the Godot desktop shortcuts. Safe to re-run.

.DESCRIPTION
    Creates three shortcuts on the current user's Desktop:
      1. Godot 4 - Project Manager   open Godot with no project (create/open games)
      2. Typical Project (Godot)     open C:\Godot with Godot AI connected
      3. New Godot Game              scaffold a new game from this template and open it

    Each one goes through tools\launch-godot.ps1, which rebuilds PATH so the
    Godot AI plugin can find uvx.
#>
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $PSScriptRoot 'launch-godot.ps1'
$newGame = Join-Path $PSScriptRoot 'new-godot-game.ps1'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

$console = [Environment]::GetEnvironmentVariable('GODOT', 'User')
if ([string]::IsNullOrWhiteSpace($console) -or -not (Test-Path $console)) {
    Write-Host "GODOT user variable is missing or invalid. Run the setup again." -ForegroundColor Red
    exit 1
}
$iconExe = $console -replace '_console\.exe$', '.exe'
if (-not (Test-Path $iconExe)) { $iconExe = $console }

$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) {
    Write-Host 'Could not resolve the Desktop folder.' -ForegroundColor Red
    exit 1
}

$shell = New-Object -ComObject WScript.Shell

function Set-Shortcut {
    param(
        [string]$FileName,
        [string]$Arguments,
        [string]$Description
    )
    $path = Join-Path $desktop $FileName
    $sc = $shell.CreateShortcut($path)
    $sc.TargetPath = $powershell
    $sc.Arguments = $Arguments
    $sc.WorkingDirectory = $root
    $sc.IconLocation = "$iconExe,0"
    $sc.Description = $Description
    $sc.WindowStyle = 1
    $sc.Save()
    Write-Host "  $path"
}

Write-Host 'Creating desktop shortcuts:' -ForegroundColor Cyan

Set-Shortcut `
    -FileName 'Godot 4 - Project Manager.lnk' `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`"" `
    -Description 'Open the Godot 4 Project Manager (create a new game or open an existing project)'

Set-Shortcut `
    -FileName 'Typical Project (Godot).lnk' `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`" -ProjectPath `"$root`"" `
    -Description 'Open the Typical Project in Godot 4 with Godot AI connected'

Set-Shortcut `
    -FileName 'New Godot Game.lnk' `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$newGame`"" `
    -Description 'Create a new Godot 4 game from the Typical Project template'

Write-Host ''
Write-Host 'Done. Re-run this script any time to refresh them.' -ForegroundColor Green
