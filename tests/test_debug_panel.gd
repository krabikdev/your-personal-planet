extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func after_each() -> void:
	Engine.time_scale = 1.0


func _make_game() -> Game:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	return game


func _button(panel: DebugPanel, text: String) -> Button:
	for node: Node in panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text:
			return button
	return null


func test_the_debug_panel_builds_categories_with_buttons() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	var panel: DebugPanel = game._debug_panel
	assert_not_null(panel, "the game should build a debug panel")
	assert_gte(
		panel.find_children("*", "Button", true, false).size(),
		12,
		"every category should bring its buttons"
	)

	var headings: Array[String] = []
	for node: Node in panel.find_children("*", "Label", true, false):
		headings.append((node as Label).text)
	for wanted: String in ["Планета", "Час симуляції", "Гравець", "Уламки та сумка"]:
		assert_true(headings.has(wanted), "the panel should show the %s category" % wanted)


func test_tab_opens_and_closes_the_debug_panel() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	var press := InputEventAction.new()
	press.action = "debug_panel"
	press.pressed = true
	assert_false(game._debug_panel.is_open(), "the panel starts closed")

	game._unhandled_input(press)
	assert_true(game._debug_panel.is_open(), "Tab should open the panel")
	assert_false(
		game._camera_rig.is_processing_unhandled_input(),
		"the camera should stop listening while the panel is open"
	)

	game._unhandled_input(press)
	assert_false(game._debug_panel.is_open(), "Tab again should close it")
	assert_true(
		game._camera_rig.is_processing_unhandled_input(),
		"the camera should take the mouse back when the panel closes"
	)


func test_the_planet_button_grows_the_world() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	var planet: Planet = game.get_node("Planet") as Planet
	var before: float = planet.radius
	var button: Button = _button(game._debug_panel, "+10")
	assert_not_null(button, "the panel should offer a +10 button")

	button.pressed.emit()
	assert_almost_eq(planet.radius, before + 10.0, 0.01, "the +10 button should grow the planet")

	var reset: Button = _button(game._debug_panel, "5")
	assert_not_null(reset, "the panel should offer a reset button")
	reset.pressed.emit()
	assert_almost_eq(planet.radius, 5.0, 0.01, "the reset button should shrink the world back")


func test_the_cold_buttons_drive_the_boy() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	game._on_debug_action(&"cold_set", 0.5)
	assert_almost_eq(player.get_cold(), 0.5, 0.01, "the panel should set the cold directly")

	game._on_debug_action(&"cold_set", 0.0)
	assert_almost_eq(player.get_cold(), 0.0, 0.01, "the warm button should clear the cold")


func test_the_time_buttons_change_the_simulation_speed() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	game._on_debug_action(&"time_scale", 4.0)
	assert_almost_eq(Engine.time_scale, 4.0, 0.001, "the time buttons should speed the world up")

	game._on_debug_action(&"time_scale", 1.0)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "and put it back")


func test_the_debris_button_skips_the_waiting() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	game._on_debug_action(&"debris", 1.0)
	assert_eq(
		debris._phase, DebrisManager.Phase.FLYING, "the button should launch the flyby right away"
	)
