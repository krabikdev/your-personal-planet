#Requires -Version 5.1
<#
.SYNOPSIS
    Download the newest work from GitHub into this folder.

.DESCRIPTION
    Use this before you start, and any time you want the latest version:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync.ps1

    It never invents merges: your copy simply catches up with GitHub.
    If it finds unsaved work or a conflict, it stops and explains what to do.

.PARAMETER Check
    Also run the project checks (format, lint, load, tests) afterwards.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function Stop-With([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Red
    exit 1
}

git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Stop-With "This folder is not a Git repository. Clone the project again from GitHub."
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Step "Downloading the latest changes from GitHub..."
git fetch --prune origin
if ($LASTEXITCODE -ne 0) {
    Stop-With "Could not reach GitHub. Check your internet connection, then try again."
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Host "Unsaved work is sitting in this folder:" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "   $_" }
    Stop-With "Ask your agent to ship or commit these changes first, then run sync again."
}

if ($branch -eq 'master') {
    $incoming = (git rev-list --count HEAD..origin/master).Trim()
    if ([int]$incoming -eq 0) {
        Write-Host "Already up to date. Nothing to download." -ForegroundColor Green
    } else {
        Write-Host "Applying $incoming change(s) from your teammate..."
        git merge --ff-only origin/master
        if ($LASTEXITCODE -ne 0) {
            Stop-With "This copy of master has work that GitHub does not. Ask your agent to repair it."
        }
        git --no-pager log --oneline -n ([int]$incoming) HEAD
        Write-Host "Your copy is now up to date." -ForegroundColor Green
    }
} else {
    Write-Host "You are on branch '$branch'. Replaying it on top of the latest master..."
    git rebase origin/master
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The same lines were changed in two places." -ForegroundColor Yellow
        Write-Host "Files that need a decision:"
        git diff --name-only --diff-filter=U | ForEach-Object { Write-Host "   $_" }
        Stop-With "Ask your agent to resolve the conflict (docs\WORKFLOW.md, section 'When two agents collide')."
    }
    Write-Host "Branch '$branch' is now based on the latest master." -ForegroundColor Green
}

if ($Check) {
    Write-Step "Running the project checks..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check.ps1')
    if ($LASTEXITCODE -ne 0) {
        Stop-With "The checks failed. Ask your agent to fix the problems above."
    }
    Write-Host "All checks pass." -ForegroundColor Green
}

Write-Step "Done."
