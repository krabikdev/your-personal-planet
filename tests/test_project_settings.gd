extends GutTest


func test_game_starts_in_fullscreen() -> void:
	var mode: int = int(ProjectSettings.get_setting("display/window/size/mode"))
	assert_eq(mode, DisplayServer.WINDOW_MODE_FULLSCREEN, "the game should open in fullscreen mode")


func test_base_resolution_is_full_hd() -> void:
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert_eq(width, 1920, "base viewport width should be Full HD")
	assert_eq(height, 1080, "base viewport height should be Full HD")
