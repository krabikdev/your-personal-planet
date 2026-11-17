#Requires -Version 5.1
<#
.SYNOPSIS
    Open an OpenCode session for every Godot project editor that starts.

.DESCRIPTION
    The opencode_link editor plugin only exists inside projects created from this
    template. Any project opened from Godot's Project Manager - including ones
    created by Godot itself - has no plugin, so nothing would ever open OpenCode
    for it.

    This watcher is started alongside Godot by tools/launch-godot.ps1. It polls
    the process table, and whenever a Godot editor process with `--path <dir>`
    appears, it asks tools/open-opencode-if-needed.ps1 to attach a session to
    that folder. Duplicate sessions are prevented by that helper (process scan +
    a short-lived lock file), so it is safe to run next to the editor plugin.

    It exits on its own once Godot has been gone for a few minutes.
#>
param(
    [int]$PollSeconds = 2,
    [int]$IdleExitSeconds = 180
)

$ErrorActionPreference = 'Continue'

$logFile = Join-Path $env:TEMP 'godot-launcher.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] watch: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue } catch { }
}

# One watcher per user session is enough. A named mutex is used instead of
# scanning command lines, because any shell that merely mentions this script
# would otherwise look like a running watcher.
$created = $false
$mutex = [System.Threading.Mutex]::new($true, 'Local\GodotOpenCodeProjectWatcher', [ref]$created)
if (-not $created) {
    Write-Log 'watcher already running; exiting'
    exit 0
}

$openHelper = Join-Path $PSScriptRoot 'open-opencode-if-needed.ps1'
if (-not (Test-Path $openHelper)) {
    Write-Log "missing helper: $openHelper"
    exit 1
}

Write-Log 'watcher started'

# project dir -> editor pid, so closing and reopening a project re-triggers.
$seen = @{}
$idleSince = $null

while ($true) {
    $editors = @()
    try {
        $editors = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like 'Godot*' -and
                $_.CommandLine -and
                $_.CommandLine -match '--path' -and
                $_.CommandLine -notmatch '--headless'
            }
    } catch { }

    $alive = @{}
    foreach ($proc in $editors) {
        $dir = $null
        if ($proc.CommandLine -match '--path\s+"([^"]+)"') {
            $dir = $Matches[1]
        } elseif ($proc.CommandLine -match '--path\s+(\S+)') {
            $dir = $Matches[1]
        }
        if (-not $dir) { continue }

        $dir = $dir.Trim().TrimEnd('\', '/')
        if ($dir -eq '') { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $dir 'project.godot'))) { continue }

        $alive[$dir] = $true
        if ($seen.ContainsKey($dir) -and $seen[$dir] -eq $proc.ProcessId) { continue }

        $seen[$dir] = $proc.ProcessId
        Write-Log "godot editor for '$dir' (pid $($proc.ProcessId)) -> attaching"
        try {
            $args = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-WindowStyle', 'Hidden',
                '-File', "`"$openHelper`"",
                '-Path', "`"$dir`""
            )
            Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Hidden | Out-Null
        } catch {
            Write-Log "failed to attach for '$dir': $($_.Exception.Message)"
        }
    }

    # Forget projects whose editor has closed.
    foreach ($key in @($seen.Keys)) {
        if (-not $alive.ContainsKey($key)) { $seen.Remove($key) }
    }

    if ($seen.Count -eq 0) {
        if ($null -eq $idleSince) { $idleSince = Get-Date }
        elseif (((Get-Date) - $idleSince).TotalSeconds -ge $IdleExitSeconds) {
            Write-Log 'no godot editors for a while; watcher exiting'
            exit 0
        }
    } else {
        $idleSince = $null
    }

    Start-Sleep -Seconds $PollSeconds
}
