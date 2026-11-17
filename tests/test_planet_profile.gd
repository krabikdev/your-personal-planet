extends GutTest

const START_RADIUS: float = PlanetProfile.BASE_RADIUS


func test_starting_planet_is_ten_boys_wide() -> void:
	assert_almost_eq(
		PlanetProfile.diameter_in_boys(PlanetProfile.BASE_RADIUS),
		10.0,
		0.01,
		"the starting planet should be half of the original twenty-boy diameter"
	)


func test_starting_jump_is_dangerous() -> void:
	assert_false(
		PlanetProfile.is_jump_safe(START_RADIUS),
		"the first jump on the tiny planet must be able to escape"
	)
	assert_gt(
		PlanetProfile.jump_speed(START_RADIUS),
		PlanetProfile.escape_velocity(START_RADIUS),
		"jump speed should exceed escape velocity at the start"
	)


func test_gravity_grows_with_planet() -> void:
	assert_gt(
		PlanetProfile.surface_gravity(START_RADIUS * 2.0),
		PlanetProfile.surface_gravity(START_RADIUS),
		"a bigger planet must pull harder"
	)
	assert_gt(
		PlanetProfile.escape_velocity(START_RADIUS * 2.0),
		PlanetProfile.escape_velocity(START_RADIUS),
		"escape velocity must also grow"
	)


func test_jump_height_falls_as_planet_grows() -> void:
	assert_gt(
		PlanetProfile.jump_height(START_RADIUS),
		PlanetProfile.jump_height(START_RADIUS * 2.0),
		"heavier planets make the same boy jump lower"
	)
	assert_gt(
		PlanetProfile.jump_height(START_RADIUS * 2.0), PlanetProfile.jump_height(START_RADIUS * 4.0)
	)


func test_there_is_a_safe_radius_and_it_is_reachable() -> void:
	var safe: float = PlanetProfile.safe_radius()
	assert_gt(safe, START_RADIUS + 1.0, "the planet must actually grow before it is safe")
	assert_lt(safe, START_RADIUS * 2.0, "the safe threshold should be reachable in a session")
	assert_true(PlanetProfile.is_jump_safe(safe), "at the safe radius jumps must return")
	assert_false(
		PlanetProfile.is_jump_safe(safe - 0.4), "just below the threshold the boy can still escape"
	)


func test_growth_is_large_at_first_then_diminishes() -> void:
	var big_first: float = PlanetProfile.growth_for_stone(START_RADIUS, 1.5)
	var small_first: float = PlanetProfile.growth_for_stone(START_RADIUS, 0.5)
	var big_later: float = PlanetProfile.growth_for_stone(START_RADIUS * 3.0, 1.5)
	assert_gt(big_first, 0.9, "the first big stone should visibly grow the planet")
	assert_lt(big_first, 1.6, "growth should stay gentle after the tuning pass")
	assert_gt(big_first, small_first, "bigger stones add more material")
	assert_gt(big_first, big_later, "the same stone should matter less on a big planet")
	assert_gt(big_later, 0.0, "growth never becomes negative")


func test_escape_velocity_formula() -> void:
	var gravity: float = PlanetProfile.surface_gravity(START_RADIUS)
	var escape: float = PlanetProfile.escape_velocity(START_RADIUS)
	assert_almost_eq(escape * escape, 2.0 * gravity * START_RADIUS, 0.01)


func test_cold_threshold_is_above_a_safe_jump() -> void:
	var safe_radius: float = PlanetProfile.safe_radius()
	var safe_jump: float = PlanetProfile.jump_height(safe_radius)
	assert_gt(
		PlanetProfile.cold_altitude(safe_radius),
		safe_jump,
		"a jump that falls back must not trigger the freeze"
	)
	assert_lt(
		PlanetProfile.cold_altitude(START_RADIUS),
		PlanetProfile.jump_height(START_RADIUS),
		"the escape jump should cross into the cold zone"
	)
