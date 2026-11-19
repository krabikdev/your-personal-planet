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
	var spike: int = _chain_index(sprigs, "spike_01")
	assert_true(left >= 0 and right >= 0, "setup: both vine chains should exist")

	Input.action_press("move_forward")
	await wait_physics_frames(30)
	var swings_l := PackedFloat32Array()
	var swings_r := PackedFloat32Array()
	var fore_l := PackedFloat32Array()
	var fore_r := PackedFloat32Array()
	var fore_s := PackedFloat32Array()
	var have_spike: bool = spike >= 0
	for _frame: int in 60:
		await wait_physics_frames(1)
		swings_l.append(_tip_lateral(sprigs, left))
		swings_r.append(_tip_lateral(sprigs, right))
		fore_l.append(_tip_fore(sprigs, left))
		fore_r.append(_tip_fore(sprigs, right))
		if have_spike:
			fore_s.append(_tip_fore(sprigs, spike))
	Input.action_release("move_forward")

	assert_gt(_excursion(swings_l), 0.02, "the left vine tip should travel with the walk")
	assert_gt(_excursion(swings_r), 0.02, "the right vine tip should travel with the walk")
	assert_gt(_excursion(fore_l), 0.025, "the left vine should stride fore and aft")
	assert_gt(_excursion(fore_r), 0.025, "the right vine should stride fore and aft")
	if have_spike:
		assert_gt(_excursion(fore_s), 0.03, "the chest twigs should stride with the walk")
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

	assert_gt(walked, 0.02, "setup: the walk should move the vine tip")
	assert_gt(rested, 0.002, "standing still should leave a small idle breath")
	assert_lt(rested, walked * 0.5, "the idle breath should stay far below the walk")


func test_turning_flings_the_vine_tips_outward() -> void:
	var game: Game = _make_game()
	await wait_physics_frames(2)

	var player: Boy = game.get_node("Player") as Boy
	var sprigs: PrinceSprigs = player._model._sprigs
	var left: int = _chain_index(sprigs, "vine_L_01")
	var up: Vector3 = player.get_up()
	var swing := PackedFloat32Array()
	for flip: int in 6:
		var direction: float = 1.0 if flip % 2 == 0 else -1.0
		for _frame: int in 10:
			player._facing = player._facing.rotated(up, direction * 0.06).normalized()
			await wait_physics_frames(1)
			swing.append(_tip_lateral(sprigs, left))

	assert_gt(_excursion(swing), 0.03, "whipping the body around should fling the vine tip")
