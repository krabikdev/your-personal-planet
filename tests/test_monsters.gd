extends GutTest  # gdlint:ignore=max-public-methods

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child_autofree(game)
	return game


func test_the_duke_starts_with_a_hundred_health() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var player: Boy = game.get_node("Player") as Boy

	assert_eq(player.get_max_health(), 100.0)
	assert_eq(player.get_health(), 100.0)


func test_damage_lowers_health_and_zero_ends_the_run() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var player: Boy = game.get_node("Player") as Boy

	player.take_damage(30.0)
	assert_almost_eq(player.get_health(), 70.0, 0.001)
	assert_false(player.dead, "thirty points is not fatal")

	player.take_damage(70.0)
	assert_almost_eq(player.get_health(), 0.0, 0.001)
	assert_true(player.dead, "the duke freezes when his health runs out")


func test_health_regenerates_one_point_every_ten_seconds() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var player: Boy = game.get_node("Player") as Boy

	player.debug_set_health(60.0)
	player.debug_tick_health(9.9)
	assert_eq(player.get_health(), 60.0, "nine point nine seconds is not enough")

	player.debug_tick_health(0.2)
	assert_eq(player.get_health(), 61.0, "the tenth second heals one point")

	player.debug_tick_health(30.0)
	assert_eq(player.get_health(), 64.0, "three more intervals heal three more points")


func test_each_monster_has_its_own_reach_and_bite() -> void:
	assert_eq(DecorProp.aggro_radius_for_level(1), 5.0)
	assert_eq(DecorProp.aggro_radius_for_level(2), 10.0)
	assert_eq(DecorProp.aggro_radius_for_level(3), 15.0)
	assert_eq(DecorProp.aggro_radius_for_level(4), 20.0)

	assert_eq(DecorProp.contact_damage_for_level(1), 1.0)
	assert_eq(DecorProp.contact_damage_for_level(2), 2.0)
	assert_eq(DecorProp.contact_damage_for_level(3), 3.0)
	assert_eq(DecorProp.contact_damage_for_level(4), 4.0)


func test_a_monster_chases_the_duke_inside_its_reach() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 1)

	monster.debug_place_near(player.global_position, 3.0)
	var before: float = monster.global_position.distance_to(player.global_position)
	monster.debug_step(0.3)

	assert_eq(monster.get_state(), DecorProp.State.CHASE, "three metres is inside five")
	var after: float = monster.global_position.distance_to(player.global_position)
	assert_lt(after, before - 0.1, "a chase must close the distance")


func test_a_level_one_monster_ignores_the_duke_at_six_metres() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 1)

	monster.debug_place_near(player.global_position, 6.0)
	monster.debug_step(0.3)

	assert_ne(monster.get_state(), DecorProp.State.CHASE, "six metres is outside its five")


func test_a_level_four_monster_chases_from_eighteen_metres() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 4)

	monster.debug_place_near(player.global_position, 18.0)
	monster.debug_step(0.4)

	assert_eq(monster.get_state(), DecorProp.State.CHASE, "the fourth monster sees twenty")


func test_a_monster_wanders_then_rests_then_wanders_again() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 1)
	monster.debug_place_near(player.global_position, 12.0)

	var start: Vector3 = monster.global_position
	monster.debug_step(2.0)
	assert_eq(monster.get_state(), DecorProp.State.WANDER)
	assert_gt(monster.global_position.distance_to(start), 0.5, "wandering actually covers ground")

	monster.debug_step(4.0)
	assert_eq(monster.get_state(), DecorProp.State.REST, "five seconds of walking, then a rest")
	var resting_at: Vector3 = monster.global_position
	monster.debug_step(0.5)
	assert_eq(monster.get_state(), DecorProp.State.REST, "the rest lasts at least five seconds")
	assert_lt(monster.global_position.distance_to(resting_at), 0.001, "it stands still")

	var waited: float = 0.0
	while monster.get_state() != DecorProp.State.WANDER and waited < 16.0:
		monster.debug_step(0.5)
		waited += 0.5
	assert_eq(monster.get_state(), DecorProp.State.WANDER, "after the rest it walks again")


func test_a_touching_monster_bites_for_its_level() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(3)
	var player: Boy = game.get_node("Player") as Boy
	var spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
	var monster: DecorProp = spawner.debug_spawn_monster(Vector3.UP, 3)

	monster.debug_place_near(player.global_position, 0.0)
	var before: float = player.get_health()
	monster.debug_step(1.0)

	assert_almost_eq(monster.get_contact_damage(), 3.0, 0.001)
	assert_almost_eq(
		player.get_health(), before - 3.0, 0.2, "the third monster bites three a second"
	)


func test_every_monster_dies_with_its_own_sound() -> void:
	var keys: Dictionary[String, bool] = {}
	for level: int in [1, 2, 3, 4]:
		var key: String = DecorProp.death_sound_for_level(level)
		assert_true(AudioDirector.SFX_PATHS.has(key), "%s should be registered" % key)
		var stream: AudioStream = load(AudioDirector.SFX_PATHS[key]) as AudioStream
		assert_not_null(stream, "%s should load" % key)
		assert_gt(stream.get_length(), 0.4, "%s should be a real death cry" % key)
		keys[key] = true
	assert_eq(keys.size(), 4, "each of the four monsters needs its own death sound")


func test_the_health_bar_sits_above_the_inventory_hint() -> void:
	var game: Game = _make_game()
	await wait_process_frames(2)
	var bar: HealthBar = game._hud.get_node("%HealthBar") as HealthBar
	var button: Button = game._hud.get_node("%InventoryButton") as Button
	var root: Control = game._hud.get_node("Root") as Control

	assert_not_null(bar, "the HUD should have a health bar")
	assert_almost_eq(bar.get_value(), 100.0, 0.001)
	assert_gt(bar.size.x, 100.0, "the bar is wide enough to read")
	assert_lt(
		bar.get_global_rect().position.y,
		button.get_global_rect().position.y,
		"the health bar sits above the bag hint"
	)
	assert_gt(
		bar.get_global_rect().get_center().x,
		root.size.x * 0.5,
		"the health bar lives in the top right corner"
	)


func test_damage_shows_up_on_the_health_bar() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var bar: HealthBar = game._hud.get_node("%HealthBar") as HealthBar

	player.take_damage(40.0)
	await wait_process_frames(1)

	assert_almost_eq(bar.get_value(), 60.0, 0.001, "the bar follows the real health")
	assert_eq(bar.get_maximum(), 100.0)
