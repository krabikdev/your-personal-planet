extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_player() -> Boy:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	await wait_physics_frames(1)
	return game.get_node("Player") as Boy


func test_the_two_feet_use_two_different_samples() -> void:
	var player: Boy = await _make_player()

	player._on_footstepped(0)
	var left: String = player._audio.stream.resource_path
	player._on_footstepped(1)
	var right: String = player._audio.stream.resource_path

	assert_string_contains(left, "footstep_1", "the left foot should have its own sample")
	assert_string_contains(right, "footstep_2", "the right foot should have its own sample")
	assert_ne(left, right, "both feet sharing one sound is what makes a walk sound mechanical")


func test_every_step_is_pitched_between_five_and_ten_percent() -> void:
	var player: Boy = await _make_player()

	var lowest: float = 1.0
	var highest: float = 1.0
	for _step: int in 60:
		player._on_footstepped(0)
		var pitch: float = player._audio.pitch_scale
		var wobble: float = absf(pitch - 1.0)
		assert_between(wobble, 0.049, 0.101, "every step should be detuned just a little")
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)

	assert_lt(lowest, 0.96, "some steps should land low")
	assert_gt(highest, 1.04, "and some should land high")


func test_a_step_plays_at_the_footstep_level() -> void:
	var player: Boy = await _make_player()

	player._on_footstepped(0)
	var expected: float = Boy.FOOTSTEP_DB + linear_to_db(AudioDirector.sfx_volume)
	assert_almost_eq(
		player._audio.volume_db, expected, 0.01, "a step should play at the footstep level"
	)
	assert_lt(Boy.FOOTSTEP_DB, -6.0, "the steps were asked to come down and stay down")
