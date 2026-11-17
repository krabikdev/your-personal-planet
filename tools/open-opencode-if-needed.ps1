#Requires -Version 5.1
<#
.SYNOPSIS
    Open an OpenCode session for a project, but only once.

.DESCRIPTION
    Used by the opencode_link editor plugin (and as a fallback by the launcher).
    It never spawns a duplicate: if an opencode-cli process is already attached to
    the same folder, it exits quietly.

    With -WaitForGodotAi it first waits (up to 120 s) for the Godot AI MCP port to
    listen, so the new session connects to the editor on the first try.

    Runs hidden; the visible console is created by open-opencode.ps1.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [switch]$WaitForGodotAi
)

$ErrorActionPreference = 'Stop'

$logFile = Join-Path $env:TEMP 'godot-launcher.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] open-if-needed: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

function Test-AlreadyOpen {
    param([string]$Target)
    $pattern = [regex]::Escape($Target) + '(\s|$|")'
    $procs = Get-CimInstance Win32_Process -Filter "Name='opencode-cli.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and $p.CommandLine -match $pattern) { return $true }
    }
    return $false
}

try {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

    if (-not (Test-Path -LiteralPath $Path)) { Write-Log "missing path: $Path"; exit 1 }
    $Path = (Resolve-Path -LiteralPath $Path).Path
    $Path = $Path.TrimEnd('\')

    if (Test-AlreadyOpen -Target $Path) {
        Write-Log "already open: $Path"
        exit 0
    }

    # The editor plugin and the process watcher can both ask for the same project
    # within a second of each other. A short-lived lock stops two TUI windows.
    $safe = ($Path -replace '[^A-Za-z0-9]', '_')
    $lockFile = Join-Path $env:TEMP ('opencode-open-' + $safe + '.lock')
    if (Test-Path -LiteralPath $lockFile) {
        $age = (Get-Date) - (Get-Item -LiteralPath $lockFile).LastWriteTime
        if ($age.TotalSeconds -lt 90) {
            Write-Log "recently opened: $Path"
            exit 0
        }
    }
    try { Set-Content -LiteralPath $lockFile -Value (Get-Date -Format o) -ErrorAction SilentlyContinue } catch { }

    if ($WaitForGodotAi) {
        $deadline = (Get-Date).AddSeconds(120)
        while ((Get-Date) -lt $deadline) {
            $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                Where-Object { $_.LocalPort -eq 8000 }
            if ($listening) { break }
            Start-Sleep -Milliseconds 750
        }
        Write-Log 'godot ai port checked'
    }

    # Re-check after waiting: another instance may have opened it meanwhile.
    if (Test-AlreadyOpen -Target $Path) {
        Write-Log "already open after wait: $Path"
        exit 0
    }

    $script = Join-Path $PSScriptRoot 'open-opencode.ps1'
    Write-Log "opening: $Path"
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$script`"",
        '-Path', "`"$Path`""
    )
    exit 0
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
