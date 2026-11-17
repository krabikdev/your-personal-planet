#Requires -Version 5.1
<#
.SYNOPSIS
    Add a project to Godot's Project Manager list.

.DESCRIPTION
    Godot only adds a project to the Project Manager when it is created or opened
    through the Project Manager itself. Opening a project with
    `godot --editor --path <dir>` does NOT register it, so projects made by the
    New Godot Game shortcut would never show up in the list.

    This appends the section Godot expects to %APPDATA%\Godot\projects.cfg:

        [C:/path/to/project]

        favorite=false

    The operation is idempotent: an existing entry is left untouched.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Project folder not found: $Path" -ForegroundColor Red
    exit 1
}

$full = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
if (-not (Test-Path (Join-Path $full 'project.godot'))) {
    Write-Host "Not a Godot project (no project.godot): $full" -ForegroundColor Red
    exit 1
}

$configDir = Join-Path $env:APPDATA 'Godot'
$configFile = Join-Path $configDir 'projects.cfg'
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Godot stores project paths with forward slashes.
$normalized = ($full -replace '\\', '/').TrimEnd('/')
$section = "[$normalized]"

$existing = ''
if (Test-Path $configFile) {
    $existing = [System.IO.File]::ReadAllText($configFile, [System.Text.Encoding]::UTF8)
}

if ($existing -match ('(?im)^\s*' + [regex]::Escape($section) + '\s*$')) {
    Write-Host "  Already in Project Manager: $normalized" -ForegroundColor DarkGray
    exit 0
}

$entry = "$section`r`n`r`nfavorite=false`r`n`r`n"
if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) {
    $entry = "`r`n$entry"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($configFile, $existing + $entry, $utf8NoBom)

Write-Host "  Added to Project Manager: $normalized" -ForegroundColor Green
exit 0
