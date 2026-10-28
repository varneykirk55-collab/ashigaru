#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/runtime.sh
if [[ -n "${DISPLAY:-}" ]]; then
  godot --path . --audio-driver Dummy --fixed-fps 60 --disable-render-loop --script tests/integration.gd
else
  godot --headless --path . --fixed-fps 60 --script tests/integration.gd
fi
