# AGENTS.md — Project Rules

This is a **Godot 4.7** project. Read these rules before touching any file.

## Environment

| Item | Value |
| --- | --- |
| Engine | Godot **4.7.2.stable.official.ed1daf0bf** |
| `GODOT_VERSION` | `4.7.2.stable.official.ed1daf0bf` |
| `$env:GODOT` | `C:\Program Files\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` |
| Project root | `C:\Godot` |

`$env:GODOT` points at the **console** executable. The GUI `Godot_v4.7.2-stable_win64.exe` detaches from
the terminal and loses stdout, so always use `$env:GODOT` for scripted / headless runs:

```powershell
& $env:GODOT --headless --path . --quit
```

In a fresh shell, re-read it if the variable is unset:
`$env:GODOT = [Environment]::GetEnvironmentVariable('GODOT','User')`

## Godot 4 only — never Godot 3 APIs

| Never (Godot 3) | Use (Godot 4) |
| --- | --- |
| `onready var x` | `@onready var x` |
| `yield(obj, "signal")` | `await obj.signal` |
| `KinematicBody` / `KinematicBody2D` | `CharacterBody3D` / `CharacterBody2D` |
| `export var x` | `@export var x` |
| `connect("pressed", self, "_on_pressed")` | `pressed.connect(_on_pressed)` |
| `instance()` | `instantiate()` |
| `OS.get_ticks_msec()` (where a 4.x API exists) | `Time.get_ticks_msec()` |
| `Spatial` | `Node3D` |
| `PoolStringArray` etc. | `PackedStringArray` etc. |

Signals must be **typed** and connected by reference, never by string:

```gdscript
signal score_changed(new_score: int)

func _ready() -> void:
	score_changed.connect(_on_score_changed)

func _on_score_changed(new_score: int) -> void:
	%ScoreLabel.text = str(new_score)
```

## GDScript style

- **Static typing everywhere.** Type every variable, parameter, and return value
  (`var speed: float = 0.0`, `func move(dir: Vector2) -> void:`). Prefer `:=` only when the
  inferred type is unambiguous. No untyped `Array`/`Dictionary` in public APIs — use
  `Array[Node]`, `Dictionary[String, int]`.
- Tabs for indentation (Godot default), one class per file, `snake_case` for
  files/variables/functions, `PascalCase` for `class_name` and nodes.
- Prefer `@export` over hardcoded values so designers can tune in the inspector.
- Use `%UniqueName` (scene-unique names) instead of long `get_node("../../X")` paths.
- Never `get_node()` in `_process`; cache in `@onready`.
- `queue_free()`, never `free()`.

## UI rules

- **`Control` nodes only** for UI — never `Node2D`/`Sprite2D` for interface.
- **Layout with containers**, never manual pixel positions or sizes:
  `MarginContainer`, `VBoxContainer`, `HBoxContainer`, `GridContainer`, `ScrollContainer`,
  `CenterContainer`, `PanelContainer`.
- Use **anchors and container flags** (`size_flags_horizontal/vertical`) for growth and alignment.
  Do not set `position` / `size` numerically to lay things out.
- Outer margins/padding come from a `MarginContainer` with theme constants, not spacer nodes.
- Text that must scale/wrap: set `autowrap_mode` and let the container size it.
- Never hardcode a window size assumption. **Test every UI at both 1280×720 (landscape) and
  720×1280 (portrait).** The project uses `stretch/mode="canvas_items"` with
  `stretch/aspect="expand"`, so layouts must adapt rather than assume a fixed canvas.
- Centralize fonts/colors in a `Theme` resource; avoid scattered `theme_override_*` unless it is a
  genuine one-off.

## Architecture

- **Prefer scenes + signals over singletons.** Reach for an autoload only for genuinely global,
  stateless services (e.g. an audio bus manager). Do not put game state in autoloads.
- Compose behaviour from small scenes/nodes (component pattern) rather than deep inheritance.
- Communicate upward with signals; call downward with methods. Siblings talk through a parent or a
  typed signal, not `get_node("../../..")`.
- Keep each scene focused on one responsibility; one feature per commit.

## Verification — mandatory

After **every** change, run the full pipeline and fix every error before continuing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

(`pwsh scripts\check.ps1` if PowerShell 7 is ever installed — this machine currently has only
Windows PowerShell 5.1, so the `powershell` form above is the one that works.)

It runs, in order, and exits non-zero on any failure:

1. `gdformat --check` — formatting must be canonical (fix with `gdformat scripts ui tests scenes`)
2. `gdlint` — static analysis
3. headless project load — fails on any `ERROR` / `SCRIPT ERROR`
4. GUT tests headless (`addons/gut`, tests in `res://tests`)

Do not report a task as done while this script fails. If you add a feature, add or update a GUT
test under `tests/` (`extends GutTest`, file name `test_*.gd`).

## Docs and APIs

- **Use Context7** (`context7` MCP server) whenever you are unsure about a Godot 4.7 API, a class
  name, a method signature, or a changed default. Do not guess API shapes from memory.
- Godot AI (`godot-ai` MCP) is available **only while the Godot editor is open on this project**.
  It talks to the live editor; if its tools are missing, open the editor.
- Prefer the official docs over blog posts for engine behaviour.

## Dependencies

- **Ask before adding any new addon, MCP server, or tool.** Current approved addons:
  `addons/godot_ai` (editor/MCP bridge) and `addons/gut` (tests). Nothing else is pre-approved.
- Do not reformat or "fix" third-party addon code. `scripts/check.ps1` intentionally excludes
  `addons/`.

## Commits

- One feature per commit, imperative subject (`feat: add player dash`).
- Never commit `.godot/`, `export_presets.cfg`, `.env`, or keystores.
