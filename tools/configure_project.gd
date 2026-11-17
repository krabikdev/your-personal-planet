extends SceneTree

## One-off project setup helper: writes the input map, the global UI theme and
## the renderer quality bits. Run:
##   godot --headless --path . --script tools/configure_project.gd

const ACTIONS: Dictionary[String, Array] = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"interact": [],
	"plant": [KEY_Q],
	"unplant": [KEY_E],
	"inventory": [KEY_I],
	"pause": [KEY_ESCAPE],
}


func _initialize() -> void:
	for action: String in ACTIONS.keys():
		var events: Array[InputEvent] = []
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.device = -1
			events.append(event)
		if action == "interact":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.device = -1
			events.append(click)
		ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": events})
	ProjectSettings.set_setting("gui/theme/custom", "res://ui/theme/app_theme.tres")
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 0)
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 2)
	var error := ProjectSettings.save()
	if error != OK:
		printerr("Could not save project settings: %s" % error)
	else:
		print("Project settings saved.")
	quit()
