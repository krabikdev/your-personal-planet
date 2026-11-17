#Requires -Version 5.1
<#
.SYNOPSIS
    One-time Git setup for this project. Run it once after cloning, on every machine.

.DESCRIPTION
    Two people and two AI agents share this repository, so Git is configured to:

      pull.rebase           pulling = download + replay your work on top
      rebase.autoStash      uncommitted edits are parked during a pull, not lost
      rerere.enabled        Git remembers how a conflict was resolved once
      merge.conflictStyle   conflict markers also show the original text
      fetch.prune           deleted remote branches disappear from your list
      push.autoSetupRemote  the first push of a new branch just works
      core.autocrlf         off; .gitattributes decides line endings

    It also sets your name and email the first time, using your GitHub account.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-git.ps1
#>
[CmdletBinding()]
param(
    [string]$Name,
    [string]$Email
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path '.git')) {
    Write-Host "This folder is not a Git repository. Clone it again from GitHub." -ForegroundColor Red
    exit 1
}

$settings = [ordered]@{
    'pull.rebase'          = 'true'
    'rebase.autoStash'     = 'true'
    'rerere.enabled'       = 'true'
    'rerere.autoupdate'    = 'true'
    'merge.conflictStyle'  = 'zdiff3'
    'fetch.prune'          = 'true'
    'push.autoSetupRemote' = 'true'
    'core.autocrlf'        = 'false'
    'core.longpaths'       = 'true'
}

foreach ($key in $settings.Keys) {
    git config --local $key $settings[$key]
    Write-Host ("  {0,-24} {1}" -f $key, $settings[$key]) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- identity
$currentName = (git config user.name)
$currentEmail = (git config user.email)
$placeholder = $false
if ($currentEmail) {
    if ($currentEmail -like '*@users.noreply.github.com') {
        $placeholder = $false
    } elseif ($currentEmail -like '*localhost*' -or $currentEmail -like '*example.com*') {
        $placeholder = $true
    }
}

if ($Name -and $Email) {
    git config --local user.name $Name
    git config --local user.email $Email
    Write-Host "Identity set to $Name <$Email>" -ForegroundColor Green
} elseif (-not $currentName -or -not $currentEmail -or $placeholder) {
    $ghPath = $null
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCommand) {
        $ghPath = $ghCommand.Source
    } elseif (Test-Path 'C:\Program Files\GitHub CLI\gh.exe') {
        $ghPath = 'C:\Program Files\GitHub CLI\gh.exe'
    }
    if ($ghPath) {
        $login = (& $ghPath api user --jq '.login' 2>$null)
        $id = (& $ghPath api user --jq '.id' 2>$null)
        if ($login -and $id) {
            git config --local user.name $login.Trim()
            git config --local user.email "$($id.Trim())+$($login.Trim())@users.noreply.github.com"
            Write-Host "Identity set to $($login.Trim()) (from GitHub CLI)" -ForegroundColor Green
        }
    }
    if (-not (git config user.email)) {
        Write-Host ""
        Write-Host "Git does not know who you are yet. Run this again with:" -ForegroundColor Yellow
        Write-Host '  scripts\setup-git.ps1 -Name "Your Name" -Email "you@example.com"'
    }
}

Write-Host ""
Write-Host "Git is ready for team work." -ForegroundColor Green
Write-Host "Board access needs the project scope: gh auth refresh -s project" -ForegroundColor Gray
Write-Host "Next: read docs\WORKFLOW.md. Short version: run scripts\sync.ps1 before you start." -ForegroundColor Gray
