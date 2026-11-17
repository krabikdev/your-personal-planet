#Requires -Version 5.1
<#
.SYNOPSIS
    Open an OpenCode session rooted at a project folder.

.DESCRIPTION
    Starts the OpenCode CLI in the given directory inside the current console
    window. OpenCode loads that folder's AGENTS.md, .opencode/skills, and
    opencode.json (Godot AI + Context7 MCP servers) automatically, so the user
    can type a request straight away.

    The session is stored in the same session database the desktop app uses,
    so it also shows up in the OpenCode app afterwards.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Folder not found: $Path" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
$Path = (Resolve-Path -LiteralPath $Path).Path

# Newest installed CLI under the desktop app's versioned folder.
$cliRoot = Join-Path $env:APPDATA 'ai.opencode.desktop\cli'
$cli = Get-ChildItem -Path $cliRoot -Filter 'opencode-cli.exe' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if (-not $cli) {
    Write-Host "OpenCode CLI not found under $cliRoot" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

$leaf = Split-Path -Leaf $Path
try { $Host.UI.RawUI.WindowTitle = "OpenCode - $leaf" } catch { }

Write-Host ''
Write-Host "  OpenCode - $leaf" -ForegroundColor Cyan
Write-Host "  $Path" -ForegroundColor DarkGray
Write-Host '  Ask for a feature, e.g. "create a player that moves with WASD"' -ForegroundColor DarkGray
Write-Host ''

Set-Location -LiteralPath $Path
& $cli.FullName $Path
