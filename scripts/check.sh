#!/usr/bin/env bash
# Project check pipeline: format, lint, project load, headless tests.
#
# Usage:
#   ./scripts/check.sh                 # everything: use before shipping
#   ./scripts/check.sh --quick         # format and lint only, a couple of seconds
#   ./scripts/check.sh --test rope     # format, lint and the matching test files
#   ./scripts/check.sh --no-tests      # format, lint and the headless project load
#   ./scripts/check.sh --no-load       # everything except the headless load
#
# In the middle of a change run --quick, or --test with the area you touched.
# Save the full run for shipping, for anything that touches scenes, project
# settings or this pipeline.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
project_root=$(pwd)

run_load=1
run_tests=1
test_filters=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --quick)
            run_load=0
            run_tests=0
            ;;
        --no-tests) run_tests=0 ;;
        --no-load) run_load=0 ;;
        --test)
            shift
            if [ "$#" -eq 0 ]; then
                echo "--test needs a name, for example: --test rope" >&2
                exit 2
            fi
            test_filters+=("$1")
            run_load=0
            ;;
        -h | --help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (try --help)" >&2
            exit 2
            ;;
    esac
    shift
done

if [ "$run_load" -eq 1 ] || [ "$run_tests" -eq 1 ]; then
    godot=${GODOT:-godot}
    if ! command -v "$godot" >/dev/null 2>&1 && [ ! -x "$godot" ]; then
        echo "GODOT is not set or points to a missing binary." >&2
        echo "Set it with: export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64" >&2
        exit 1
    fi
fi

for tool in gdformat gdlint; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "$tool not found. Install with: uv tool install gdtoolkit" >&2
        exit 1
    }
done

stage_names=()
verdicts=()
details=()
durations=()
add_result() {
    stage_names+=("$1")
    verdicts+=("$2")
    details+=("$3")
    durations+=("$4")
}

stage_total=2
[ "$run_load" -eq 1 ] && stage_total=$((stage_total + 1))
[ "$run_tests" -eq 1 ] && stage_total=$((stage_total + 1))
stage_index=0

header() {
    stage_index=$((stage_index + 1))
    printf '\n=== %s/%s %s ===\n' "$stage_index" "$stage_total" "$1"
}

now_ms() { date +%s%N; }

duration_text() {
    local ms=$1
    if [ "$ms" -lt 1000 ]; then
        printf '%dms' "$ms"
    else
        printf '%d.%01ds' "$((ms / 1000))" "$((ms % 1000 / 100))"
    fi
}

elapsed() {
    duration_text "$((($(now_ms) - $1) / 1000000))"
}

gd_files=()
while IFS= read -r file; do
    gd_files+=("$file")
done < <(find scripts ui tests scenes -type f -name '*.gd' -not -path '*/addons/*' 2>/dev/null | sort)

# ------------------------------------------------------- 1+2. format and lint
# Both only read the files and Python startup dominates the cost, so they run
# side by side and the summary still reports each on its own.
format_log=$(mktemp)
lint_log=$(mktemp)
format_exit=0
lint_exit=0
format_ms=0
lint_ms=0

if [ "${#gd_files[@]}" -eq 0 ]; then
    printf '(no GDScript files yet)\n' >"$format_log"
    printf '(no GDScript files yet)\n' >"$lint_log"
else
    started=$(now_ms)
    gdformat --check "${gd_files[@]}" >"$format_log" 2>&1 &
    format_pid=$!
    gdlint "${gd_files[@]}" >"$lint_log" 2>&1 &
    lint_pid=$!
    wait "$format_pid"
    format_exit=$?
    format_ms=$(($(now_ms) - started))
    wait "$lint_pid"
    lint_exit=$?
    lint_ms=$(($(now_ms) - started))
    format_ms=$((format_ms / 1000000))
    lint_ms=$((lint_ms / 1000000))
fi

header "gdformat --check"
if [ "${#gd_files[@]}" -eq 0 ]; then
    cat "$format_log"
    add_result gdformat PASS "no files" "$(duration_text "$format_ms")"
elif [ "$format_exit" -eq 0 ]; then
    echo "Formatting OK (${#gd_files[@]} files)"
    add_result gdformat PASS "${#gd_files[@]} files" "$(duration_text "$format_ms")"
else
    cat "$format_log"
    echo "Formatting violations found. Fix with: gdformat scripts ui tests scenes" >&2
    add_result gdformat FAIL "needs formatting" "$(duration_text "$format_ms")"
fi

header "gdlint"
if [ "${#gd_files[@]}" -eq 0 ]; then
    cat "$lint_log"
    add_result gdlint PASS "no files" "$(duration_text "$lint_ms")"
elif [ "$lint_exit" -eq 0 ]; then
    echo "Lint OK"
    add_result gdlint PASS "clean" "$(duration_text "$lint_ms")"
else
    cat "$lint_log"
    add_result gdlint FAIL "violations" "$(duration_text "$lint_ms")"
fi

rm -f "$format_log" "$lint_log"

# ------------------------------------------------------------- 3. project load
if [ "$run_load" -eq 1 ]; then
    header "headless project load"
    started=$(now_ms)
    load_output=$("$godot" --headless --path "$project_root" --quit 2>&1)
    load_exit=$?
    load_errors=$(printf '%s\n' "$load_output" | grep -E 'ERROR|SCRIPT ERROR' || true)

    if [ "$load_exit" -ne 0 ]; then
        printf '%s\n' "$load_output"
        echo "Project load exited with code $load_exit" >&2
        add_result project-load FAIL "exit $load_exit" "$(elapsed "$started")"
    elif [ -n "$load_errors" ]; then
        echo "Errors reported during load:" >&2
        printf '%s\n' "$load_errors" | sed 's/^/  /' >&2
        add_result project-load FAIL "$(printf '%s\n' "$load_errors" | wc -l | tr -d ' ') error lines" "$(elapsed "$started")"
    else
        echo "Project loads cleanly"
        add_result project-load PASS "clean" "$(elapsed "$started")"
    fi
fi

# -------------------------------------------------------------------- 4. tests
if [ "$run_tests" -eq 1 ]; then
    header "GUT tests (headless)"
    started=$(now_ms)
    gut_targets=()
    if [ "${#test_filters[@]}" -eq 0 ]; then
        gut_targets=(-gdir=res://tests -ginclude_subdirs)
    else
        match_files=()
        for filter in "${test_filters[@]}"; do
            if [ -f "$filter" ]; then
                match_files+=("$filter")
                continue
            fi
            while IFS= read -r match; do
                match_files+=("$match")
            done < <(find tests -type f -name "*${filter}*.gd" | sort)
        done
        if [ "${#match_files[@]}" -eq 0 ]; then
            echo "No test files match: ${test_filters[*]}" >&2
            exit 2
        fi
        for match in "${match_files[@]}"; do
            gut_targets+=("-gtest=res://${match#./}")
            echo "  ${match}"
        done
    fi

    gut_output=$("$godot" --headless --fixed-fps 60 --path "$project_root" \
        -s addons/gut/gut_cmdln.gd \
        "${gut_targets[@]}" -gexit -glog=1 2>&1)
    gut_exit=$?

    # GUT wraps its summary in ANSI colour codes; strip them before parsing.
    gut_clean=$(printf '%s\n' "$gut_output" | sed -E 's/\x1B\[[0-9;]*m//g')
    tests=$(printf '%s\n' "$gut_clean" | sed -nE 's/^Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
    passing=$(printf '%s\n' "$gut_clean" | sed -nE 's/.*Passing Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
    failing=$(printf '%s\n' "$gut_clean" | sed -nE 's/.*Failing Tests[[:space:]]+([0-9]+).*/\1/p' | head -n 1)
    tests=${tests:-0}
    passing=${passing:-0}
    failing=${failing:-0}
    # GUT quietly skips a test script it cannot parse, which would shrink the
    # suite without failing it. Treat that as a failure of its own.
    unloaded=$(printf '%s\n' "$gut_clean" | grep -A1 -E 'Ignoring script|Failed to load script' | head -n 6)

    if [ "$gut_exit" -ne 0 ] || [ "$failing" -gt 0 ] || [ "$tests" -eq 0 ] || [ -n "$unloaded" ]; then
        printf '%s\n' "$gut_output"
        if [ -n "$unloaded" ]; then
            echo "A test script could not be loaded, so the suite is smaller than it claims:" >&2
            printf '%s\n' "$unloaded" | sed 's/^/  /' >&2
        fi
        echo "GUT: tests=$tests passing=$passing failing=$failing exit=$gut_exit" >&2
        [ "$tests" -eq 0 ] && echo "No tests were collected from res://tests." >&2
        add_result gut FAIL "tests=$tests failing=$failing exit=$gut_exit" "$(elapsed "$started")"
    else
        echo "GUT: tests=$tests passing=$passing failing=$failing"
        add_result gut PASS "tests=$tests passing=$passing" "$(elapsed "$started")"
    fi
fi

# ------------------------------------------------------------------- summary
printf '\n================ SUMMARY ================\n'
failed=0
for index in "${!stage_names[@]}"; do
    printf '  %-14s %-5s %-22s %s\n' \
        "${stage_names[$index]}" "${verdicts[$index]}" "${details[$index]}" "${durations[$index]}"
    [ "${verdicts[$index]}" = PASS ] || failed=$((failed + 1))
done
printf '=========================================\n'

if [ "$failed" -gt 0 ]; then
    echo "$failed stage(s) failed." >&2
    exit 1
fi
echo "All stages passed."
