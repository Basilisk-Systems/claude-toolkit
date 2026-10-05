#!/usr/bin/env bash
# Run a Godot project with a real (software) renderer under a virtual framebuffer.
# Usage: tools/render.sh <project-dir> [extra godot args]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ="${1:?project dir}"; shift || true
BIN="$("$DIR/godot.sh")"
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
xvfb-run -a -s "-screen 0 1280x720x24" "$BIN" --path "$PROJ" --rendering-driver opengl3 --rendering-method gl_compatibility --quit-after 900 "$@" 2>&1 | grep -v -i -E '^$|alsa|audio' || true
