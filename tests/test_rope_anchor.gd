extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	return game


func test_stake_action_is_mapped_to_the_right_mouse_button() -> void:
	assert_true(InputMap.has_action("stake"), "the stake should have its own action")
	var found_click: bool = false
	for event: InputEvent in InputMap.action_get_events("stake"):
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_RIGHT:
				found_click = true
	assert_true(found_click, "the stake should be toggled with the right mouse button")


func test_pressing_the_right_mouse_button_toggles_the_stake() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy

	var press := InputEventAction.new()
	press.action = "stake"
	press.pressed = true
	game._unhandled_input(press)
	assert_true(player.rope.is_planted(), "the first right click should plant the stake")

	game._unhandled_input(press)
	assert_false(player.rope.is_planted(), "the second right click should pull the stake out")


func test_the_boy_hammers_a_stake_into_the_ground() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	assert_not_null(player.rope, "the game should hand the boy a rope anchor")

	player.plant_stake()
	assert_true(player.rope.is_planted(), "one press should drive the stake in")
	assert_almost_eq(
		player.rope.get_anchor_position().distance_to(planet.get_center()),
		planet.radius,
		0.01,
		"the stake should sit on the surface"
	)
	assert_almost_eq(
		player.rope.get_max_length(),
		PlanetProfile.death_altitude(planet.radius) * 0.95,
		0.01,
		"the rope should reach 95% of the freezing distance"
	)


func test_a_taut_rope_stops_the_boy_and_throws_him_back() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	var rope: RopeAnchor = player.rope
	var limit: float = rope.get_max_length()
	var up: Vector3 = player.get_up()

	# Hover just past the limit, still below the freezing altitude.
	player.global_position = planet.get_center() + up * (planet.radius + limit + 0.5)
	player.velocity = up * 6.0
	player._apply_rope_limit()

	var distance: float = player.global_position.distance_to(rope.get_anchor_position())
	assert_almost_eq(
		distance, limit, 0.01, "the rope should cap the distance exactly at its length"
	)
	assert_lt(player.velocity.dot(up), 0.0, "flying into the limit should bounce the boy back")


func test_holding_space_reels_the_boy_back_to_the_surface() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 1.6)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(2)

	Input.action_press("jump")
	await get_tree().create_timer(2.8).timeout
	Input.action_release("jump")

	assert_lt(player.get_altitude(), 0.6, "holding Space should crawl the boy back down the rope")


func test_removing_the_stake_removes_the_rope() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	player.plant_stake()
	var rope: RopeAnchor = player.rope
	assert_true(rope.is_planted(), "the stake should be planted first")

	player.remove_stake()
	await wait_process_frames(1)

	assert_false(rope.is_planted(), "the stake should be gone")
	assert_eq(rope.get_child_count(), 0, "the stake and the rope should be freed together")


func test_the_stake_has_its_own_soil_sounds() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	assert_true(player._streams.has("stake_plant"), "planting should have a soil-dig sound")
	assert_true(player._streams.has("stake_pull"), "removing should have a pull-out sound")

	player.plant_stake()
	await get_tree().create_timer(0.25).timeout
	assert_eq(
		player._audio.stream.resource_path,
		"res://assets/audio/stake_plant.wav",
		"planting should play the shovel-in-soil sound"
	)

	player.remove_stake()
	await get_tree().process_frame
	assert_eq(
		player._audio.stream.resource_path,
		"res://assets/audio/stake_pull.wav",
		"removing should play the stake-out-of-soil sound"
	)


func test_a_tethered_boy_flies_sideways_faster_than_he_walks() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 2.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(2)

	Input.action_press("move_right")
	await wait_physics_frames(24)
	var after_up: Vector3 = player.get_up()
	var tangent: Vector3 = player.velocity - after_up * player.velocity.dot(after_up)
	Input.action_release("move_right")

	assert_gt(
		tangent.length(),
		player.walk_speed * 1.2,
		"a boy hanging from the stake should glide sideways faster than he walks"
	)


func test_reeling_is_three_times_faster_and_plays_a_winch() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 10.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(2)

	assert_almost_eq(Boy.ROPE_CRAWL_SPEED, 4.05, 0.01, "reeling should be three times faster")

	Input.action_press("jump")
	await get_tree().create_timer(0.45).timeout
	var to_stake: Vector3 = player.rope.get_anchor_position() - player.global_position
	var reeling_speed: float = player.velocity.dot(to_stake.normalized())
	assert_gt(reeling_speed, 3.0, "holding Space should pull the boy in quickly")
	assert_true(player.is_winching(), "a winch should wind while the boy reels himself in")
	assert_eq(
		player._winch.stream.resource_path,
		"res://assets/audio/winch.wav",
		"the reel should use the winch loop"
	)
	assert_eq(
		(player._winch.stream as AudioStreamWAV).loop_mode,
		AudioStreamWAV.LOOP_FORWARD,
		"the winch loop should repeat seamlessly"
	)

	Input.action_release("jump")
	await wait_physics_frames(2)
	assert_false(player.is_winching(), "the winch should stop when Space is released")


func test_a_planted_stake_prevents_freezing() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()

	var up: Vector3 = player.get_up()
	player.global_position = (
		planet.get_center() + up * (planet.radius + planet.cold_altitude() + 1.0)
	)
	player.velocity = Vector3.ZERO
	player._cold = 0.85
	player._update_cold(2.0)

	assert_lt(player.get_cold(), 1.0, "a planted stake should cap the cold below death")
	assert_false(player.dead, "the boy must not freeze while the stake holds him")
