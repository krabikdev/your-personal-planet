#Requires -Version 5.1
<#
.SYNOPSIS
    Save the current work, verify it, open a pull request and merge it into master.

.DESCRIPTION
    This is how every change reaches the project. It is safe to run while your
    teammate's agent is working at the same time:

      1. creates a separate branch if you are on master
      2. runs scripts\check.ps1 (unless -SkipCheck)
      3. commits everything in the folder
      4. replays the commit on top of GitHub's latest master
      5. pushes the branch and opens a pull request
      6. squash-merges the pull request and brings master back down

    If two agents changed the same lines, step 4 stops with a conflict and
    explains exactly what to do. Nothing is lost and nothing is force-pushed
    over someone else's work.

.PARAMETER Message
    Imperative commit/PR title, e.g. "fix: stop the boy sliding on slopes".

.PARAMETER SkipCheck
    Skip the local checks. Use only when you already ran them.

.PARAMETER NoMerge
    Push and open the pull request, but leave it open for review.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\agent-ship.ps1 -Message "feat: add snow footprints"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Message,
    [switch]$SkipCheck,
    [switch]$NoMerge
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

function Get-GhPath {
    $command = Get-Command gh -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $known = 'C:\Program Files\GitHub CLI\gh.exe'
    if (Test-Path $known) { return $known }
    Stop-With "GitHub CLI is missing. Install it with: winget install --id GitHub.cli --exact"
}

function Test-Conflict {
    if ($LASTEXITCODE -eq 0) { return }
    Write-Host "CONFLICT: the same code was changed on both machines." -ForegroundColor Yellow
    Write-Host "Files that need a decision:"
    git diff --name-only --diff-filter=U | ForEach-Object { Write-Host "   $_" }
    Write-Host ""
    Write-Host "Do this, then run the same command again:" -ForegroundColor Yellow
    Write-Host "  1. Open each file and keep both intentions (search for <<<<<<<)."
    Write-Host "  2. git add <file>"
    Write-Host "  3. git rebase --continue"
    Write-Host ""
    Write-Host "To give up and go back to where you started: git rebase --abort"
    exit 2
}

$gh = Get-GhPath

git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Stop-With "This folder is not a Git repository."
}

if (-not (git config user.email)) {
    Stop-With "Git does not know who you are yet. Run scripts\setup-git.ps1 once."
}

$changes = git status --porcelain
if (-not $changes) {
    Write-Host "Nothing to ship - this folder already matches the last commit." -ForegroundColor Green
    exit 0
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq 'master') {
    $slug = ($Message.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) { $slug = 'change' }
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).Trim('-') }
    $branch = "agent/$slug"
    git switch -c $branch
    if ($LASTEXITCODE -ne 0) {
        Stop-With "Could not create the working branch '$branch'."
    }
    Write-Host "Working on a separate branch: $branch (master stays protected)." -ForegroundColor Gray
}

if (-not $SkipCheck) {
    Write-Step "Checking the project before shipping..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check.ps1')
    if ($LASTEXITCODE -ne 0) {
        Stop-With "The checks failed. Fix the problems above, then run this command again."
    }
}

Write-Step "Saving the work..."
git add -A
git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Stop-With "Nothing was saved. The folder may already match the last commit."
}

Write-Step "Including your teammate's latest work..."
git fetch origin --prune
git rebase origin/master
Test-Conflict

Write-Step "Uploading to GitHub..."
git push -u origin HEAD
if ($LASTEXITCODE -ne 0) {
    Stop-With "Upload failed. Check the internet connection and 'gh auth status'."
}

Write-Step "Opening a pull request..."
$checkLine = if ($SkipCheck) { 'skipped' } else { 'scripts/check.ps1 passed' }
$body = @"
Shipped by an AI agent from ``$env:COMPUTERNAME``.

- Local checks: $checkLine
- Rebased on the latest ``master`` before merging.

Rules: docs/WORKFLOW.md
"@
$prUrl = (& $gh pr create --base master --head $branch --title $Message --body $body).Trim()
if ($LASTEXITCODE -ne 0) {
    $existing = (& $gh pr list --head $branch --state open --json url --jq '.[0].url' 2>$null)
    if ($existing) {
        $prUrl = $existing.Trim()
    } else {
        Stop-With "Could not open a pull request."
    }
}
Write-Host "Pull request: $prUrl"

if ($NoMerge) {
    Write-Host "Left the pull request open for review (-NoMerge)." -ForegroundColor Green
    exit 0
}

Write-Step "Merging into master..."
$merged = $false
foreach ($attempt in 1..2) {
    & $gh pr merge $prUrl --squash --delete-branch
    if ($LASTEXITCODE -eq 0) {
        $merged = $true
        break
    }
    if ($attempt -eq 1) {
        Write-Host "master moved while we were working. Updating and retrying..." -ForegroundColor Yellow
        git fetch origin --prune
        git rebase origin/master
        Test-Conflict
        git push --force-with-lease origin HEAD
        if ($LASTEXITCODE -ne 0) {
            Stop-With "Could not update the pull request branch."
        }
    }
}

if (-not $merged) {
    Stop-With "GitHub could not merge the pull request. Open $prUrl and read the message there."
}

git switch master
if ($LASTEXITCODE -ne 0) {
    Stop-With "Merged, but could not switch back to master. Ask your agent to fix it."
}
git pull --ff-only
if (git branch --list $branch) {
    git branch -D $branch | Out-Null
}

Write-Step "Done."
Write-Host $Message -ForegroundColor Green
Write-Host "This folder and GitHub now match." -ForegroundColor Gray
