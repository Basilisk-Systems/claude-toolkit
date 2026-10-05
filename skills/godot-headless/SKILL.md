---
name: godot-headless
description: Working on a Godot 4.x project from a machine with no display, such as a Claude Code cloud session. Use when writing, running, testing, rendering or exporting a code-first Godot project blind - fetching the binary, headless vs virtual-framebuffer runs, screenshots from script, GDScript strict-typing traps, scene files as text, and generating the class reference locally.
allowed-tools: Read, Glob, Grep, Bash
---

# Godot without a screen

Facts learned by running Godot 4.6 blind inside a Claude Code cloud container. Everything here was verified on 2026‑10‑04; re‑verify if the Godot version changes.

## Getting the binary

```bash
scripts/godot.sh          # prints a Godot path, fetching 4.6-stable into ./.godot-bin/ if nothing is on PATH
```
Release assets on github.com download through the session proxy (71 MB, about a second when cached). `api.github.com` and the GitHub web pages are 403 through the proxy, so never rely on them to discover versions; pin the version in `scripts/godot.sh`. Export templates are 1.25 GB and belong in CI, never in a session.

## Three ways to run

| Need | Command | Notes |
|---|---|---|
| Logic only (tests, sim) | `godot --headless --path . -s tests/run.gd` | Dummy renderer, no window, fast. `-s` runs a script extending `SceneTree` or `MainLoop`. |
| Pixels (screenshots) | `LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --quit-after 900` | Real renderer on Mesa llvmpipe. ~3 s for a small scene with shadows. `--quit-after N` frames is the safety net against a hung script. |
| Class reference | `godot --headless --doctool docs` | Writes 912 XML files to `docs/doc/classes/` in one second. `grep` them instead of guessing the API. Regenerate per session; don't commit. |

`--headless` renders nothing: `get_viewport().get_texture()` returns an empty image. Use the Xvfb path for anything visual.

ALSA errors on boot (`snd_pcm_open_noupdate Unknown PCM default`) are harmless; the audio server falls back to the dummy driver. Filter them from logs with `grep -v -i -E 'alsa|audio'`.

## Screenshot from script

```gdscript
await RenderingServer.frame_post_draw      # once after setup
# change the scene
await RenderingServer.frame_post_draw
await RenderingServer.frame_post_draw      # two frames: shadows and transparency settle
get_viewport().get_texture().get_image().save_png("res://shot.png")
get_tree().quit()
```
`res://` writes work from a running project in a plain directory (not from a `.pck`). Use `user://` in exported builds.

## Project as text

- `project.godot` is INI. Minimum for the Compatibility renderer:
  ```
  [rendering]
  renderer/rendering_method="gl_compatibility"
  renderer/rendering_method.mobile="gl_compatibility"
  ```
- `.tscn` is text. A root node with a script is enough; build everything else in `_ready()`. When hand‑writing a scene, `load_steps` must equal the number of resources plus one, or Godot warns.
- Prefer building nodes in code over hand‑written deep scene trees: a typo in a `.tscn` fails silently, a typo in GDScript fails loudly with a line number.

## GDScript traps that stop the script at parse time

Warnings about inference are treated as errors in this project. The parser cannot infer a type from a `Variant`, and anything pulled out of an untyped `Array` or from `[a, b][i]` is `Variant`.
- `var y := tri[0].y` → `var y: float = tri[0].y`
- `for v in tri: st.add_vertex(v)` → `st.add_vertex(v as Vector3)`
- `var t := clamp(x, 0.0, 1.0)` → `clamp` returns Variant; use `clampf` or type the variable.
- `var s := sin(PI * t)` where `t` is already Variant → type `t` first.
Rule: type every variable that comes out of a container, a `Variant`‑returning builtin, or a `Dictionary`.

Integer overflow is silent in GDScript (64‑bit wrap), so a C‑style LCG like `(seed * 1103515245 + 12345) & 0x7fffffff` works unchanged. Prefer `RandomNumberGenerator` with `seed` set for anything beyond a spike.

## Rendering recipe for a low-poly scene

- Terrain: `SurfaceTool`, `PRIMITIVE_TRIANGLES`, `set_color()` before each face's three `add_vertex()` calls, `generate_normals(false)` for flat shading, `commit()` to an `ArrayMesh`. Material: `StandardMaterial3D` with `vertex_color_use_as_albedo = true`.
- Sun: `DirectionalLight3D`, `shadow_enabled = true`, position it then `look_at(Vector3.ZERO)`.
- Sky and fog: `WorldEnvironment` with `BG_COLOR`, `AMBIENT_SOURCE_COLOR`, `fog_enabled`. Keep `fog_density` tiny (0.0005–0.001) for a 70 m island or everything washes to the sky colour.
- Camera: `Camera3D` with `PROJECTION_ORTHOGONAL`, `size` ≈ 50, placed high and oblique, `look_at`, `current = true`.
- Water: `PlaneMesh` with an alpha `StandardMaterial3D` (`transparency = TRANSPARENCY_ALPHA`), moved on `position.y`.

## Tests

Plain scripts beat frameworks here. `tests/run.gd` extends `SceneTree`, loads `sim/` scripts with `preload`, runs assertions, prints a summary, and calls `quit(1)` on failure so CI sees a non‑zero exit. Run with `--headless -s`.

## Export in CI, not in sessions

GitHub Actions with a pinned Godot 4.6 export action: web build to Pages on every push to main; Linux and Windows zips as workflow artifacts. `export_presets.cfg` is text and lives in the repo. Never download templates in a daily session.

## Scripts in this skill

| Script | Does |
|---|---|
| `scripts/godot.sh` | Prints a Godot binary path. Uses `godot` on PATH if present, else fetches 4.6‑stable into `$GODOT_ROOT/.godot-bin/` (default: current directory). |
| `scripts/render.sh <project-dir> [args]` | Runs a project with a real software renderer under Xvfb. Needs `xvfb-run` and Mesa. |
| `scripts/docs.sh [out-dir]` | Generates the class reference XML (default `./.godot-docs`). |

Copy them into a project's `tools/` or call them from the skill directory. Add `.godot-bin/` and `.godot-docs/` to the project's `.gitignore`.
