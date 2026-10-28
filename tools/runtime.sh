#!/usr/bin/env bash
set -euo pipefail
TASK_RUNTIME_DIR="${ASHIGARU_RUNTIME_DIR:-/workspace/.runtime}"
export XDG_DATA_HOME="$TASK_RUNTIME_DIR/data"
export XDG_CONFIG_HOME="$TASK_RUNTIME_DIR/config"
export XDG_CACHE_HOME="$TASK_RUNTIME_DIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
