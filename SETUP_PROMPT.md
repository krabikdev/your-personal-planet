# Agentic Prompt — Reproducible AI-Driven Godot 4 Workspace

> **How to use:** start a fresh AI coding session in an empty folder and paste this entire file as the
> first message. The agent executes it phase by phase. Every phase ends with a verification command
> whose real output must be shown before the agent continues. Do not let it skip verification.

---

## 0. Mission

Set up a Godot 4 game-development workspace where an AI agent can:

1. connect to the running Godot editor over MCP (scene edits, screenshots, input simulation, logs),
2. create a brand-new game project from a template in one action,
3. open Godot *and* an attached AI coding session for any project — including one opened from Godot's
   own Project Manager,
4. prove every change with a single check command (format, lint, load, tests).

Target: **Godot 4.x stable** (pin the exact version; record it), one project = one folder, no global
state hidden outside the repo.

## 1. Non-negotiable rules

- **Verify, never assume.** Every step ends with a real command and its real output. If a command
  fails, fix the cause before moving on. Never report "done" from a config file alone.
- **Godot 4 APIs only.** No Godot 3 names: `@onready` not `onready`, `await` not `yield`,
  `CharacterBody3D` not `KinematicBody`, `@export` not `export`, `instantiate()` not `instance()`,
  `Node3D` not `Spatial`, `Packed*Array` not `Pool*Array`. Signals typed and connected by reference,
  never by string.
- **Static typing everywhere.** Type every variable, parameter, return value. No untyped public APIs.
- **UI = `Control` nodes + containers.** Never position/size UI manually; use
  `MarginContainer`/`VBoxContainer`/`GridContainer`/`ScrollContainer`, anchors and size flags.
  Verify layouts at both 1280×720 and 720×1280.
- **One check command must be green before "done".** Add tests for anything you add.
- **Ask before adding dependencies.** List what is approved; anything else needs a yes.
- **Don't edit third-party addons**, and exclude them from format/lint.
- **No secrets in the repo.** No API keys, no tokens, no `.env`.

## 2. Variables used below

| Name | Windows | Linux / macOS |
| --- | --- | --- |
| `PROJECT` | `C:\Godot` | `~/godot` |
| `GODOT` | `...\Godot_vX-stable_win64_console.exe` | `.../Godot_vX-stable_linux.x86_64` |
| Godot editor settings | `%APPDATA%\Godot\` | `~/.config/godot/` |
| Godot user data | `%APPDATA%\Godot\app_userdata\` | `~/.local/share/godot/app_userdata/` |
| OpenCode config | `%APPDATA%\opencode\` | `~/.config/opencode/` |
| Games folder | `Documents\Godot Games\` | `~/Godot Games/` |

`GODOT` must point at the **console/headless-capable** build. On Windows the GUI `.exe` detaches from
the terminal and loses stdout — always script against `*_console.exe`.

## 3. Phase 0 — host inventory

```powershell
# Windows
git --version; node --version; npm.cmd --version; python --version; uv --version
```

```bash
# Linux / macOS
git --version; node --version; npm --version; python3 --version; uv --version
```

Record the versions. Missing tools are installed in Phase 1; do not continue with gaps.

Also record the OS and whether PowerShell 5.1 (Windows) or PowerShell 7+ (`pwsh`) is available —
Phase 6's check script depends on it.

## 4. Phase 1 — install prerequisites

- **git** (needed by the generator and for commits).
- **Node.js LTS** (MCP servers and OpenCode are npm/uv based).
- **Python 3.11+** (Godot tooling: gdtoolkit).
- **uv** (provides `uvx`, which launches the Godot MCP server).

Install with the platform package manager:

- Windows: `winget install --id Git.Git -e`, `OpenJS.NodeJS.LTS`, `Python.Python.3.12`,
  `astral-sh.uv`. On Windows use `npm.cmd`, not `npm.ps1` (execution policy blocks the latter).
- Linux: distro packages for git/python3, NodeSource or `nvm` for Node, `curl -LsSf
  https://astral.sh/uv/install.sh | sh` for uv.
- macOS: `brew install git node python uv`.

**PATH gotcha (all OSes):** a process started from a desktop shortcut or a GUI launcher inherits a
possibly stale `PATH`. Every launcher you write must rebuild `PATH` from the OS source of truth
(registry on Windows, `/etc/environment` + shell profile on Linux) before starting Godot.

**uvx discovery gotcha:** Godot AI only searches well-known locations (`~/.local/bin`, `where uvx`).
Some installers put it elsewhere (e.g. `C:\Program Files\WinGet\Links`). After installing, copy
`uv`/`uvx` into `~/.local/bin` (Windows: `%USERPROFILE%\.local\bin`) so a GUI-launched editor can
find them. Verify by resolving `uvx --version` with only the system PATH present.

## 5. Phase 2 — install Godot

1. Download the **pinned stable** release (record the exact version string, e.g.
   `4.7.2.stable.official.<hash>`) from the official downloads page or the matching GitHub release.
2. Install/extract outside the project.
3. Persist a `GODOT` variable pointing at the console binary:
   - Windows: `setx GODOT "<path>\Godot_vX-stable_win64_console.exe"`.
   - Linux/macOS: export it in the shell profile, or install to a directory already on `PATH`.
4. Verify: `& $env:GODOT --version` / `"$GODOT" --version` — must print the section 2 version.

## 6. Phase 3 — project scaffold

```
PROJECT/
  AGENTS.md              # rules the agent must follow (Phase 7)
  SETUP_LOG.md           # phase-by-phase history + gotchas
  project.godot
  opencode.json          # MCP servers
  .gitignore  .gitattributes
  scenes/  scripts/  ui/  tests/  tools/
  addons/                # godot_ai, gut, (your own editor plugins)
```

`project.godot` must set at minimum:

```ini
config_version=5
[application]
config/name="<Name>"
run/main_scene="res://ui/main_menu.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
[editor_plugins]
enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg", "res://addons/gut/plugin.cfg")
```

`.gitignore`: `.godot/`, `export_presets.cfg`, `.env`, `*.translation`, `*.tmp`.
`.gitattributes`:

```
* text=auto eol=lf
*.png binary
*.ttf binary
*.ogg binary
```

Verify: `"$GODOT" --headless --path PROJECT --quit` loads with no `ERROR` / `SCRIPT ERROR`.

## 7. Phase 4 — MCP servers

Write `opencode.json`. **Detect the config schema first** — OpenCode V2 uses a `servers` map inside
`mcp`; V1 used a flat `mcp` map. Inspect the installed version's own schema/docs instead of guessing.

V2 shape:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "godot-ai": {
        "type": "local",
        "command": ["<absolute path to uvx>", "godot-ai"],
        "enabled": true
      },
      "context7": { "type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true }
    }
  }
}
```

Rules that matter:

- Use the **absolute** path to `uvx`. A stale `PATH` must not be able to break the server.
- Optional servers go in with `"disabled": true` rather than being deleted, so they stay discoverable.
- Install the **Godot AI editor addon** (`addons/godot_ai`) from its release zip; it self-disables in
  headless mode, so it only works with the GUI editor open.
- The addon registers an autoload (e.g. `_mcp_game_helper`) on first activation — leave it in place;
  game screenshots/eval need it.

Verify: open the editor, confirm the addon dock reports a connected server on its port (typically
8000), and that the MCP client lists roughly 40+ tools. A `no server found` warning means `uvx`
resolution failed (see Phase 1).

If the MCP client caches a failed connection, force a reconnect rather than restarting everything.

## 8. Phase 5 — skills and subagents

1. Install a Godot skill pack into `.opencode/skills/<id>/SKILL.md` (one folder per skill, YAML
   frontmatter with `name` + `description`).
2. Install subagent definitions into `.opencode/agents/`.
3. Frontmatter from other tools usually says `model: inherit`; that is not valid here — replace it with
   `mode: subagent` so the definitions load.
4. Verify: the skill/agent list in the client matches the file count, and names are unique.

## 9. Phase 6 — quality gate (the single check command)

Install:

- **gdtoolkit** (`gdformat`, `gdlint`) — pin a version.
- **GUT** as `addons/gut` — pin a version.

GUT gotcha: the first headless run fails with *"some class_names have not been imported"*. Run
`"$GODOT" --headless --import --path PROJECT` once, and make the project generator do it too.

Write `scripts/check.ps1` (Windows) or `scripts/check.sh` (Linux/macOS). It runs four stages in
order and exits non-zero if any fails:

1. `gdformat --check scripts ui tests scenes`
2. `gdlint scripts ui tests scenes`
3. headless project load — fail on any `ERROR` or `SCRIPT ERROR` line
4. GUT headless, with `-gexit` — parse `Passing Tests` / `Failing Tests` counts

Requirements: strip ANSI colour codes before parsing; print a compact summary table; make the
fail path demonstrably exit non-zero (break a file, run it, observe the failure, restore).

Verify: run it on a clean tree → all stages pass.

## 10. Phase 7 — AGENTS.md

Write the rules file the agent reads every session. It must contain:

- engine version string and how to invoke the console binary headless,
- the exact check command and the fact that it must pass before any "done",
- GDScript style: static typing, tabs, `snake_case` files/vars, `PascalCase` classes,
  typed signals connected by reference, `%UniqueName` instead of long paths, cache in `@onready`,
  `queue_free()` never `free()`,
- UI rules: `Control` only, containers only, no manual pixel layout, test 1280×720 and 720×1280,
  central theme,
- architecture: scenes + signals over autoloads, component composition, downward calls /
  upward signals,
- dependency policy and the list of approved addons,
- commit policy: one feature per commit, imperative subject,
- "never commit" list: `.godot/`, `export_presets.cfg`, `.env`, keystores.

## 11. Phase 8 — sample feature + tests

Build `ui/main_menu.tscn` (`Control` → `MarginContainer` → `VBoxContainer` → title `Label` + 3
`Button`s) and `ui/main_menu.gd` (typed `@onready` refs via `%Name`, `pressed.connect(_on_...)`).

Write `tests/test_main_menu.gd` (`extends GutTest`) asserting:

1. the scene instantiates,
2. `MarginContainer` → `VBoxContainer` hierarchy exists,
3. exactly 3 buttons,
4. **the title equals `application/config/name`** — never a hardcoded literal, or every derived
   project will fail one test,
5. the primary button has a `pressed` handler connected.

Verify: 5/5 passing, and if the MCP tooling is available, capture the game framebuffer and confirm
1280×720 plus a real click producing the expected log line.

## 12. Phase 9 — launchers

Six small scripts, each independently testable. Names below are suggestions; contracts are the point.

1. **`launch-godot`** — rebuild `PATH`, resolve `GODOT` (console path + derived GUI path), register
   the project with the Project Manager, start the editor, then start the project watcher.
   *Pitfall:* `Start-Process -ArgumentList` on Windows joins arguments **without quoting** — build one
   explicitly quoted argument string, or `C:\...\Godot Games\x` silently becomes `C:\...\Godot`.
   *Pitfall:* an empty `-ArgumentList` throws on Windows PowerShell 5.1 — branch on the no-args case.

2. **`open-ai-session`** — start the AI coding CLI/TUI rooted at a folder in a **new visible console**
   window, with a window title identifying the project.

3. **`open-ai-session-if-needed`** — the dedupe layer:
   - scan running CLI processes for the project path;
   - plus a per-project lock file valid for ~90 s (prevents a double window when two triggers fire
     within a second);
   - optionally wait for the editor's MCP port (short timeout, e.g. 120 s) so the session connects on
     the first try.

4. **`watch-godot-projects`** — catch-all for **Godot's Project Manager**: poll the process table for
   any Godot editor started with `--path <dir>`, and ask (3) to attach a session to that folder.
   This is what makes PM-opened projects work at all, because a project created inside Godot contains
   no plugin of yours. Guard it with a **named mutex**
   (`[System.Threading.Mutex]::new($true,'Local\YourName',[ref]$created)`), not a command-line scan —
   any shell that merely mentions the script name would look like a running instance. Exit after a
   few idle minutes with no editors.

5. **an editor plugin (`@tool extends EditorPlugin`)** — optional fast path: on `_enter_tree`, skip if
   `DisplayServer.get_name() == "headless"`, resolve `res://` to a real path, then spawn (3). Print a
   diagnostic line on success and on failure; silence here is the main debugging cost.

6. **`add-to-project-manager` + `new-game` + `create-shortcuts`** —
   - Godot only lists a project in its Project Manager if the PM itself created/opened it. Register by
     appending `[C:/normalized/path]` + blank line + `favorite=false` to the PM's `projects.cfg`
     (section 2). Idempotent; verify the entries survive a PM open/close.
   - `new-game` copies the template to a new folder while excluding `.git`, `.godot`, `SETUP_LOG.md`,
     `export_presets.cfg`, rewrites `config/name` and the main-menu title, `git init` + first commit,
     pre-imports the engine cache, and registers the project.
   - `create-shortcuts` writes idempotent desktop entries/`.lnk` files for: Project Manager, this
     project, new game.

Generator performance pitfalls (both bit this setup):

- `Copy-Item -Recurse` on Windows PowerShell 5.1 re-enumerates the tree per item and looks like a
  hang; 881 files took minutes. Use `robocopy /E` (0.6 s) or `rsync -a --exclude`.
- `git add -A 2>$null` can deadlock under `$ErrorActionPreference='Stop'` when git emits hundreds of
  CRLF warnings. Fix the cause with `* text=auto eol=lf` in `.gitattributes` + `core.autocrlf=false`,
  and never redirect native-tool stderr; let exit codes decide.
- Never call `Read-Host` in an error path that can run unattended — a failure then looks like a
  permanent freeze. Gate prompts on "is a human actually watching".
- PowerShell 5.1 `Get-Content`/`Set-Content` corrupt UTF-8: use `[IO.File]::ReadAllText` /
  `WriteAllText` with `UTF8Encoding($false)`.

## 13. Phase 10 — acceptance tests (all must pass)

1. `check` script on the template → all stages pass.
2. Generate a new game into a temp folder → completes in well under a minute, has a first commit.
3. `check` script inside the **generated** game → all stages pass **first run** (proves the
   pre-import step).
4. Project appears in the Project Manager list and survives a PM restart.
5. Open a project from the Project Manager → an AI session for that folder appears without manual
   action, and a second trigger does not create a duplicate.
6. Open a project whose path contains a space → editor opens the correct project (quoting fix).
7. Project name with a space, non-ASCII name, and a fresh folder → all still work.
8. Restore/delete the test artifacts and confirm the git tree is clean.

## 14. Appendix A — symptom → cause → fix

| Symptom | Cause | Fix |
| --- | --- | --- |
| `no server found` / `uv not found` in editor | `uvx` not in a path the addon searches | copy `uv`/`uvx` to `~/.local/bin`, use absolute path in MCP config |
| Editor opens the wrong/truncated path | unquoted `-ArgumentList` | pass one quoted argument string |
| New game "hangs forever" | recursive copy + `git add` stderr deadlock + `Read-Host` on error | robocopy/rsync, `.gitattributes` eol=lf, no stderr redirect, no interactive prompt |
| First test run fails on GUT class_names | engine cache not imported | `--headless --import` once, also in the generator |
| MCP tools missing after config change | client caches connection status per directory | force reconnect / restart the client |
| Godot rewrites `project.godot` and settings vanish | Godot drops values equal to defaults | verify effective values through the running editor, not the file |
| Project never appears in Project Manager | `--editor --path` does not register projects | append to `projects.cfg` |
| AI session never opens from Project Manager | project has no plugin of yours | process watcher + dedupe lock |
| Two AI sessions for one project | two triggers race | process scan + short-lived lock file |
| Watcher never starts / immediately exits | command-line self-match on a named script | use a named mutex |

## 15. Appendix B — final report the agent must produce

- versions installed (OS, Godot, Node, Python, uv, gdtoolkit, GUT),
- file inventory created (paths + one-line purpose),
- output of Phase 10, test by test,
- every deviation from this prompt and why,
- open issues with the exact command that reproduces them.

Stop and ask before: installing anything not listed here, changing the engine version, or editing
third-party addon code.
