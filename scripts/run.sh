#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

runner=()
if [ "${PLANET_GPU:-auto}" != "0" ]; then
    if command -v prime-run >/dev/null 2>&1 && [ -e /dev/nvidia0 ]; then
        runner=(prime-run)
    fi
fi

if [ "${#runner[@]}" -gt 0 ]; then
    echo "Launching on the discrete GPU (${runner[*]})."
fi

exec "${runner[@]}" "${GODOT:-godot}" --path . "$@"
