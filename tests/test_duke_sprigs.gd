extends GutTest

const GAME_PATH: String = "res://scenes/game.tscn"


func _make_game() -> Game:
	var game: Game = (load(GAME_PATH) as PackedScene).instantiate() as Game
	add_child_autofree(game)
	return game


func _chain_index(sprigs: PrinceSprigs, root: String) -> int:
	for index: int in sprigs._chains.size():
		if String(sprigs._skeleton.get_bone_name(sprigs._chains[index][0])) == root:
			return index
	return -1


func _tip_lateral(sprigs: PrinceSprigs, chain: int) -> float:
	var points: PackedVector3Array = sprigs._points[chain]
	var anchor: Vector3 = points[0]
	var x: Vector3 = sprigs._skeleton.global_transform.basis.x.normalized()
	return (points[points.size() - 1] - anchor).dot(x)


func _tip_fore(sprigs: PrinceSprigs, chain: int) -> float:
	var points: PackedVector3Array = sprigs._points[chain]
	var anchor: Vector3 = points[0]
	var forward: Vector3 = -sprigs._skeleton.global_transform.basis.z.normalized()
	return (points[points.size() - 1] - anchor).dot(forward)


func _excursion(values: PackedFloat32Array) -> float:
	var low: float = INF
	var high: float = -INF
	for value: float in values:
		low = minf(low, value)
		high = maxf(high, value)
	return high - low


func _correlation(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var mean_a: float = 0.0
	var mean_b: float = 0.0
	for value: float in a:
		mean_a += value
	for value: float in b:
		mean_b += value
	mean_a /= float(maxi(a.size(), 1))
	mean_b /= float(maxi(b.size(), 1))
	var covariance: float = 0.0
	var variance_a: float = 0.0
	var variance_b: float = 0.0
	for index: int in mini(a.size(), b.size()):
		var da: float = a[index] - mean_a
		var db: float = b[index] - mean_b
		covariance += da * db
		variance_a += da * da
		variance_b += db * db
	return covariance / maxf(sqrt(variance_a * variance_b), 0.000001)


func test_the_vines_swing_against_their_own_footfalls() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var sprigs: PrinceSprigs = player._model._sprigs
	var left: int = _chain_index(sprigs, "vine_L_01")
	var right: int = _chain_index(sprigs, "vine_R_01")
	assert_true(left >= 0 and right >= 0, "setup: both vine chains should exist")

	Input.action_press("move_forward")
	await wait_physics_frames(30)
	var swings_l := PackedFloat32Array()
	var swings_r := PackedFloat32Array()
	var fore_l := PackedFloat32Array()
	var fore_r := PackedFloat32Array()
	for _frame: int in 60:
		await wait_physics_frames(1)
		swings_l.append(_tip_lateral(sprigs, left))
		swings_r.append(_tip_lateral(sprigs, right))
		fore_l.append(_tip_fore(sprigs, left))
		fore_r.append(_tip_fore(sprigs, right))
	Input.action_release("move_forward")

	assert_gt(_excursion(swings_l), 0.03, "the left vine tip should travel with the walk")
	assert_gt(_excursion(swings_r), 0.03, "the right vine tip should travel with the walk")
	assert_gt(_excursion(fore_l), 0.08, "the left vine should stride fore and aft")
	assert_gt(_excursion(fore_r), 0.08, "the right vine should stride fore and aft")
	assert_lt(
		_correlation(fore_l, fore_r),
		-0.5,
		"the two vines should swing against each other, not in sync",
	)


func test_the_vines_keep_a_quiet_idle_breath() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var sprigs: PrinceSprigs = player._model._sprigs
	var left: int = _chain_index(sprigs, "vine_L_01")

	Input.action_press("move_forward")
	await wait_physics_frames(90)
	var walk := PackedFloat32Array()
	for _frame: int in 60:
		await wait_physics_frames(1)
		walk.append(_tip_lateral(sprigs, left))
	Input.action_release("move_forward")
	await wait_physics_frames(30)

	var idle := PackedFloat32Array()
	for _frame: int in 60:
		await wait_physics_frames(1)
		idle.append(_tip_lateral(sprigs, left))
	var walked: float = _excursion(walk)
	var rested: float = _excursion(idle)

	assert_gt(walked, 0.03, "setup: the walk should move the vine tip")
	assert_gt(rested, 0.002, "standing still should leave a small idle breath")
	assert_lt(rested, walked * 0.5, "the idle breath should stay far below the walk")


func test_turning_flings_the_vine_tips_outward() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var sprigs: PrinceSprigs = player._model._sprigs
	var left: int = _chain_index(sprigs, "vine_L_01")

	var base := PackedFloat32Array()
	for _frame: int in 20:
		await wait_physics_frames(1)
		base.append(_tip_lateral(sprigs, left))
	var up: Vector3 = player.get_up()
	for _frame: int in 40:
		player._facing = player._facing.rotated(up, 0.06).normalized()
		await wait_physics_frames(1)
	var turn := PackedFloat32Array()
	for _frame: int in 20:
		player._facing = player._facing.rotated(up, 0.06).normalized()
		await wait_physics_frames(1)
		turn.append(_tip_lateral(sprigs, left))

	var base_mean: float = 0.0
	for value: float in base:
		base_mean += value
	base_mean /= float(base.size())
	var turn_mean: float = 0.0
	for value: float in turn:
		turn_mean += value
	turn_mean /= float(turn.size())

	assert_gt(absf(turn_mean), 0.04, "spinning should push the vine tip sideways")
	assert_gt(
		absf(turn_mean),
		absf(base_mean) + 0.02,
		"the sideways push should stand clear of the idle sway",
	)
