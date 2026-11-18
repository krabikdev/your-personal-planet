extends GutTest  # gdlint:ignore=max-public-methods

const GAME_PATH: String = "res://scenes/game.tscn"


func _frost_progress(game: Game) -> float:
	var material: ShaderMaterial = game._frost_material
	if material == null:
		return 0.0
	return float(material.get_shader_parameter("progress"))


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


func test_frost_effect_only_starts_after_death() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	game._on_cold_changed(0.95)
	assert_almost_eq(
		_frost_progress(game), 0.0, 0.001, "a living boy should not be covered in frost"
	)

	game._play_freeze_effect()
	await wait_process_frames(4)
	assert_gt(_frost_progress(game), 0.0, "the frost should appear once the boy is dead")


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
	await get_tree().create_timer(0.35).timeout
	Input.action_release("move_forward")

	assert_gt(
		start.distance_to(player.global_position), 0.35, "the boy should be able to walk freely"
	)


func test_the_boy_has_no_debris_hint() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	assert_null(player.get_node_or_null("CatchHint"), "the floating junk hint is gone")
	assert_false(player.has_method("set_catch_hint"), "there is no catch hint API any more")


func test_debris_countdown_is_5_to_10_seconds() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	var countdown: float = debris.get_countdown()
	assert_gte(countdown, 4.8, "the next flyby should come quickly")
	assert_lte(countdown, 10.0, "the countdown should stay within ten seconds")


func test_debris_dot_previews_during_the_warning() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	await wait_process_frames(1)

	var node: Node3D = debris.get_node_or_null("Debris") as Node3D
	assert_not_null(node, "the junk should already show as a dot before it flies")
	var first_scale: float = node.scale.x
	assert_lt(first_scale, 0.2, "the preview should start as a tiny dot")

	await get_tree().create_timer(0.5).timeout
	assert_gt(node.scale.x, first_scale + 0.01, "the dot should grow as the junk approaches")
	assert_lt(node.scale.x, 1.0, "it should still be small during the warning")


func test_debris_flyby_is_silent() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	debris.debug_launch_now()
	await wait_process_frames(1)

	var node: Node3D = debris.get_node_or_null("Debris") as Node3D
	assert_not_null(node, "the flyby should still exist")
	for child: Node in node.get_children():
		assert_false(
			child is AudioStreamPlayer3D, "space junk should not make a sound while flying"
		)


func test_debris_drifts_at_half_speed() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	assert_gte(debris._speed, 1.3, "the junk should drift slowly across the sky")
	assert_lte(debris._speed, 2.2, "the flyby should take twice as long as it used to")


func test_the_first_flyby_shows_no_hint() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var hud: GameHUD = game.get_node("GameHud") as GameHUD
	assert_null(hud.get_node_or_null("%WarningLabel"), "the flyby warning was removed")
	assert_false(hud.has_method("show_warning"), "the HUD cannot show a flyby hint any more")


func test_debris_appears_far_from_the_planet() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	var planet: Planet = game.get_node("Planet") as Planet
	debris.force_spawn()
	debris.debug_launch_now()
	await wait_process_frames(1)

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


func test_debris_is_caught_without_pressing_the_net() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	debris.debug_launch_now()
	await wait_process_frames(1)

	var node: Node3D = debris.get_node("Debris") as Node3D
	node.global_position = player.get_net_catch_point()
	assert_false(player.is_net_active(), "the player should not have to swing the net first")
	assert_true(debris._try_catch(), "the net reaching the junk should catch it automatically")
	assert_eq(
		debris._phase, DebrisManager.Phase.CAUGHT, "the flyby should switch to the caught phase"
	)


func test_the_net_reaches_farther_than_before() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	debris.debug_launch_now()
	await wait_process_frames(1)

	assert_gt(DebrisManager.NET_CATCH_RADIUS, 1.5, "the catch radius should be generous")
	var node: Node3D = debris.get_node("Debris") as Node3D
	node.global_position = player.get_net_catch_point() + player.get_up() * 1.7
	assert_true(debris._try_catch(), "a net almost two metres away should still scoop the junk")


func test_the_automatic_catch_swings_the_net_without_a_whoosh() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
	debris.force_spawn(0.5)
	debris.debug_launch_now()
	await wait_process_frames(1)

	assert_null(player._audio.stream, "the boy should not have made a sound yet")
	var node: Node3D = debris.get_node("Debris") as Node3D
	node.global_position = player.get_net_catch_point()
	assert_true(debris._try_catch(), "the automatic catch should still work")
	assert_ne(
		player._audio.stream,
		player._streams["whoosh"],
		"an automatic catch must not play the flyby whoosh"
	)

	player.swing_net()
	assert_eq(
		player._audio.stream.resource_path,
		"res://assets/audio/whoosh.wav",
		"the player's own swing keeps its sound"
	)


func test_the_smear_sound_plays_at_half_volume() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var smear: AudioStream = load("res://assets/audio/smear.wav")
	game._start_apply(StoneItem.new(StoneItem.Kind.ROCK, 1.0, 1))

	var played: bool = false
	for audio_player: AudioStreamPlayer in AudioDirector._pool:
		if audio_player.stream == smear:
			played = true
			var expected: float = linear_to_db(AudioDirector.sfx_volume) + Game.SMEAR_DB
			assert_almost_eq(
				audio_player.volume_db,
				expected,
				0.01,
				"the smear should be about twice as quiet as before"
			)
	assert_true(played, "smearing a stone should start the smear sound")
	assert_almost_eq(Game.SMEAR_DB, -5.5, 0.01, "half the loudness is six decibels down")


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
	await get_tree().create_timer(0.35).timeout
	var walk_speed: float = player.velocity.length()
	Input.action_press("run")
	await get_tree().create_timer(0.3).timeout
	var run_speed: float = player.velocity.length()
	Input.action_release("run")
	Input.action_release("move_forward")

	assert_gt(run_speed, walk_speed * 1.3, "holding Shift should make the boy run faster")


func test_the_duke_turns_smoothly_towards_the_stick() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var rig: CameraRig = player.camera_rig as CameraRig
	var up: Vector3 = player.get_up()
	var target: Vector3 = rig.get_tangent_right(up)
	var start: Vector3 = -player.global_transform.basis.z
	Input.action_press("move_right")
	await wait_physics_frames(1)
	var early: Vector3 = -player.global_transform.basis.z
	await get_tree().create_timer(0.25).timeout
	var late: Vector3 = -player.global_transform.basis.z
	Input.action_release("move_right")

	var target_late: Vector3 = rig.get_tangent_right(player.get_up())
	assert_gt(start.angle_to(early), 0.02, "the body should start turning right away")
	assert_gt(early.angle_to(target_late), 0.6, "one frame must not finish the turn")
	assert_lt(late.angle_to(target_late), 0.35, "the body should end up facing the input")


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
	await get_tree().create_timer(0.35).timeout
	assert_false(player.is_net_active(), "the swing should end")


func test_mouse_motion_rotates_the_camera_without_clicking() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	var before: Vector3 = rig.get_tangent_forward(Vector3.UP)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(160.0, 0.0)
	rig._unhandled_input(motion)
	var after: Vector3 = rig.get_tangent_forward(Vector3.UP)
	assert_gt(before.angle_to(after), 0.1, "moving the mouse should turn the view left or right")


func test_the_sky_view_action_is_mapped_to_q() -> void:
	var found: bool = false
	for event: InputEvent in InputMap.action_get_events("sky_view"):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode == KEY_Q:
				found = true
	assert_true(found, "holding Q should lift the camera to the sky")


func test_holding_q_points_the_camera_straight_up_from_the_duke() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	var player: Boy = game.get_node("Player") as Boy
	Input.action_press("sky_view")
	await get_tree().create_timer(0.3).timeout

	var camera: Camera3D = rig.get_camera()
	var look: Vector3 = -camera.global_transform.basis.z
	var up: Vector3 = player.get_up()
	Input.action_release("sky_view")
	assert_gt(look.dot(up), 0.95, "the camera should look straight up into space")
	assert_lt(
		camera.global_position.distance_to(player.global_position),
		2.6,
		"the camera should sit right at the duke's head"
	)
	assert_false(player.is_net_active(), "looking up should not swing the net")


func test_the_sky_camera_follows_the_mouse_in_every_direction() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	Input.action_press("sky_view")
	await get_tree().create_timer(0.25).timeout
	var start_pitch: float = rig.get_sky_pitch()
	var start_yaw: float = rig.get_sky_yaw()

	var sideways := InputEventMouseMotion.new()
	sideways.relative = Vector2(200.0, 0.0)
	rig._unhandled_input(sideways)
	assert_gt(absf(rig.get_sky_yaw() - start_yaw), 0.1, "moving the mouse sideways turns the view")

	var downward := InputEventMouseMotion.new()
	downward.relative = Vector2(0.0, 220.0)
	rig._unhandled_input(downward)
	assert_lt(rig.get_sky_pitch(), start_pitch - 0.1, "moving the mouse down tilts the view down")

	Input.action_release("sky_view")
	await get_tree().create_timer(0.2).timeout
	assert_false(rig.is_sky_view(), "releasing Q should return to the chase camera")


func test_interact_is_mapped_to_the_left_mouse_button() -> void:
	var found_click: bool = false
	for event: InputEvent in InputMap.action_get_events("interact"):
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_LEFT:
				found_click = true
	assert_true(found_click, "the net swing should be on the left mouse button")


func test_skeleton_lies_near_the_boy_with_its_finds() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var skeleton: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
	assert_not_null(skeleton, "the starting area should have a skeleton")
	var player: Boy = game.get_node("Player") as Boy
	var distance: float = player.global_position.distance_to(skeleton.global_position)
	assert_gt(distance, 1.0, "the finds should not be picked up instantly")
	assert_lt(distance, 3.0, "the skeleton should lie right next to the boy")
	assert_true(skeleton.has_can(), "the watering can should still be lying there")
	assert_true(skeleton.has_pouch(), "the pouch should still be lying there")


func test_skeleton_finds_can_be_picked_up() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var skeleton: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
	var player: Boy = game.get_node("Player") as Boy
	var model: InventoryModel = game.get_inventory_model()

	player.global_position = skeleton.get_can_position()
	await wait_process_frames(2)
	assert_eq(model.size(), 1, "walking up to the can should add it to the bag")
	assert_eq(model.items[0].kind, StoneItem.Kind.WATERING_CAN)

	player.global_position = skeleton.get_pouch_position()
	await wait_process_frames(2)
	assert_eq(model.size(), 2, "walking up to the pouch should add it too")
	assert_eq(model.items[1].kind, StoneItem.Kind.POUCH)


func test_the_skeleton_sinks_slowly_as_the_planet_grows() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var skeleton: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
	var planet: Planet = game.get_node("Planet") as Planet
	var start_position: Vector3 = skeleton.global_position

	planet.apply_radius(PlanetProfile.BASE_RADIUS + 0.25)
	await wait_process_frames(2)
	var moved: float = skeleton.global_position.distance_to(start_position)
	assert_gt(moved, 0.15, "the skeleton should ride the rising ground")
	assert_lt(moved, 0.25, "but it should fall a little behind the new surface")
	assert_lt(
		skeleton.global_position.distance_to(planet.get_center()),
		planet.radius,
		"the first growth should already start covering the bones"
	)
	assert_false(skeleton.is_buried(), "one small growth should not hide it yet")

	planet.apply_radius(PlanetProfile.BASE_RADIUS + 1.6)
	await wait_process_frames(2)
	assert_true(skeleton.is_buried(), "enough slow sinking should swallow the skeleton")
	assert_false(skeleton.visible, "a buried skeleton should not be drawn")


func test_the_bones_lie_flat_on_the_dust() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(1)

	var skeleton: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
	var resting: int = 0
	var lowest: float = 10.0
	var spine: MeshInstance3D = null
	var longest: float = 0.0
	for child: Node in skeleton.get_children():
		if not (child is MeshInstance3D):
			continue
		var node := child as MeshInstance3D
		if node.mesh == null:
			continue
		var ground_y: float = (node.transform * node.mesh.get_aabb()).position.y
		lowest = minf(lowest, ground_y)
		if ground_y <= 0.02:
			resting += 1
		if node.mesh is CylinderMesh:
			var cylinder := node.mesh as CylinderMesh
			if cylinder.height > longest:
				longest = cylinder.height
				spine = node

	assert_not_null(spine, "the skeleton should have a spine")
	assert_lte(
		(spine.transform * spine.mesh.get_aabb()).position.y,
		0.03,
		"the spine must rest on the dust, not float above it"
	)
	assert_lt(lowest, 0.01, "at least some bones should touch the ground")
	assert_gte(resting, 20, "almost every bone should lie flat instead of floating")
