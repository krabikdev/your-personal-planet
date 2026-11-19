extends GutTest  # gdlint:ignore=max-public-methods

## The far side is a dry, dead place: yellow and brown plants of random size,
## tumbleweeds, bare oaks with hanging lianas, and the four monsters.

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_prop(kind: int, seed_value: int, level: int = 1) -> DecorProp:
	var prop := DecorProp.new()
	add_child_autofree(prop)
	prop.setup(kind, seed_value, level)
	return prop


func test_no_plant_shade_is_green() -> void:
	var palettes: Array[Array] = [
		DecorProp.DRY_COLORS, DecorProp.BARK_COLORS, DecorProp.LIANA_COLORS
	]
	for palette: Array in palettes:
		for color: Color in palette:
			var entry := color as Color
			assert_lt(entry.h, 0.17, "%s should stay in the straw-to-brown range" % entry.to_html())
			assert_lte(
				entry.b, entry.r, "%s must not drift towards green or blue" % entry.to_html()
			)


func test_decorations_roll_a_size_between_90_and_120_percent() -> void:
	var smallest: float = 2.0
	var largest: float = 0.0
	for i: int in 10:
		var prop: DecorProp = _make_prop(DecorProp.Kind.BUSH, 1200 + i)
		var scale_value: float = prop.get_size_scale()
		assert_between(scale_value, DecorProp.SCALE_MIN, DecorProp.SCALE_MAX)
		assert_almost_eq(
			prop.get_visual_scale(),
			scale_value * DecorProp.DECOR_SCALE,
			0.001,
			"the roll is doubled on its way to the world",
		)
		smallest = minf(smallest, scale_value)
		largest = maxf(largest, scale_value)
	assert_gt(largest - smallest, 0.05, "the rolls should actually differ from bush to bush")
	assert_almost_eq(
		DecorProp.DECOR_SCALE, 2.0, 0.001, "the far side is drawn twice its model size"
	)


func test_a_bush_is_a_ball_of_dry_twigs() -> void:
	var prop: DecorProp = _make_prop(DecorProp.Kind.BUSH, 77)
	assert_gte(prop.get_twig_count(), 30, "a tumbleweed is built from many little twigs")
	assert_gt(
		prop.get_mesh_parts(), prop.get_twig_count(), "twigs fork, so there are even more pieces"
	)


func test_the_bare_oaks_hang_yellow_lianas() -> void:
	var sapling: DecorProp = _make_prop(DecorProp.Kind.SAPLING, 5)
	assert_gte(sapling.get_liana_count(), 5, "even a young oak has lianas")
	var tree: DecorProp = _make_prop(DecorProp.Kind.TREE, 6)
	assert_gte(tree.get_liana_count(), 8, "a full oak is heavy with them")
	assert_gt(tree.get_mesh_parts(), 30, "the crown is built from many forked branches")


func test_the_big_oak_grows_flat_platforms_to_climb() -> void:
	var bodies: Dictionary[int, bool] = {}
	for seed_value: int in [909, 71, 404, 1234, 55]:
		var prop: DecorProp = _make_prop(DecorProp.Kind.BIG_TREE, seed_value)
		var count: int = prop.get_platform_count()
		assert_between(count, 5, 10, "a big oak needs five to ten pads")

		var heights: Array[float] = prop.get_platform_heights()
		for i: int in range(1, heights.size()):
			assert_gt(heights[i], heights[i - 1], "the pads climb like a staircase")
			assert_lt(
				heights[i] - heights[i - 1],
				0.85,
				"each pad is one charged jump above the one below it",
			)
		for i: int in range(1, count):
			var previous: Vector3 = prop.get_platform_point(i - 1)
			var current: Vector3 = prop.get_platform_point(i)
			var gap: float = (
				previous.distance_to(current)
				- prop.get_platform_radius(i - 1)
				- prop.get_platform_radius(i)
			)
			assert_gt(gap, 0.2, "no pad may sit in the duke's head while he stands on another")

		var body: StaticBody3D = prop.get_platform_collider()
		assert_not_null(body, "the pads must be walkable")
		assert_eq(body.get_child_count(), count, "every pad gets its own collider")
		assert_eq(body.collision_layer, 1, "the duke stands on layer one")
		for child: Node in body.get_children():
			var holder := child as CollisionShape3D
			assert_not_null(holder, "a collider needs a shape holder")
			assert_not_null(holder.shape, "the holder needs a shape")
		bodies[body.get_instance_id()] = true
	assert_eq(bodies.size(), 5)


func test_each_level_brings_its_own_monster() -> void:
	var names: Dictionary[String, bool] = {}
	var previous_scale: float = 0.0
	for level: int in 4:
		var monster: DecorProp = _make_prop(DecorProp.Kind.MONSTER, 400 + level, level + 1)
		var monster_name: String = monster.get_monster_name()
		assert_false(monster_name.is_empty(), "every monster should have a name")
		assert_false(names.has(monster_name), "the four monsters must look different")
		names[monster_name] = true
		assert_gt(monster.get_visual_scale(), previous_scale, "the levels get bigger")
		previous_scale = monster.get_visual_scale()
	assert_eq(names.size(), 4)
	assert_gt(previous_scale, 1.8, "the fourth one is a monster the size of a house")


func test_the_duke_can_stand_on_a_big_oak_platform() -> void:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	spawner.debug_spawn_all()
	await wait_process_frames(2)

	var tree: DecorProp = null
	for prop: DecorProp in spawner.get_props():
		if prop.kind == DecorProp.Kind.BIG_TREE:
			tree = prop
	assert_not_null(tree, "the debug garden should hold a big oak")

	var point: Vector3 = tree.get_platform_point(1)
	var up: Vector3 = (point - planet.get_center()).normalized()
	player.global_position = point + up * 0.6
	player.velocity = Vector3.ZERO
	await wait_physics_frames(80)

	assert_true(player.is_on_floor(), "the pads are solid ground, not decoration")
	var pad_altitude: float = point.distance_to(planet.get_center()) - planet.radius
	assert_almost_eq(
		player.get_altitude(),
		pad_altitude,
		0.4,
		"he should be standing on the oak pad, not on the ground below it",
	)


func test_a_tree_trunk_is_solid() -> void:
	for kind: int in [DecorProp.Kind.SAPLING, DecorProp.Kind.TREE, DecorProp.Kind.BIG_TREE]:
		var prop: DecorProp = _make_prop(kind, 330 + kind)
		var body: StaticBody3D = prop.get_trunk_collider()
		assert_not_null(body, "kind %d needs a solid trunk" % kind)
		assert_eq(body.get_child_count(), 1)
		assert_eq(body.collision_layer, 1, "the duke collides on layer one")
		var holder := body.get_child(0) as CollisionShape3D
		assert_not_null(holder)
		var shape := holder.shape as CylinderShape3D
		assert_not_null(shape, "the trunk is a simple round post")
		assert_gt(shape.radius, 0.05, "the post must be thick enough to block him")
		assert_gt(shape.height, 1.0, "and reach up towards the branches")


func test_the_duke_cannot_walk_into_a_trunk() -> void:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	spawner.debug_spawn_all()
	await wait_process_frames(2)

	var tree: DecorProp = null
	for prop: DecorProp in spawner.get_props():
		if prop.kind == DecorProp.Kind.TREE:
			tree = prop
	assert_not_null(tree)
	var up: Vector3 = (tree.global_position - planet.get_center()).normalized()
	player.global_position = tree.global_position + up * 0.2
	player.velocity = Vector3.ZERO
	await wait_physics_frames(30)

	var offset: Vector3 = player.global_position - tree.global_position
	offset -= up * offset.dot(up)
	assert_gt(
		offset.length(),
		tree.get_trunk_radius() * 0.9,
		"the trunk should push him out instead of letting him stand inside it",
	)


func test_the_far_side_still_appears_on_a_500_metre_planet() -> void:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	planet.apply_radius(500.0)
	player.snap_to_surface()
	await wait_process_frames(2)

	assert_lte(
		spawner.get_region_radius(), 22.1, "the patch must stay small enough to find on foot"
	)
	assert_lte(spawner.get_spawn_distance(), 60.1, "and close enough to walk to")

	var prop: DecorProp = spawner.spawn_one()
	assert_not_null(prop, "a huge planet should still receive decorations")
	var distance: float = prop.global_position.distance_to(player.global_position)
	assert_lt(distance, 100.0, "an arrival must not land a kilometre away")


func test_a_growing_planet_keeps_a_cluster_together() -> void:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_process_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	spawner.debug_spawn_all()
	await wait_process_frames(2)

	var props: Array[DecorProp] = spawner.get_props()
	var centre: DecorProp = props[4]
	var neighbour: DecorProp = props[2]
	var before: float = centre.global_position.distance_to(neighbour.global_position)
	planet.apply_radius(40.0)
	await wait_process_frames(2)
	var after: float = centre.global_position.distance_to(neighbour.global_position)

	assert_lt(
		absf(after - before),
		0.5,
		"the cluster should keep its real size instead of stretching with the planet",
	)
	assert_almost_eq(
		neighbour.global_position.distance_to(planet.get_center()),
		planet.radius,
		0.05,
		"and everything still stands on the new surface",
	)
