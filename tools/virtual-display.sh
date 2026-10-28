#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/runtime.sh
if DISPLAY=:9 xdpyinfo >/dev/null 2>&1; then
  echo 'Display :9 is already available.'
  exit 0
fi
nohup Xorg :9 -config "$PWD/tools/xorg.conf" -logfile "$TASK_RUNTIME_DIR/xorg.log" -noreset -nolisten tcp -ac > "$TASK_RUNTIME_DIR/xorg-output.log" 2>&1 &
echo "$!" > "$TASK_RUNTIME_DIR/xorg.pid"
for attempt in {1..30}; do
  if DISPLAY=:9 xdpyinfo >/dev/null 2>&1; then
    echo 'Display :9 ready. Use DISPLAY=:9 ./tools/test.sh or DISPLAY=:9 godot --path .'
    exit 0
  fi
  sleep 0.1
done
cat "$TASK_RUNTIME_DIR/xorg-output.log"
exit 1
