#!/usr/bin/env bash
# Generate Godot's class reference locally (912 XML files, ~1 s). grep docs/doc/classes/<Class>.xml.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$("$DIR/godot.sh")"
OUT="${1:-$PWD/.godot-docs}"
mkdir -p "$OUT" && "$BIN" --headless --doctool "$OUT" 2>&1 | grep -v -i -E 'alsa|audio|^$' || true
echo "$OUT/doc/classes"
