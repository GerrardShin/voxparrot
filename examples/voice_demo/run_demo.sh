#!/usr/bin/env bash
# Headless end-to-end test: Godot -> HTTP -> sherpa-onnx/Parakeet -> transcript.
# Prereqs: backend server running (backend/server.py), GODOT env or `godot` on PATH,
# and a WAV file to transcribe.
#   ./run_demo.sh /path/to/sample.wav
set -euo pipefail
cd "$(dirname "$0")"
WAV="${1:?usage: run_demo.sh <sample.wav>}"
GODOT="${GODOT:-godot}"
mkdir -p addons
rm -rf addons/godot_parakeet
cp -r ../../addons/godot_parakeet addons/godot_parakeet
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
"$GODOT" --headless --path . -- --wav "$WAV"
