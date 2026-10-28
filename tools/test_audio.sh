#!/usr/bin/env bash
# Runtime audio validation (real game, real weapons/bots/menus). Takes ~4-5 minutes: it runs in real time
# because the audio mixer follows the wall clock, so voice lifetimes are only meaningful at 1x speed.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/runtime.sh
godot --headless --path . --audio-driver Dummy --script tests/audio.gd
