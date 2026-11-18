extends GutTest  # gdlint:ignore=max-public-methods

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	return game


func test_spawn_interval_starts_at_ten_minutes() -> void:
	assert_almost_eq(
		FarSideSpawner.interval_for_size(20.0), 600.0, 0.01, "the far side starts at 600 s"
	)
	assert_almost_eq(
		FarSideSpawner.interval_for_size(10.0),
		600.0,
		0.01,
		"a planet below size 20 keeps the slowest cadence"
	)


func test_spawn_interval_reaches_one_second_at_size_1000() -> void:
	assert_almost_eq(
		FarSideSpawner.interval_for_size(1000.0), 1.0, 0.001, "a huge planet spawns every second"
	)
	assert_almost_eq(
		FarSideSpawner.interval_for_size(2000.0), 1.0, 0.001, "the wait never drops below 1 s"
	)


func test_spawn_interval_shrinks_without_jumping() -> void:
	var previous: float = FarSideSpawner.interval_for_size(20.0)
	for size: float in [40.0, 80.0, 160.0, 320.0, 640.0, 1000.0]:
		var current: float = FarSideSpawner.interval_for_size(size)
		assert_lt(current, previous, "the wait should shorten as the planet grows")
		previous = current


func test_size_20_to_50_is_mostly_grass() -> void:
	var table: Array[Dictionary] = FarSideSpawner.spawn_table_for_size(30.0)
	assert_eq(table.size(), 2, "early on only grass and one monster exist")
	assert_eq(table[0]["kind"], FarSideSpawner.Kind.GRASS)
	assert_almost_eq(float(table[0]["weight"]), 80.0, 0.01)
	assert_eq(table[1]["kind"], FarSideSpawner.Kind.MONSTER)
	assert_eq(int(table[1]["count"]), 1)
	assert_almost_eq(float(table[1]["weight"]), 20.0, 0.01)


func test_size_50_to_200_adds_bushes_and_monster_pairs() -> void:
	var table: Array[Dictionary] = FarSideSpawner.spawn_table_for_size(100.0)
	assert_eq(table.size(), 4)
	assert_eq(table[0]["kind"], FarSideSpawner.Kind.GRASS)
	assert_almost_eq(float(table[0]["weight"]), 50.0, 0.01)
	assert_eq(table[1]["kind"], FarSideSpawner.Kind.BUSH)
	assert_almost_eq(float(table[1]["weight"]), 25.0, 0.01)
	assert_eq(table[2]["kind"], FarSideSpawner.Kind.MONSTER)
	assert_eq(int(table[2]["count"]), 1)
	assert_eq(table[3]["kind"], FarSideSpawner.Kind.MONSTER)
	assert_eq(int(table[3]["count"]), 2)
	assert_almost_eq(float(table[3]["weight"]), 5.0, 0.01)


func test_size_200_to_500_adds_a_sapling() -> void:
	var table: Array[Dictionary] = FarSideSpawner.spawn_table_for_size(300.0)
	assert_eq(table.size(), 6)
	assert_eq(table[2]["kind"], FarSideSpawner.Kind.SAPLING)
	assert_eq(int(table[2]["count"]), 1)
	assert_almost_eq(float(table[2]["weight"]), 5.0, 0.01)
	assert_eq(int(table[5]["count"]), 3, "three monsters become possible")


func test_size_500_and_up_adds_trees_and_four_monsters() -> void:
	var table: Array[Dictionary] = FarSideSpawner.spawn_table_for_size(600.0)
	assert_eq(table.size(), 8)
	assert_eq(table[3]["kind"], FarSideSpawner.Kind.TREE)
	assert_almost_eq(float(table[3]["weight"]), 5.0, 0.01)
	assert_eq(int(table[7]["count"]), 4)
	assert_almost_eq(float(table[7]["weight"]), 5.0, 0.01)
	var total: float = 0.0
	for entry: Dictionary in table:
		total += float(entry["weight"])
	assert_almost_eq(total, 100.0, 0.01, "the weights should fill the whole group")


func test_the_roll_respects_the_weights() -> void:
	var early_monster: Dictionary = FarSideSpawner.roll_spawn(30.0, 0.85)
	assert_eq(early_monster["kind"], FarSideSpawner.Kind.MONSTER)
	var early_grass: Dictionary = FarSideSpawner.roll_spawn(30.0, 0.2)
	assert_eq(early_grass["kind"], FarSideSpawner.Kind.GRASS)

	var bush: Dictionary = FarSideSpawner.roll_spawn(100.0, 0.6)
	assert_eq(bush["kind"], FarSideSpawner.Kind.BUSH)
	var pair: Dictionary = FarSideSpawner.roll_spawn(100.0, 0.97)
	assert_eq(pair["kind"], FarSideSpawner.Kind.MONSTER)
	assert_eq(int(pair["count"]), 2)

	var sapling: Dictionary = FarSideSpawner.roll_spawn(300.0, 0.45)
	assert_eq(sapling["kind"], FarSideSpawner.Kind.SAPLING)
	var tree: Dictionary = FarSideSpawner.roll_spawn(600.0, 0.46)
	assert_eq(tree["kind"], FarSideSpawner.Kind.TREE)
	var four: Dictionary = FarSideSpawner.roll_spawn(600.0, 0.97)
	assert_eq(int(four["count"]), 4)


func test_nothing_spawns_on_the_starting_empty_planet() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)

	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	assert_not_null(spawner, "the game should own the far side spawner")
	assert_eq(spawner.get_prop_count(), 0, "the far side starts bare")
	assert_gt(spawner.get_time_left(), 500.0, "the first far side object is minutes away")


func test_far_side_objects_land_opposite_the_boy() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)

	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var player: Boy = game.get_node("Player") as Boy
	var planet: Planet = game.get_node("Planet") as Planet
	var prop: DecorProp = spawner.spawn_one()
	assert_not_null(prop, "the spawner should place something")
	await wait_process_frames(1)

	var direction: Vector3 = (prop.global_position - planet.get_center()).normalized()
	assert_lt(
		direction.dot(player.get_up()),
		-0.4,
		"objects should appear on the opposite side of the planet"
	)
	assert_almost_eq(
		prop.global_position.distance_to(planet.get_center()),
		planet.radius,
		0.05,
		"objects should sit on the surface"
	)


func test_the_spawn_area_grows_with_the_planet() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)

	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var planet: Planet = game.get_node("Planet") as Planet
	var before: float = spawner.get_region_radius()
	planet.apply_radius(planet.radius * 2.0)
	await wait_process_frames(1)
	assert_almost_eq(
		spawner.get_region_radius(), before * 2.0, 0.01, "the area should grow with it"
	)


func test_growing_the_planet_keeps_the_props_size_and_spot() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)

	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var planet: Planet = game.get_node("Planet") as Planet
	var prop: DecorProp = spawner.spawn_one()
	assert_not_null(prop)
	var direction: Vector3 = prop.anchor_dir
	var size_before: Vector3 = prop.scale

	planet.apply_radius(planet.radius + 4.0)
	await wait_process_frames(1)

	assert_eq(prop.scale, size_before, "props must never be scaled by the growing planet")
	assert_almost_eq(
		prop.global_position.distance_to(planet.get_center()),
		planet.radius,
		0.05,
		"the prop should ride the new surface"
	)
	var kept: Vector3 = (prop.global_position - planet.get_center()).normalized()
	assert_gt(kept.dot(direction), 0.999, "the prop should keep its spot on the sphere")


func test_the_debug_garden_holds_every_kind() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)

	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	spawner.debug_spawn_all()
	await wait_process_frames(2)

	var props: Array[DecorProp] = spawner.get_props()
	assert_eq(props.size(), 8, "the debug garden should hold one of each kind plus monsters")
	var monsters: int = 0
	var trees: int = 0
	for prop: DecorProp in props:
		if prop.kind == FarSideSpawner.Kind.MONSTER:
			monsters += 1
		if prop.kind == FarSideSpawner.Kind.BIG_TREE:
			trees += 1
	assert_eq(monsters, 3, "the garden should show a few monsters")
	assert_eq(trees, 1, "the garden should show a big tree")
