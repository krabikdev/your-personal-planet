extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func test_gravity_stops_growing_on_huge_planets() -> void:
	var small: float = PlanetProfile.surface_gravity(PlanetProfile.BASE_RADIUS)
	var huge: float = PlanetProfile.surface_gravity(200.0)
	assert_gt(huge, small, "a bigger world should still feel heavier")
	assert_lte(huge, PlanetProfile.MAX_GRAVITY + 0.001, "gravity must stop climbing somewhere")
	assert_lte(
		PlanetProfile.surface_gravity(PlanetProfile.MAX_RADIUS),
		PlanetProfile.MAX_GRAVITY + 0.001,
		"the heaviest world the game can build must be capped too"
	)


func test_a_jump_on_a_huge_planet_stays_controllable() -> void:
	assert_gte(PlanetProfile.jump_height(200.0), 1.0, "the boy should still clear one boy height")
	assert_lt(
		PlanetProfile.jump_speed(200.0),
		12.0,
		"a capped gravity must not launch him at sixty metres a second",
	)


func test_the_fall_speed_is_capped() -> void:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_physics_frames(1)

	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	planet.apply_radius(200.0)
	player.velocity = Vector3.ZERO

	player._apply_gravity(player.get_up(), 30.0)
	var falling: float = -player.velocity.dot(player.get_up())
	assert_almost_eq(falling, Boy.MAX_FALL_SPEED, 0.01, "a long fall should settle on one speed")


func _walk_sample(radius: float) -> Dictionary:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_physics_frames(1)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var model: PrinceModel = player._model
	planet.apply_radius(radius)
	player.snap_to_surface()
	await wait_physics_frames(1)

	var skeleton: Skeleton3D = model._skeleton
	var bone: int = skeleton.find_bone("leg_L_tip")
	var last: Vector3 = skeleton.get_global_transform() * skeleton.get_bone_global_pose(bone).origin
	var steps: Array[float] = []
	var flips: int = 0
	var was_grounded: bool = model._grounded
	Input.action_press("move_forward")
	for _frame: int in 18:
		await wait_physics_frames(1)
		var now: Vector3 = (
			skeleton.get_global_transform() * skeleton.get_bone_global_pose(bone).origin
		)
		steps.append(now.distance_to(last))
		last = now
		if model._grounded != was_grounded:
			flips += 1
			was_grounded = model._grounded
	Input.action_release("move_forward")

	steps.sort()
	return {
		"p90": steps[int(steps.size() * 0.9)],
		"max": steps[steps.size() - 1],
		"flips": flips,
	}


func test_the_walk_is_as_steady_on_a_200_metre_planet_as_at_home() -> void:
	var home: Dictionary = await _walk_sample(PlanetProfile.BASE_RADIUS)
	var giant: Dictionary = await _walk_sample(200.0)

	assert_lte(home["flips"], 2, "walking at home should not lose the floor")
	assert_lte(giant["flips"], 2, "walking on a huge planet should not lose the floor either")
	assert_lt(
		float(giant["p90"]),
		float(home["p90"]) * 1.35,
		"the stride on a huge planet should match the stride at home",
	)
	assert_lt(
		float(giant["max"]),
		float(home["max"]) * 1.6,
		"a huge planet must not make the foot snap between frames",
	)
