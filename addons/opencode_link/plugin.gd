@tool
extends EditorPlugin

## Opens an OpenCode session for this project when the editor opens it.
##
## This covers every way a project gets opened: the desktop shortcut, Godot's
## Project Manager, or double-clicking project.godot. The actual work happens in
## tools/open-opencode-if-needed.ps1, which refuses to spawn duplicates and waits
## for the Godot AI port so the MCP connection succeeds on the first attempt.

const LAUNCHER_RELATIVE := "tools/open-opencode-if-needed.ps1"


func _enter_tree() -> void:
	# Never act in headless runs (CI, --import, --quit smoke loads).
	if DisplayServer.get_name() == "headless":
		return

	var project_dir: String = ProjectSettings.globalize_path("res://")
	project_dir = project_dir.trim_suffix("/").trim_suffix("\\")
	if project_dir.is_empty():
		return

	var launcher: String = project_dir.path_join(LAUNCHER_RELATIVE)
	if not FileAccess.file_exists(launcher):
		push_warning("[opencode_link] launcher not found: %s" % launcher)
		return

	var args := PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden",
		"-File", '"%s"' % launcher,
		"-Path", '"%s"' % project_dir,
		"-WaitForGodotAi",
	])
	var pid: int = OS.create_process("powershell.exe", args)
	if pid <= 0:
		push_warning("[opencode_link] could not start the session helper (pid=%d)" % pid)
	else:
		print("[opencode_link] session helper started (pid %d) for %s" % [pid, project_dir])
