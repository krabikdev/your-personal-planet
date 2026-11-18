extends GutTest  # gdlint:ignore=max-public-methods

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
	await wait_physics_frames(1)
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
	await wait_physics_frames(1)

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
	await wait_physics_frames(1)

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
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 1.6)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)

	Input.action_press("jump")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("jump")

	assert_lt(player.get_altitude(), 0.6, "holding Space should crawl the boy back down the rope")


func test_space_slows_the_flight_instead_of_throwing_the_boy_back() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 5.0)
	player.velocity = up * 5.0
	player._coyote = 0.0
	player._rope_brake_latch = false
	Input.action_press("jump")
	await wait_physics_frames(1)
	assert_gt(
		player.velocity.dot(up), 3.5, "the first frame must not bounce him back towards the stake"
	)

	await get_tree().create_timer(0.5).timeout
	assert_lt(player.velocity.dot(up), 1.0, "the winch should gradually eat the outward speed")

	await get_tree().create_timer(0.4).timeout
	Input.action_release("jump")
	assert_lt(player.velocity.dot(up), -0.5, "then it should start pulling him home")


func test_a_rope_snap_does_not_play_the_flying_whoosh() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	player.plant_stake()
	await wait_physics_frames(1)

	var whoosh: AudioStream = load("res://assets/audio/whoosh.wav")
	player.rope.notify_snap(6.0)
	await wait_process_frames(1)
	for audio_player: AudioStreamPlayer in AudioDirector._pool:
		assert_ne(audio_player.stream, whoosh, "the rope must not play the airy flight whoosh")


func test_removing_the_stake_removes_the_rope() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

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
	await wait_physics_frames(1)

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
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 2.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)

	Input.action_press("move_right")
	await wait_physics_frames(12)
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
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 10.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)

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
	await wait_physics_frames(1)
	assert_false(player.is_winching(), "the winch should stop when Space is released")


func test_a_planted_stake_prevents_freezing() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

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


func test_wasd_steers_the_boy_while_the_winch_pulls_him_in() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 6.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)

	Input.action_press("jump")
	await wait_physics_frames(12)
	var sideways_without: Vector3 = player.velocity - up * player.velocity.dot(up)

	var altitude_before: float = player.get_altitude()
	Input.action_press("move_right")
	await wait_physics_frames(12)
	var sideways_with: Vector3 = player.velocity - up * player.velocity.dot(up)
	var altitude_after: float = player.get_altitude()
	var facing: Vector3 = player._facing
	Input.action_release("move_right")
	Input.action_release("jump")

	assert_gt(
		sideways_with.length(),
		sideways_without.length() + 2.0,
		"WASD should slide the boy sideways while the winch holds him"
	)
	assert_lt(
		altitude_after,
		altitude_before - 0.15,
		"the winch should keep winding him towards the stake while he steers"
	)
	assert_gt(
		facing.dot(sideways_with.normalized()),
		0.7,
		"the duke should turn into the direction he glides"
	)


func test_space_alone_does_not_steer_the_boy() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 6.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)

	Input.action_press("jump")
	await wait_physics_frames(12)
	var sideways: Vector3 = player.velocity - up * player.velocity.dot(up)
	Input.action_release("jump")

	assert_lt(sideways.length(), 1.0, "with only Space held the boy should not steer anywhere")


func test_the_rope_lies_on_the_ground_when_the_boy_walks_around_the_planet() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var centre: Vector3 = planet.get_center()
	var up: Vector3 = player.get_up()
	var axis: Vector3 = up.cross(Vector3.UP)
	if axis.length_squared() < 0.01:
		axis = up.cross(Vector3.RIGHT)
	var direction: Vector3 = up.rotated(axis.normalized(), 1.0)
	player.global_position = centre + direction * (planet.radius + 0.3)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)
	player.rope.debug_advance(0.8)

	var points: PackedVector3Array = player.rope.get_rope_points()
	assert_gt(points.size(), 6, "a rope laid over the curve needs several segments")

	var lowest: float = INF
	for point: Vector3 in points:
		var radius: float = point.distance_to(centre)
		lowest = minf(lowest, radius)
		assert_gte(radius, planet.radius - 0.002, "the rope must never sink into the planet")
	assert_lt(
		lowest,
		planet.radius + RopeAnchor.ROPE_CLEARANCE + 0.04,
		"the rope should rest on the ground instead of cutting across the world"
	)


func test_the_rope_pulls_straight_when_the_boy_hangs_in_the_air() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 6.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)
	player.rope.debug_advance(1.2)

	var points: PackedVector3Array = player.rope.get_rope_points()
	assert_gte(points.size(), 4, "there should be a rope between the stake and the boy")
	var start: Vector3 = points[0]
	var finish: Vector3 = points[points.size() - 1]
	for point: Vector3 in points:
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(point, start, finish)
		assert_lt(point.distance_to(closest), 0.15, "a taut rope in the air should hang in a line")


func test_the_rope_never_jumps_to_the_far_side_of_the_planet() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var centre: Vector3 = planet.get_center()
	var stake_dir: Vector3 = (player.rope.get_anchor_position() - centre).normalized()
	var start_dir: Vector3 = player.get_up()
	var axis: Vector3 = stake_dir.cross(start_dir).normalized()
	if axis.length_squared() < 0.01:
		axis = stake_dir.cross(Vector3.RIGHT).normalized()

	var walked: float = 2.4
	for step: int in 12:
		var angle: float = walked * float(step + 1) / 12.0
		var direction: Vector3 = stake_dir.rotated(axis, angle)
		player.global_position = centre + direction * (planet.radius + 0.03)
		player.velocity = Vector3.ZERO
		await wait_physics_frames(1)
	player.rope.debug_advance(0.5)

	var highest: float = -INF
	var lowest: float = INF
	for point: Vector3 in player.rope.get_rope_points():
		var radius: float = point.distance_to(centre)
		assert_gte(radius, planet.radius - 0.002, "the rope must stay outside the planet")
		var turned: float = stake_dir.signed_angle_to((point - centre).normalized(), axis)
		highest = maxf(highest, turned)
		lowest = minf(lowest, turned)

	assert_gt(lowest, -0.15, "no part of the rope should snap around the far side")
	assert_lt(highest, walked + 0.3, "the rope should never wrap the wrong way round")


func test_the_stake_can_only_be_pulled_out_on_the_ground() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 3.0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)
	player.remove_stake()
	assert_true(player.rope.is_planted(), "the stake must stay tied while the boy is in the air")

	player.snap_to_surface()
	await wait_physics_frames(1)
	player.remove_stake()
	assert_false(player.rope.is_planted(), "a boy standing on the ground can pull the stake out")


func test_a_resting_rope_stays_where_it_was_laid() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	await wait_physics_frames(1)

	var centre: Vector3 = planet.get_center()
	var up: Vector3 = player.get_up()
	var axis: Vector3 = up.cross(Vector3.UP)
	if axis.length_squared() < 0.01:
		axis = up.cross(Vector3.RIGHT)
	player.global_position = centre + up.rotated(axis.normalized(), 0.5) * (planet.radius + 0.03)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(1)
	player.rope.debug_advance(1.0)

	var before: PackedVector3Array = player.rope.get_rope_points().duplicate()
	player.rope.debug_advance(0.6)
	var after: PackedVector3Array = player.rope.get_rope_points()

	assert_eq(before.size(), after.size(), "the rope should keep its shape")
	var drift: float = 0.0
	for index: int in before.size():
		drift = maxf(drift, before[index].distance_to(after[index]))
	assert_lt(drift, 0.05, "a rope resting on the ground should not creep or slide")


func test_hitting_the_rope_limit_is_a_soft_stop() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	player.plant_stake()
	var rope: RopeAnchor = player.rope
	var limit: float = rope.get_max_length()
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + limit + 0.5)
	player.velocity = up * 14.0

	player._apply_rope_limit()

	var recoil: float = player.velocity.dot(up)
	assert_lt(recoil, 0.0, "the rope should still stop the boy")
	assert_gt(recoil, -2.0, "a full speed jump should not be flung back down the rope")


func test_the_rope_is_tied_to_the_dukes_hand() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	player.plant_stake()
	await wait_physics_frames(6)

	var points: PackedVector3Array = player.rope.get_rope_points()
	var hand: Vector3 = player.get_hand_position()
	assert_gt(points.size(), 2, "there should be a rope to look at")
	assert_lt(
		points[points.size() - 1].distance_to(hand),
		0.12,
		"the loose end of the rope should sit in the duke's hand"
	)
	assert_gt(
		hand.y - player.global_position.y, 0.2, "the hand should be up the body, not at the boots"
	)
