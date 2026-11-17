extends GutTest

const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"


func _instantiate() -> Control:
	var scene: PackedScene = load(MAIN_MENU_PATH) as PackedScene
	assert_not_null(scene, "main_menu.tscn should load")
	var menu: Control = scene.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(1)
	return menu


func test_main_menu_structure() -> void:
	var menu: Control = await _instantiate()
	assert_eq(menu.name, "MainMenu", "root should be named MainMenu")

	var margin: MarginContainer = menu.get_node_or_null("MarginContainer") as MarginContainer
	assert_not_null(margin, "root should contain a MarginContainer")

	var box: VBoxContainer = menu.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	assert_not_null(box, "MarginContainer should contain a VBoxContainer")

	var title: Label = menu.get_node_or_null("%TitleLabel") as Label
	assert_not_null(title, "title label should exist")
	assert_false(title.text.strip_edges().is_empty(), "title should have a visible name")


func test_main_menu_has_three_primary_buttons() -> void:
	var menu: Control = await _instantiate()
	for unique_name: String in ["%StartButton", "%SettingsButton", "%QuitButton"]:
		var button: Button = menu.get_node_or_null(unique_name) as Button
		assert_not_null(button, "%s should exist" % unique_name)
		assert_gt(
			button.pressed.get_connections().size(),
			0,
			"%s should have a pressed handler" % unique_name
		)


func test_settings_overlay_exists() -> void:
	var menu: Control = await _instantiate()
	var settings: Node = menu.get_node_or_null("%SettingsPanel")
	assert_not_null(settings, "settings overlay should be part of the menu")
	assert_true(settings.has_method("open"), "settings overlay should expose open()")


func test_menu_overlays_do_not_block_clicks() -> void:
	var menu: Control = await _instantiate()
	for path: String in ["%SettingsPanel", "Fade"]:
		var overlay: Control = menu.get_node(path) as Control
		assert_not_null(overlay, "%s should exist" % path)
		assert_eq(
			overlay.mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"%s must not swallow clicks meant for the menu buttons" % path
		)
