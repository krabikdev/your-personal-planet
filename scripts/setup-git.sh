#!/usr/bin/env bash
# One-time Git setup for this project. Run once after cloning, on every machine.
#
# Two people and two AI agents share this repository, so Git is configured to:
#   pull.rebase          pulling = download + replay your work on top
#   rebase.autoStash     uncommitted edits are parked during a pull, not lost
#   rerere.enabled       Git remembers how a conflict was resolved once
#   merge.conflictStyle  conflict markers also show the original text
#   fetch.prune          deleted remote branches disappear from your list
#   push.autoSetupRemote the first push of a new branch just works
#   core.autocrlf        off; .gitattributes decides line endings
#
# Usage:
#   ./scripts/setup-git.sh
#   ./scripts/setup-git.sh "Your Name" "you@example.com"

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -d .git ]; then
    echo "This folder is not a Git repository. Clone the project again from GitHub." >&2
    exit 1
fi

settings=(
    "pull.rebase true"
    "rebase.autoStash true"
    "rerere.enabled true"
    "rerere.autoupdate true"
    "merge.conflictStyle zdiff3"
    "fetch.prune true"
    "push.autoSetupRemote true"
    "core.autocrlf false"
)
for setting in "${settings[@]}"; do
    key=${setting%% *}
    value=${setting#* }
    git config --local "$key" "$value"
    printf '  %-24s %s\n' "$key" "$value"
done

name=${1:-}
email=${2:-}
if [ -n "$name" ] && [ -n "$email" ]; then
    git config --local user.name "$name"
    git config --local user.email "$email"
    echo "Identity set to $name <$email>"
elif [ -z "$(git config user.email 2>/dev/null || true)" ] || [[ "$(git config user.email)" == *localhost* ]]; then
    if command -v gh >/dev/null 2>&1; then
        login=$(gh api user --jq '.login' 2>/dev/null || true)
        id=$(gh api user --jq '.id' 2>/dev/null || true)
        if [ -n "$login" ] && [ -n "$id" ]; then
            git config --local user.name "$login"
            git config --local user.email "${id}+${login}@users.noreply.github.com"
            echo "Identity set to $login (from GitHub CLI)"
        fi
    fi
    if [ -z "$(git config user.email 2>/dev/null || true)" ]; then
        echo
        echo "Git does not know who you are yet. Run this again with:"
        echo '  ./scripts/setup-git.sh "Your Name" "you@example.com"'
    fi
fi

echo
echo "Git is ready for team work."
echo "Next: read docs/WORKFLOW.md. Short version: run ./scripts/sync.sh before you start."
