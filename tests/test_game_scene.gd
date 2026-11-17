extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func test_game_scene_instantiates_cleanly() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	assert_not_null(scene, "game.tscn should load")

	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)

	var planet: Planet = game.get_node_or_null("Planet") as Planet
	assert_not_null(planet, "game should contain the Planet")
	assert_almost_eq(planet.radius, PlanetProfile.BASE_RADIUS, 0.01)
	assert_gt(planet.get_child_count(), 0, "planet should have its collision and surface")

	var player: Boy = game.get_node_or_null("Player") as Boy
	assert_not_null(player, "game should contain the Player")
	assert_gt(player.get_altitude(), -0.5, "player should start on the surface")

	assert_not_null(game.get_node_or_null("CameraRig"), "camera rig should exist")
	assert_not_null(game.get_node_or_null("DebrisManager"), "debris manager should exist")
	assert_not_null(game.get_node_or_null("GameHud"), "HUD should exist")
	assert_not_null(game.get_node_or_null("Inventory"), "inventory should exist")
	assert_not_null(game.get_node_or_null("GameOver"), "game over screen should exist")
	assert_not_null(game.get_node_or_null("PauseMenu"), "pause menu should exist")


func test_game_starts_with_empty_inventory() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(1)

	var game_script: Game = game as Game
	assert_not_null(game_script, "game root should use game.gd")
	var model: InventoryModel = game_script.get_inventory_model()
	assert_not_null(model, "inventory model should exist")
	assert_true(model.is_empty(), "the boy starts with an empty bag")


func test_hud_counts_a_caught_stone() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	game.debug_grant_stone(StoneItem.Kind.ICE, 1.1)
	assert_eq(game.get_inventory_model().size(), 1)
	var hud: GameHUD = game.get_node("GameHud") as GameHUD
	var button: Button = hud.get_node("%InventoryButton") as Button
	assert_string_contains(button.text, "1")


func test_planet_surface_is_bare() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var planet: Planet = game.get_node("Planet") as Planet
	assert_null(planet.get_node_or_null("Rocks"), "the planet should have no surface rocks")
	assert_null(
		planet.get_node_or_null("Marker"), "the catch marker on the surface has been removed"
	)
	var extra_colliders: int = 0
	for child: Node in planet.get_children():
		if child is CollisionShape3D:
			extra_colliders += 1
	assert_eq(extra_colliders, 1, "only the planet's own sphere collider should remain")


func test_boy_can_walk_across_the_surface() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.2).timeout

	assert_gt(
		start.distance_to(player.global_position), 0.5, "the boy should be able to walk freely"
	)


func test_catch_hint_floats_above_the_boy() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var hint: Node3D = player.get_node("CatchHint") as Node3D
	assert_not_null(hint, "the catch hint should be part of the boy")
	assert_gt(hint.position.y, 1.2, "the hint should sit above his head")
	assert_false(hint.visible, "the hint starts hidden")

	player.set_catch_hint(true)
	assert_true(hint.visible, "the hint should appear while the debris is near")
	player.set_catch_hint(false)
	assert_false(hint.visible, "the hint should disappear when the debris leaves")


func test_debris_countdown_is_10_to_30_seconds() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	var countdown: float = debris.get_countdown()
	assert_gte(countdown, 9.0, "the next flyby should be at most half a minute away")
	assert_lte(countdown, 30.0, "the countdown should start within the new range")


func test_debris_appears_far_from_the_planet() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	var planet: Planet = game.get_node("Planet") as Planet
	debris.force_spawn()
	await get_tree().create_timer(DebrisManager.WARNING_TIME + 0.2).timeout

	var node: Node3D = debris.get_node_or_null("Debris") as Node3D
	assert_not_null(node, "the flyby should have created its debris")
	var distance: float = node.global_position.distance_to(planet.get_center())
	assert_gt(
		distance,
		planet.radius + 3.0,
		"the junk should fade in from far away instead of popping in nearby"
	)


func test_run_action_exists() -> void:
	assert_true(InputMap.has_action("run"), "the run action should be mapped to Shift")


func test_hud_planet_size_is_just_a_value() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var hud: GameHUD = game.get_node("GameHud") as GameHUD
	var label: Label = hud.get_node("%DiameterLabel") as Label
	assert_false(label.text.contains("хлопчик"), "the planet size should not be measured in boys")
	assert_string_contains(label.text, "10.0")


func test_run_increases_the_boy_speed() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	Input.action_press("move_forward")
	await get_tree().create_timer(0.8).timeout
	var walk_speed: float = player.velocity.length()
	Input.action_press("run")
	await get_tree().create_timer(0.5).timeout
	var run_speed: float = player.velocity.length()
	Input.action_release("run")
	Input.action_release("move_forward")

	assert_gt(run_speed, walk_speed * 1.3, "holding Shift should make the boy run faster")


func test_net_swing_raises_the_catch_point() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var rest_height: float = player.get_net_catch_point().y
	player.swing_net()
	await get_tree().create_timer(0.32).timeout

	assert_true(player.is_net_active(), "the net should be active mid-swing")
	assert_gt(
		player.get_net_catch_point().y,
		rest_height + 0.2,
		"the net should rise above the boy during the swing"
	)
	await get_tree().create_timer(0.5).timeout
	assert_false(player.is_net_active(), "the swing should end")


func test_mouse_drag_rotates_the_camera() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	var before: Vector3 = rig.get_tangent_forward(Vector3.UP)
	rig.orbit_by(140.0)
	var after: Vector3 = rig.get_tangent_forward(Vector3.UP)
	assert_gt(before.angle_to(after), 0.1, "dragging should turn the view left or right")
