extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	return game


func test_holding_space_charges_the_jump_on_the_ground() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	Input.action_press("jump")
	await wait_physics_frames(30)

	assert_true(player.is_charging(), "holding Space loads the jump")
	assert_true(player.is_on_floor(), "the boy must not leave the ground while charging")
	assert_almost_eq(player.get_jump_charge(), 0.5, 0.06, "half a second is half a charge")

	Input.action_release("jump")
	await wait_physics_frames(1)
	assert_false(player.is_charging(), "releasing fires the jump")


func test_a_short_charge_is_a_small_hop() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var full: float = player.planet.get_jump_speed()
	Input.action_press("jump")
	await wait_physics_frames(9)
	Input.action_release("jump")
	await wait_physics_frames(1)

	var speed: float = player.velocity.dot(player.get_up())
	assert_gt(speed, 0.5, "a tap still leaves the ground")
	assert_lt(speed, full * 0.7, "a short hold must stay a small hop")


func test_a_two_second_charge_reaches_the_full_jump() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)

	var player: Boy = game.get_node("Player") as Boy
	var full: float = player.planet.get_jump_speed()
	Input.action_press("jump")
	await wait_physics_frames(121)
	Input.action_release("jump")
	await wait_physics_frames(1)

	var speed: float = player.velocity.dot(player.get_up())
	assert_almost_eq(
		speed, full, full * 0.12, "two seconds of holding should reach the advertised jump"
	)


func test_coyote_time_survives_walking_off_a_ledge() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 0.5)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(2)
	player._coyote = 0.06
	Input.action_press("jump")
	await wait_physics_frames(1)
	Input.action_release("jump")
	await wait_physics_frames(1)

	assert_gt(
		player.velocity.dot(player.get_up()),
		0.5,
		"a jump just after leaving the ground should still fire",
	)


func test_close_to_the_ground_counts_as_grounded_for_jumping() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 0.1)
	player.velocity = up * 1.0
	await wait_physics_frames(2)
	assert_false(player.is_on_floor(), "setup: close to the ground but airborne")
	player._coyote = 0.0
	Input.action_press("jump")
	await wait_physics_frames(1)
	Input.action_release("jump")

	assert_gt(
		player.velocity.dot(player.get_up()),
		0.5,
		"being a hand above the ground should not eat the jump",
	)


func test_a_jump_pressed_just_before_landing_fires_on_touchdown() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var up: Vector3 = player.get_up()
	player.global_position = planet.get_center() + up * (planet.radius + 0.4)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(9)
	Input.action_press("jump")
	await wait_physics_frames(1)
	Input.action_release("jump")
	player.snap_to_surface()
	await wait_physics_frames(1)

	assert_gt(
		player.velocity.dot(player.get_up()),
		0.5,
		"a jump pressed just before landing should fire on touchdown",
	)
