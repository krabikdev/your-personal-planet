extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	return game


func test_the_duke_stands_upright_on_the_ground() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var model: PrinceModel = player._model
	await wait_physics_frames(6)

	var rig_up: Vector3 = model._rig.global_transform.basis.y.normalized()
	var body_up: Vector3 = player.global_transform.basis.y.normalized()
	assert_lt(
		rad_to_deg(rig_up.angle_to(body_up)), 3.0, "standing still, the duke should stand straight"
	)
	assert_lt(model.get_lean(), 0.05, "there is nothing to hang from on the ground")


func test_the_duke_hangs_from_the_rope_while_reeling() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var planet: Planet = game.get_node("Planet") as Planet
	var player: Boy = game.get_node("Player") as Boy
	var model: PrinceModel = player._model
	planet.apply_radius(20.0)
	player.snap_to_surface()
	await wait_physics_frames(2)
	player.plant_stake()
	await wait_physics_frames(1)

	var centre: Vector3 = planet.get_center()
	var stake_dir: Vector3 = (player.rope.get_anchor_position() - centre).normalized()
	var axis: Vector3 = stake_dir.cross(player.get_up())
	if axis.length_squared() < 0.01:
		axis = stake_dir.cross(Vector3.RIGHT)
	player.global_position = (
		centre + stake_dir.rotated(axis.normalized(), 0.45) * (planet.radius + 5.0)
	)
	player.velocity = Vector3.ZERO
	Input.action_press("jump")
	await wait_physics_frames(20)
	var rig_up: Vector3 = model._rig.global_transform.basis.y.normalized()
	var body_up: Vector3 = player.global_transform.basis.y.normalized()
	var lean: float = rad_to_deg(rig_up.angle_to(body_up))
	Input.action_release("jump")

	assert_gt(lean, 8.0, "a boy hanging from a rope should not be standing to attention")
	assert_gt(model.get_lean(), 0.2, "the lean should have ramped in, not snapped")


func test_the_duke_tucks_his_legs_when_he_jumps() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var model: PrinceModel = player._model
	var grounded_foot: Vector3 = (
		model._foot_targets[0] if model._foot_targets.size() > 0 else Vector3.ZERO
	)

	player.debug_jump()
	await wait_physics_frames(14)

	assert_true(model._airborne, "a jump should put him in the air")
	assert_gt(model._air_tuck, 0.4, "the legs should curl up during a jump")
	assert_gt(model._pitch, 0.08, "the body should pitch into the jump")
	var airborne_foot: Vector3 = model._foot_targets[0]
	assert_gt(
		airborne_foot.y - grounded_foot.y,
		0.12,
		"the feet should come up under the body, not trail behind",
	)
