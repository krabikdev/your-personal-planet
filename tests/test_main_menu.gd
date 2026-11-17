extends GutTest

const MAIN_MENU_PATH: String = "res://ui/main_menu.tscn"


func test_main_menu_structure() -> void:
	var scene: PackedScene = load(MAIN_MENU_PATH) as PackedScene
	assert_not_null(scene, "main_menu.tscn should load")

	var menu: Control = scene.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(1)

	assert_eq(menu.name, "MainMenu", "root should be named MainMenu")

	var margin: MarginContainer = menu.get_node_or_null("MarginContainer") as MarginContainer
	assert_not_null(margin, "root should contain a MarginContainer")

	var box: VBoxContainer = menu.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	assert_not_null(box, "MarginContainer should contain a VBoxContainer")

	var title: Label = menu.get_node_or_null("%TitleLabel") as Label
	assert_not_null(title, "title label should exist")
	var expected_title: String = str(ProjectSettings.get_setting("application/config/name", ""))
	assert_eq(title.text, expected_title, "title should show the project name")


func test_main_menu_has_three_buttons() -> void:
	var scene: PackedScene = load(MAIN_MENU_PATH) as PackedScene
	var menu: Control = scene.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(1)

	var buttons: Array[Button] = []
	for node: Node in menu.find_children("*", "Button", true, false):
		buttons.append(node as Button)

	assert_eq(buttons.size(), 3, "menu should expose exactly three buttons")


func test_buttons_are_wired_to_handlers() -> void:
	var scene: PackedScene = load(MAIN_MENU_PATH) as PackedScene
	var menu: Control = scene.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(1)

	var start_button: Button = menu.get_node_or_null("%StartButton") as Button
	assert_not_null(start_button, "start button should exist")
	assert_true(
		start_button.pressed.get_connections().size() > 0,
		"start button should have at least one pressed handler"
	)

	# Emitting must not throw.
	start_button.pressed.emit()
