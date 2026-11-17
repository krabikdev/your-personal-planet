#Requires -Version 5.1
<#
.SYNOPSIS
    Launch the Godot 4 editor, and optionally an OpenCode session for the project.

.DESCRIPTION
    Windows shortcuts started from the desktop inherit the Explorer environment,
    which can be stale (uv, node and other tools installed after logon are missing
    from PATH). The Godot AI plugin resolves `uvx` from PATH, so a stale PATH makes
    its MCP server fail with "no server found".

    This launcher rebuilds PATH from the registry before starting Godot, so the
    editor always finds uvx and Godot AI connects.

    When a project is given, it also opens an OpenCode session rooted at that
    project, after waiting (briefly) for the Godot AI server port so the MCP
    connection succeeds on the first try.

    With no -ProjectPath it opens the Project Manager (where you create/open projects).

.EXAMPLE
    .\launch-godot.ps1
    .\launch-godot.ps1 -ProjectPath C:\Godot
    .\launch-godot.ps1 -ProjectPath C:\Godot -NoOpenCode
#>
param(
    [string]$ProjectPath = "",
    [switch]$NoOpenCode,
    [switch]$PrintOnly
)

$ErrorActionPreference = 'Stop'

$logFile = Join-Path $env:TEMP 'godot-launcher.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

function Show-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    Write-Log "ERROR: $Message"
    Write-Log "See $logFile"
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show(
            "$Message`n`nDetails: $logFile",
            'Godot launcher',
            'OK',
            'Error'
        ) | Out-Null
    } catch {
        # No GUI available; the console message is enough.
    }
}

try {
    Write-Log '--- launcher start ---'

    # Rebuild PATH from the registry (Machine first, then User).
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

    # Resolve the console exe from the persistent GODOT variable, then derive the GUI exe.
    $console = $env:GODOT
    if ([string]::IsNullOrWhiteSpace($console)) {
        $console = [Environment]::GetEnvironmentVariable('GODOT', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($console) -or -not (Test-Path $console)) {
        Show-Error "Godot console executable not found.`n`nSet the GODOT user environment variable to the *_console.exe path."
        exit 1
    }

    $editorExe = $console -replace '_console\.exe$', '.exe'
    if (-not (Test-Path $editorExe)) {
        $editorExe = $console
    }
    Write-Log "editor: $editorExe"

    $openCodeScript = Join-Path $PSScriptRoot 'open-opencode.ps1'

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $godotArgs = @()
        $label = 'Project Manager'
        $workDir = Split-Path -Parent $editorExe
    } else {
        $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
        if (-not (Test-Path (Join-Path $ProjectPath 'project.godot'))) {
            Show-Error "No project.godot found in:`n$ProjectPath"
            exit 1
        }
        $godotArgs = @('--editor', '--path', $ProjectPath)
        $label = $ProjectPath
        $workDir = $ProjectPath
    }
    Write-Log "target: $label"

    if ($PrintOnly) {
        Write-Output "editor   : $editorExe"
        Write-Output "target   : $label"
        Write-Output "arguments: $($godotArgs -join ' ')"
        Write-Output "uvx      : $((Get-Command uvx -ErrorAction SilentlyContinue).Source)"
        Write-Output "opencode : $(if ($ProjectPath -and -not $NoOpenCode) { $openCodeScript } else { '(not launched)' })"
        exit 0
    }

    # Keep the Project Manager list in sync when a project is opened by path:
    # `godot --editor --path` does not register it by itself.
    if ($ProjectPath) {
        $registrar = Join-Path $PSScriptRoot 'add-to-project-manager.ps1'
        if (Test-Path $registrar) {
            try { & $registrar -Path $ProjectPath } catch { Write-Log "register failed: $($_.Exception.Message)" }
        }
    }

    # Start-Process joins -ArgumentList elements with spaces and does NOT quote
    # them, so a project path containing spaces would be truncated. Build one
    # explicitly quoted argument string instead.
    if ($ProjectPath) {
        $argLine = '--editor --path "{0}"' -f $ProjectPath
        Start-Process -FilePath $editorExe -ArgumentList $argLine -WorkingDirectory $workDir
    } else {
        Start-Process -FilePath $editorExe -WorkingDirectory $workDir
    }
    Write-Log 'godot started'

    # Catch-all: works for the Project Manager, where the project is chosen after
    # Godot starts and may not contain the opencode_link plugin at all.
    $watcher = Join-Path $PSScriptRoot 'watch-godot-projects.ps1'
    if ((Test-Path $watcher) -and -not $NoOpenCode) {
        try {
            Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-WindowStyle', 'Hidden',
                '-File', "`"$watcher`""
            )
            Write-Log 'project watcher started'
        } catch {
            Write-Log "watcher failed: $($_.Exception.Message)"
        }
    }

    if (-not $ProjectPath -or $NoOpenCode) {
        Write-Log 'opencode skipped'
        exit 0
    }

    # If the project ships the opencode_link plugin, the editor opens OpenCode
    # itself, so don't spawn a second session here.
    $linkPlugin = Join-Path $ProjectPath 'addons\opencode_link\plugin.cfg'
    if (Test-Path $linkPlugin) {
        Write-Host '  OpenCode will open automatically once the editor is ready.'
        Write-Log 'delegating opencode to opencode_link plugin'
        exit 0
    }

    Write-Host '  Starting Godot...'
    Write-Host '  Waiting for the Godot AI server (first launch can take a minute)...'
    Write-Log 'waiting for mcp port 8000'

    $deadline = (Get-Date).AddSeconds(120)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -eq 8000 }
        if ($listening) { $ready = $true; break }
        Start-Sleep -Milliseconds 750
    }
    Write-Log "mcp ready: $ready"

    Write-Host '  Opening OpenCode...'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$openCodeScript`"",
        '-Path', "`"$ProjectPath`""
    )
    Write-Log 'opencode started'
    exit 0
} catch {
    Show-Error $_.Exception.Message
    exit 1
}
