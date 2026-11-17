#Requires -Version 5.1
<#
.SYNOPSIS
    Create a new Godot 4 game pre-configured like this template project.

.DESCRIPTION
    Copies this project's scaffold (Godot AI, GUT, GodotPrompter skills, AGENTS.md,
    opencode.json, scripts/check.ps1, starter main menu) into a new folder, renames
    the project, initialises a git repository, then opens Godot and an OpenCode
    session for it.

    Excluded from the copy: .git, .godot (engine cache), SETUP_LOG.md, export_presets.cfg.

.EXAMPLE
    .\new-godot-game.ps1
    .\new-godot-game.ps1 -Name "Space Shooter" -NoLaunch
#>
param(
    [string]$Name = "",
    [string]$Parent = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

$logFile = Join-Path $env:TEMP 'godot-launcher.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] new-game: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

function Stop-WithError {
    param([string]$Message)
    Write-Host ''
    Write-Host "  $Message" -ForegroundColor Red
    Write-Host "  Details: $logFile" -ForegroundColor DarkGray
    Write-Log "ERROR: $Message"
    # Only wait for a keypress when a human is actually looking at a console.
    if (-not $NoLaunch) { Read-Host '  Press Enter to close' }
    exit 1
}

try {
    $template = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path (Join-Path $template 'project.godot'))) {
        Stop-WithError "Template project not found next to tools/: $template"
    }

    # Fresh PATH so git and uvx are available in this session.
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

    $defaultParent = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Godot Games'

    Write-Host ''
    Write-Host '  New Godot 4 game' -ForegroundColor Cyan
    Write-Host '  -----------------' -ForegroundColor Cyan
    Write-Host "  Games are created in: $defaultParent" -ForegroundColor DarkGray
    Write-Host ''

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Read-Host '  Game name'
    }
    $Name = $Name.Trim()

    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9 _-]{0,49}$') {
        Stop-WithError 'Name must start with a letter or digit and contain only letters, digits, spaces, - or _ (max 50).'
    }

    if ([string]::IsNullOrWhiteSpace($Parent)) { $Parent = $defaultParent }

    $dest = Join-Path $Parent $Name
    if (Test-Path $dest) {
        Stop-WithError "A folder already exists there: $dest"
    }

    Write-Host ''
    Write-Host '  Copying template files...' -ForegroundColor Cyan

    # robocopy is dramatically faster than Copy-Item -Recurse here: Copy-Item
    # re-enumerates the whole tree for every item and can look like a hang.
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    & robocopy $template $dest /E /XD .git .godot /XF SETUP_LOG.md export_presets.cfg /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
    $copyExit = $LASTEXITCODE
    if ($copyExit -ge 8) {
        Stop-WithError "File copy failed (robocopy exit $copyExit)."
    }
    Write-Log "robocopy exit $copyExit -> $dest"

    Write-Host '  Configuring project...' -ForegroundColor Cyan

    if (-not (Test-Path (Join-Path $dest 'project.godot'))) {
        Stop-WithError 'Copy failed: project.godot is missing in the new folder.'
    }

    # Rename the project in project.godot.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $projectFile = Join-Path $dest 'project.godot'
    $text = [System.IO.File]::ReadAllText($projectFile, [System.Text.Encoding]::UTF8)
    $text = $text -replace 'config/name="[^"]*"', ('config/name="' + $Name + '"')
    [System.IO.File]::WriteAllText($projectFile, $text, $utf8NoBom)

    # Rename the title shown on the starter menu.
    $menuFile = Join-Path $dest 'ui\main_menu.tscn'
    if (Test-Path $menuFile) {
        $menu = [System.IO.File]::ReadAllText($menuFile, [System.Text.Encoding]::UTF8)
        $menu = $menu -replace '(?m)^text = "Typical Project"$', ('text = "' + $Name + '"')
        [System.IO.File]::WriteAllText($menuFile, $menu, $utf8NoBom)
    }

    # Initialise git with the same identity the template repo uses.
    Write-Host '  Creating git repository...' -ForegroundColor Cyan
    Push-Location $dest
    # Native tools write progress/warnings to stderr. With ErrorActionPreference
    # = 'Stop', PowerShell 5.1 turns those into terminating errors, and
    # redirecting them with 2>$null while git emits hundreds of CRLF warnings
    # blocks until timeout. Keep stderr on the console and let exit codes decide.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $gitName = & git -C $template config user.name
        $gitEmail = & git -C $template config user.email
        if ([string]::IsNullOrWhiteSpace($gitName)) { $gitName = 'Godot AI Setup' }
        if ([string]::IsNullOrWhiteSpace($gitEmail)) { $gitEmail = 'setup@localhost' }

        & git init --quiet
        & git config core.autocrlf false
        & git config user.name $gitName
        & git config user.email $gitEmail
        & git add -A | Out-Null
        $addExit = $LASTEXITCODE
        & git commit --quiet -m "chore: initial commit for $Name" | Out-Null
        Write-Log "git add exit $addExit, commit exit $LASTEXITCODE"
    } finally {
        $ErrorActionPreference = $previousEap
        Pop-Location
    }

    # Import once so GUT's class_names resolve and scripts/check.ps1 passes on the
    # first run. Without this the first headless GUT run fails with "Some GUT
    # class_names have not been imported".
    $console = [Environment]::GetEnvironmentVariable('GODOT', 'User')
    if ($console -and (Test-Path $console)) {
        Write-Host '  Preparing engine cache (first run only, this takes ~30s)...' -ForegroundColor Cyan
        $previousEap2 = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $console --headless --import --path $dest | Out-Null
            Write-Log "import exit $LASTEXITCODE"
        } finally {
            $ErrorActionPreference = $previousEap2
        }
    }

    # Register with the Project Manager so the game shows up in its list.
    $registrar = Join-Path $PSScriptRoot 'add-to-project-manager.ps1'
    if (Test-Path $registrar) {
        try { & $registrar -Path $dest } catch { Write-Log "register failed: $($_.Exception.Message)" }
    }

    Write-Host ''
    Write-Host "  Created: $dest" -ForegroundColor Green
    Write-Host '  Includes: Godot AI, GUT, 59 skills, AGENTS.md, scripts/check.ps1'
    Write-Host ''
} catch {
    Stop-WithError $_.Exception.Message
}

if ($NoLaunch) {
    Write-Host '  -NoLaunch set: skipping Godot and OpenCode.' -ForegroundColor DarkGray
    exit 0
}

Write-Host '  Opening Godot and OpenCode...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'launch-godot.ps1') -ProjectPath $dest
