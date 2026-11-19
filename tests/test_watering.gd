extends GutTest  # gdlint:ignore=max-public-methods

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	return game


## The bag only opens with both feet on the ground, so tests wait for the boy
## to actually land on the little planet first.
func _wait_for_ground(player: Boy) -> void:
	for _i: int in 24:
		if player.is_on_floor():
			return
		await wait_physics_frames(1)


func test_ice_melts_into_the_watering_can() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var model: InventoryModel = game.get_inventory_model()
	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	game._on_skeleton_item_picked(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_stone(StoneItem.Kind.ICE, 1.2)
	var radius_before: float = planet.radius
	var ice_index: int = model.size() - 1

	game.debug_open_inventory()
	game.debug_melt_ice(ice_index)

	assert_almost_eq(model.water, 1.2, 0.001, "the ice should become the same amount of water")
	assert_eq(model.size(), 1, "only the can is left in the bag")
	assert_almost_eq(planet.radius, radius_before, 0.001, "melting ice must not grow the planet")


func test_ice_without_the_can_stays_in_the_bag() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var model: InventoryModel = game.get_inventory_model()
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	game.debug_grant_stone(StoneItem.Kind.ICE, 1.0)
	game.debug_open_inventory()
	game.debug_melt_ice(0)

	assert_eq(model.size(), 1, "with no can the ice cannot melt")
	assert_almost_eq(model.water, 0.0, 0.001)


func test_watering_spends_one_unit_of_water_each_second() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var model: InventoryModel = game.get_inventory_model()
	var player: Boy = game.get_node("Player") as Boy

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(3.0)
	Input.action_press("interact")
	await wait_process_frames(30)
	Input.action_release("interact")
	await wait_process_frames(2)

	assert_almost_eq(model.water, 2.5, 0.08, "half a second of pouring spends half a unit")
	assert_false(player.is_watering(), "letting go puts the can away")


func test_the_can_shows_in_his_hand_only_while_pouring() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var can: Node3D = player._model.find_child("WateringCan", true, false) as Node3D
	assert_not_null(can, "the duke should carry a can")
	assert_false(can.visible, "the can is out of sight while he walks")

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(2.0)
	Input.action_press("interact")
	await wait_process_frames(8)
	assert_true(player.is_watering(), "holding the button pours")
	assert_true(can.visible, "the can appears in his hand")

	Input.action_release("interact")
	await wait_process_frames(2)
	assert_false(can.visible, "and disappears when he stops")


func test_the_hud_shows_how_much_water_is_left() -> void:
	var game: Game = _make_game()
	await wait_process_frames(1)
	var label: Label = game._hud.get_node("%WaterLabel") as Label
	assert_not_null(label, "the HUD should have a can gauge")
	assert_false(label.visible, "no can means no gauge")

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(2.0)
	assert_true(label.visible)
	assert_string_contains(label.text, "2.0")


## Pours for a stretch of game time without waiting out real frames: the
## watering loop is the thing under test, not the renderer.
func _pour(game: Game, seconds: float) -> void:
	var steps: int = ceili(seconds * 60.0)
	for _i: int in steps:
		game._update_watering(1.0 / 60.0)


func test_a_stalk_needs_three_seconds_of_watering_before_it_shows() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var garden: Garden = game.get_garden()
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(8.0)
	Input.action_press("interact")
	_pour(game, 2.5)
	assert_eq(garden.get_plant_count(), 0, "two and a half seconds only soak the dust")

	_pour(game, 0.6)
	assert_eq(garden.get_plant_count(), 1, "three unbroken seconds sprout a stalk")
	Input.action_release("interact")


func test_letting_go_starts_the_three_seconds_again() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var garden: Garden = game.get_garden()
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(8.0)
	Input.action_press("interact")
	_pour(game, 2.5)
	Input.action_release("interact")
	game._update_watering(1.0 / 60.0)

	Input.action_press("interact")
	_pour(game, 2.0)
	assert_eq(garden.get_plant_count(), 0, "the break throws the count away")

	_pour(game, 1.1)
	assert_eq(garden.get_plant_count(), 1, "a fresh three seconds still sprouts it")
	Input.action_release("interact")


func test_a_new_stalk_announces_itself() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var garden: Garden = game.get_garden()
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	var heard: Array[PumpkinPlant] = []
	garden.sprouted.connect(func(plant: PumpkinPlant) -> void: heard.append(plant))
	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(8.0)
	Input.action_press("interact")
	_pour(game, 3.4)
	Input.action_release("interact")

	assert_eq(heard.size(), 1, "a fresh stalk should be heard once, when it appears")
	assert_eq(heard[0], garden.get_plants()[0], "and it is the stalk that just sprouted")


func test_a_watered_stalk_grows_its_head_and_chimes() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var garden: Garden = game.get_garden()
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(8.0)
	Input.action_press("interact")
	_pour(game, 3.4)
	var plant: PumpkinPlant = garden.get_plants()[0]
	assert_false(plant.is_mature(), "a fresh stalk still has growing to do")

	_pour(game, 2.6)
	Input.action_release("interact")
	assert_true(plant.is_mature(), "2.5 more water finish the pumpkin head")


func test_holding_the_can_runs_the_quiet_pour_loop() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	await _wait_for_ground(player)

	assert_false(player.is_pour_loop_playing(), "the can is quiet until it is used")
	player.set_watering(true)
	assert_true(player.is_pour_loop_playing(), "holding the can starts the trickle")
	player.set_watering(false)
	assert_false(player.is_pour_loop_playing(), "letting go stops it again")


func test_the_garden_sounds_are_shipped() -> void:
	for key: String in ["sprout", "mature", "water_pour"]:
		assert_true(AudioDirector.SFX_PATHS.has(key), "%s should be registered" % key)
		var stream: AudioStream = load(AudioDirector.SFX_PATHS[key]) as AudioStream
		assert_not_null(stream, "%s should load" % key)
		assert_gt(stream.get_length(), 0.2, "%s should be a real sound" % key)


func test_watering_sprouts_a_plant_in_front_of_the_duke() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var garden: Garden = game.get_garden()
	await _wait_for_ground(player)

	game.debug_grant_stone(StoneItem.Kind.WATERING_CAN)
	game.debug_grant_water(8.0)
	Input.action_press("interact")
	_pour(game, 3.2)
	Input.action_release("interact")

	assert_eq(garden.get_plant_count(), 1, "a stalk should grow where the water lands")
	var plant: PumpkinPlant = garden.get_plants()[0]
	var forward: Vector3 = -player.global_transform.basis.z
	var offset: Vector3 = plant.global_position - player.global_position
	assert_gt(offset.length(), 0.3, "the sprout should not be under his feet")
	assert_gt(offset.normalized().dot(forward), 0.45, "the sprout should be in front of him")
	assert_gt(plant.get_progress(), 0.0, "poured water should already grow it")


func test_each_unit_of_water_skips_two_minutes_of_growth() -> void:
	assert_eq(PumpkinPlant.GROWTH_SECONDS, 300.0, "a stalk needs five minutes of time")
	assert_eq(PumpkinPlant.SECONDS_PER_WATER, 120.0, "one unit is a two-minute shortcut")


func test_two_and_a_half_units_grow_a_pumpkin_head() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var planet: Planet = game.get_node("Planet") as Planet
	var garden: Garden = game.get_garden()
	var spot: Vector3 = planet.get_center() + Vector3.UP * planet.radius
	var plant: PumpkinPlant = garden.pour(spot, 0.1)
	assert_not_null(plant, "pouring onto bare ground makes a sprout")
	var before: float = plant.get_growth_seconds()

	plant.water(1.0)
	assert_almost_eq(plant.get_growth_seconds() - before, 120.0, 0.01, "one unit is two minutes")
	assert_false(plant.is_mature(), "one unit is not enough")

	plant.water(1.4)
	assert_true(plant.is_mature(), "enough water finishes the five minutes")
	assert_eq(plant.get_progress(), 1.0)
	assert_true(plant._head.visible, "the stalk has grown its pumpkin head")


func test_a_mature_head_spits_acid_at_a_monster_it_can_see() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var planet: Planet = game.get_node("Planet") as Planet
	var garden: Garden = game.get_garden()
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var spot: Vector3 = planet.get_center() + Vector3.UP * planet.radius
	var plant: PumpkinPlant = garden.pour(spot, 2.5)
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 1)
	monster.global_position = plant.get_head_position() + Vector3(3.0, 0.0, 0.0)

	var blob: AcidBlob = plant.debug_attack_now()
	assert_not_null(blob, "a monster three metres away is inside the ten-metre gaze")
	blob.debug_reach()
	assert_true(monster.is_queued_for_deletion(), "the acid dissolves the monster")


func test_a_head_ignores_monsters_outside_ten_metres() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var planet: Planet = game.get_node("Planet") as Planet
	var garden: Garden = game.get_garden()
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var spot: Vector3 = planet.get_center() + Vector3.UP * planet.radius
	var plant: PumpkinPlant = garden.pour(spot, 2.5)
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 1)
	monster.global_position = plant.get_head_position() + Vector3(11.0, 0.0, 0.0)

	assert_null(plant.debug_attack_now(), "eleven metres is too far to spit")


func test_the_plant_rides_the_growing_planet() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var planet: Planet = game.get_node("Planet") as Planet
	var garden: Garden = game.get_garden()
	var center: Vector3 = planet.get_center()
	var plant: PumpkinPlant = garden.pour(center + Vector3.UP * planet.radius, 0.5)

	planet.apply_radius(planet.radius + 1.0)
	await wait_process_frames(1)

	assert_almost_eq(
		plant.global_position.distance_to(center),
		planet.radius,
		0.02,
		"the stalk keeps its spot but follows the higher ground"
	)
