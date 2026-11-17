#!/usr/bin/env bash
# Project check pipeline: format, lint, headless load, GUT tests.
# The Linux/macOS twin of scripts/check.ps1. Run it after every change.
#
# Requires: GODOT (or `godot` on PATH), gdformat and gdlint (gdtoolkit).
#   uv tool install gdtoolkit   # or: pipx install gdtoolkit
#
# Usage:
#   ./scripts/check.sh

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
project_root=$(pwd)

godot=${GODOT:-godot}
if ! command -v "$godot" >/dev/null 2>&1 && [ ! -x "$godot" ]; then
    echo "GODOT is not set or points to a missing binary." >&2
    echo "Set it with: export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64" >&2
    exit 1
fi

for tool in gdformat gdlint; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "$tool not found. Install with: uv tool install gdtoolkit" >&2
        exit 1
    }
done

stages=()
verdicts=()
details=()
add_result() {
    stages+=("$1")
    verdicts+=("$2")
    details+=("$3")
}
header() { printf '\n=== %s ===\n' "$1"; }

gd_files=()
while IFS= read -r file; do
    gd_files+=("$file")
done < <(find scripts ui tests scenes -type f -name '*.gd' -not -path '*/addons/*' 2>/dev/null | sort)

# ------------------------------------------------------------------- 1. format
header "1/4 gdformat --check"
if [ "${#gd_files[@]}" -eq 0 ]; then
    echo "(no GDScript files to format yet)"
    add_result gdformat PASS "no files"
elif gdformat --check "${gd_files[@]}"; then
    echo "Formatting OK (${#gd_files[@]} files)"
    add_result gdformat PASS "${#gd_files[@]} files"
else
    echo "Formatting violations found. Fix with: gdformat scripts ui tests scenes" >&2
    add_result gdformat FAIL "needs formatting"
fi

# --------------------------------------------------------------------- 2. lint
header "2/4 gdlint"
if [ "${#gd_files[@]}" -eq 0 ]; then
    echo "(no GDScript files to lint yet)"
    add_result gdlint PASS "no files"
elif gdlint "${gd_files[@]}"; then
    echo "Lint OK"
    add_result gdlint PASS "clean"
else
    add_result gdlint FAIL "violations"
fi

# ------------------------------------------------------------- 3. project load
header "3/4 headless project load"
load_output=$("$godot" --headless --path "$project_root" --quit 2>&1)
load_exit=$?
load_errors=$(printf '%s\n' "$load_output" | grep -E 'ERROR|SCRIPT ERROR' || true)

if [ "$load_exit" -ne 0 ]; then
    printf '%s\n' "$load_output"
    echo "Project load exited with code $load_exit" >&2
    add_result project-load FAIL "exit $load_exit"
elif [ -n "$load_errors" ]; then
    echo "Errors reported during load:" >&2
    printf '%s\n' "$load_errors" | sed 's/^/  /' >&2
    add_result project-load FAIL "$(printf '%s\n' "$load_errors" | wc -l | tr -d ' ') error lines"
else
    echo "Project loads cleanly"
    add_result project-load PASS "clean"
fi

# -------------------------------------------------------------------- 4. tests
header "4/4 GUT tests (headless)"
gut_output=$("$godot" --headless --path "$project_root" \
    -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit -glog=1 2>&1)
gut_exit=$?

# GUT wraps its summary in ANSI colour codes; strip them before parsing.
gut_clean=$(printf '%s\n' "$gut_output" | sed -E 's/\x1B\[[0-9;]*m//g')
tests=$(printf '%s\n' "$gut_clean" | sed -nE 's/^Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
passing=$(printf '%s\n' "$gut_clean" | sed -nE 's/.*Passing Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
failing=$(printf '%s\n' "$gut_clean" | sed -nE 's/.*Failing Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
tests=${tests:-0}
passing=${passing:-0}
failing=${failing:-0}

if [ "$gut_exit" -ne 0 ] || [ "$failing" -gt 0 ] || [ "$tests" -eq 0 ]; then
    printf '%s\n' "$gut_output"
    echo "GUT: tests=$tests passing=$passing failing=$failing exit=$gut_exit" >&2
    [ "$tests" -eq 0 ] && echo "No tests were collected from res://tests." >&2
    add_result gut FAIL "tests=$tests failing=$failing exit=$gut_exit"
else
    echo "GUT: tests=$tests passing=$passing failing=$failing"
    add_result gut PASS "tests=$tests passing=$passing"
fi

# ------------------------------------------------------------------- summary
printf '\n================ SUMMARY ================\n'
failed=0
for i in "${!stages[@]}"; do
    printf '  %-14s %-5s %s\n' "${stages[$i]}" "${verdicts[$i]}" "${details[$i]}"
    [ "${verdicts[$i]}" = PASS ] || failed=$((failed + 1))
done
printf '=========================================\n'

if [ "$failed" -gt 0 ]; then
    echo "$failed stage(s) failed." >&2
    exit 1
fi
echo "All stages passed."
