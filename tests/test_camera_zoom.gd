extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	return game


func _camera_distance(rig: CameraRig, player: Boy) -> float:
	return rig.get_camera().global_position.distance_to(player.global_position)


func test_the_camera_stays_close_on_a_huge_planet() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	rig._intro = 0.0
	planet.apply_radius(200.0)
	player.snap_to_surface()
	rig._orbit = player.global_position
	rig._snap()
	await wait_physics_frames(10)

	var distance: float = _camera_distance(rig, player)
	assert_lt(distance, 18.0, "a huge planet must not push the camera into orbit")
	assert_gt(distance, 6.0, "the boy should still be framed, not trampled by the camera")


func test_holding_plus_zooms_in_and_minus_zooms_out() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var rig: CameraRig = game.get_node("CameraRig") as CameraRig
	rig._intro = 0.0
	await wait_physics_frames(6)
	var start: float = _camera_distance(rig, player)

	Input.action_press("zoom_in")
	await wait_physics_frames(24)
	var near: float = _camera_distance(rig, player)
	Input.action_release("zoom_in")
	assert_lt(near, start * 0.85, "holding + should bring the camera closer")
	assert_lt(rig.get_zoom(), 1.0, "the rig should remember it is zoomed in")

	Input.action_press("zoom_out")
	await wait_physics_frames(36)
	var far: float = _camera_distance(rig, player)
	Input.action_release("zoom_out")
	assert_gt(far, near * 1.15, "holding - should push the camera back out")
