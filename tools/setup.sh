#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/runtime.sh
godot --version
godot --headless --editor --path . --import
