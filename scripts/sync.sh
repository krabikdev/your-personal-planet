#!/usr/bin/env bash
# Download the newest work from GitHub into this folder.
#
# Usage:
#   ./scripts/sync.sh          # just catch up
#   ./scripts/sync.sh --check  # catch up, then run the project checks
#
# It never invents merges: your copy simply catches up with GitHub.
# If it finds unsaved work or a conflict, it stops and explains what to do.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

run_check=0
for arg in "$@"; do
    case "$arg" in
        --check) run_check=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

step() { printf '\n%s\n' "$1"; }
fail() { printf '\n%s\n' "$1" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || fail "This folder is not a Git repository. Clone the project again from GitHub."

branch=$(git rev-parse --abbrev-ref HEAD)

step "Downloading the latest changes from GitHub..."
git fetch --prune origin || fail "Could not reach GitHub. Check your internet connection, then try again."

dirty=$(git status --porcelain)
if [ -n "$dirty" ]; then
    echo "Unsaved work is sitting in this folder:"
    printf '%s\n' "$dirty" | sed 's/^/   /'
    fail "Ask your agent to ship or commit these changes first, then run sync again."
fi

if [ "$branch" = "master" ]; then
    incoming=$(git rev-list --count HEAD..origin/master)
    if [ "$incoming" -eq 0 ]; then
        echo "Already up to date. Nothing to download."
    else
        echo "Applying $incoming change(s) from your teammate..."
        git merge --ff-only origin/master || fail "This copy of master has work that GitHub does not. Ask your agent to repair it."
        git --no-pager log --oneline -n "$incoming" HEAD
        echo "Your copy is now up to date."
    fi
else
    echo "You are on branch '$branch'. Replaying it on top of the latest master..."
    if ! git rebase origin/master; then
        echo "The same lines were changed in two places." >&2
        echo "Files that need a decision:" >&2
        git diff --name-only --diff-filter=U | sed 's/^/   /' >&2
        fail "Ask your agent to resolve the conflict (docs/WORKFLOW.md, section 'When two agents collide')."
    fi
    echo "Branch '$branch' is now based on the latest master."
fi

if [ "$run_check" -eq 1 ]; then
    step "Running the project checks..."
    ./scripts/check.sh || fail "The checks failed. Ask your agent to fix the problems above."
    echo "All checks pass."
fi

step "Done."
