#!/usr/bin/env bash
# Print the path to a Godot 4.6 binary, fetching it into .godot-bin/ if needed.
set -euo pipefail
VER="4.6-stable"
ROOT="${GODOT_ROOT:-$PWD}"
if command -v godot >/dev/null 2>&1; then command -v godot; exit 0; fi
BIN="$ROOT/.godot-bin/Godot_v${VER}_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$ROOT/.godot-bin" && cd "$ROOT/.godot-bin"
  curl -sL -o godot.zip "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_linux.x86_64.zip"
  unzip -q -o godot.zip && rm godot.zip && chmod +x "Godot_v${VER}_linux.x86_64"
fi
echo "$BIN"
