#!/usr/bin/env bash
# Save the current work, verify it, open a pull request and merge it into master.
#
# This is how every change reaches the project. It is safe to run while the
# other person's agent is working at the same time:
#
#   1. creates a separate branch if you are on master
#   2. runs scripts/check.sh (unless --skip-check)
#   3. commits everything in the folder
#   4. replays the commit on top of GitHub's latest master
#   5. pushes the branch and opens a pull request
#   6. squash-merges the pull request and brings master back down
#
# If two agents changed the same lines, step 4 stops with a conflict and
# explains exactly what to do. Nothing is force-pushed over someone else.
#
# Usage:
#   ./scripts/agent-ship.sh "feat: add snow footprints"
#   ./scripts/agent-ship.sh "fix: slopes" --no-merge

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

message=""
skip_check=0
no_merge=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --skip-check) skip_check=1 ;;
        --no-merge) no_merge=1 ;;
        -m|--message) shift; message=${1:-} ;;
        *)
            if [ -z "$message" ]; then message=$1; else echo "Unknown argument: $1" >&2; exit 1; fi
            ;;
    esac
    shift
done

if [ -z "$message" ]; then
    echo 'Usage: ./scripts/agent-ship.sh "feat: what you built"' >&2
    exit 1
fi

step() { printf '\n%s\n' "$1"; }
fail() { printf '\n%s\n' "$1" >&2; exit 1; }

handle_conflict() {
    echo "CONFLICT: the same code was changed on both machines." >&2
    echo "Files that need a decision:" >&2
    git diff --name-only --diff-filter=U | sed 's/^/   /' >&2
    cat >&2 <<'EOF'

Do this, then run the same command again:
  1. Open each file and keep both intentions (search for <<<<<<<).
  2. git add <file>
  3. git rebase --continue

To give up and go back to where you started: git rebase --abort
EOF
    exit 2
}

command -v gh >/dev/null 2>&1 || fail "GitHub CLI is missing. Install it: https://cli.github.com (or 'sudo apt install gh')."

git rev-parse --git-dir >/dev/null 2>&1 || fail "This folder is not a Git repository."
[ -n "$(git config user.email 2>/dev/null || true)" ] || fail "Git does not know who you are yet. Run ./scripts/setup-git.sh once."

changes=$(git status --porcelain)
if [ -z "$changes" ]; then
    echo "Nothing to ship - this folder already matches the last commit."
    exit 0
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "master" ]; then
    slug=$(printf '%s' "$message" | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
    [ -n "$slug" ] || slug=change
    branch="agent/$slug"
    git switch -c "$branch" || fail "Could not create the working branch '$branch'."
    echo "Working on a separate branch: $branch (master stays protected)."
fi

if [ "$skip_check" -eq 0 ]; then
    step "Checking the project before shipping..."
    ./scripts/check.sh || fail "The checks failed. Fix the problems above, then run this command again."
fi

step "Saving the work..."
git add -A
git commit -m "$message" || fail "Nothing was saved. The folder may already match the last commit."

step "Including your teammate's latest work..."
git fetch origin --prune
git rebase origin/master || handle_conflict

step "Uploading to GitHub..."
git push -u origin HEAD || fail "Upload failed. Check the internet connection and 'gh auth status'."

step "Opening a pull request..."
if [ "$skip_check" -eq 1 ]; then check_line="skipped"; else check_line="scripts/check.sh passed"; fi
body="Shipped by an AI agent from \`$(hostname)\`.

- Local checks: $check_line
- Rebased on the latest \`master\` before merging.

Rules: docs/WORKFLOW.md"
pr_url=$(gh pr create --base master --head "$branch" --title "$message" --body "$body" 2>/dev/null | tail -n 1)
if [ -z "$pr_url" ]; then
    pr_url=$(gh pr list --head "$branch" --state open --json url --jq '.[0].url' 2>/dev/null || true)
fi
[ -n "$pr_url" ] || fail "Could not open a pull request."
echo "Pull request: $pr_url"

if [ "$no_merge" -eq 1 ]; then
    echo "Left the pull request open for review (--no-merge)."
    exit 0
fi

step "Merging into master..."
merged=0
for attempt in 1 2; do
    if gh pr merge "$pr_url" --squash --delete-branch; then
        merged=1
        break
    fi
    if [ "$attempt" -eq 1 ]; then
        echo "master moved while we were working. Updating and retrying..."
        git fetch origin --prune
        git rebase origin/master || handle_conflict
        git push --force-with-lease origin HEAD || fail "Could not update the pull request branch."
    fi
done
[ "$merged" -eq 1 ] || fail "GitHub could not merge the pull request. Open $pr_url and read the message there."

git switch master || fail "Merged, but could not switch back to master. Ask your agent to fix it."
git pull --ff-only
git branch -D "$branch" >/dev/null 2>&1 || true

step "Done."
echo "$message"
echo "This folder and GitHub now match."
