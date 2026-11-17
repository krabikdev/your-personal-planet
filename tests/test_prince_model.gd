extends GutTest  # gdlint:ignore=max-public-methods

const PLAYER_PATH: String = "res://scenes/player.tscn"
const GAME_PATH: String = "res://scenes/game.tscn"
const DUKE_HEIGHT: float = 1.125
const BONE_NAMES: Array[String] = [
	"body",
	"head",
	"arm_L",
	"arm_R",
	"claw_R",
	"leg_L_hip",
	"leg_L_tip",
	"leg_R_hip",
	"leg_R_tip",
	"cape_00_00",
	"cape_08_04",
	"cape_15_07",
	"stem_01",
	"stem_02",
	"vine_L_01",
	"vine_R_01",
]


func test_duke_rig_imports_with_its_bones() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	assert_not_null(skeleton, "the duke should come rigged")
	for bone: String in BONE_NAMES:
		assert_true(skeleton.find_bone(bone) >= 0, "%s bone should exist" % bone)


func test_duke_stands_on_the_visual_origin_at_capsule_height() -> void:
	var scene: PackedScene = load(PLAYER_PATH) as PackedScene
	var player: Node3D = scene.instantiate() as Node3D
	add_child_autofree(player)
	await wait_process_frames(1)
	var model: Node3D = player.get_node("%Visual")
	var capsule: CapsuleShape3D = (
		(player.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	)
	var top: float = 0.0
	var bottom: float = 100.0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.get_aabb()
		var base: Vector3 = model.global_position
		top = maxf(top, (mesh_instance.global_transform * box.position).y - base.y + box.size.y)
		bottom = minf(bottom, (mesh_instance.global_transform * box.position).y - base.y)
	assert_almost_eq(top, DUKE_HEIGHT, 0.12, "the duke should fill the old capsule height")
	assert_almost_eq(bottom, 0.0, 0.08, "the duke's feet should sit on the visual origin")
	assert_almost_eq(capsule.height, DUKE_HEIGHT, 0.01)


func test_duke_faces_player_forward() -> void:
	var model: PrinceModel = await _spawn_model()
	var eye: MeshInstance3D = null
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if node.name == "Eye_Glow_L":
			eye = node as MeshInstance3D
			break
	assert_not_null(eye, "the eye mesh should be part of the duke")
	var centre: Vector3 = eye.global_transform * eye.get_aabb().get_center()
	var forward: Vector3 = -model.global_transform.basis.z
	assert_gt(
		(centre - model.global_position).dot(forward),
		0.05,
		"the duke should look where the player faces"
	)


func test_legs_stand_near_the_ground() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	await wait_seconds(0.5)
	for side: String in ["L", "R"]:
		var knee: int = skeleton.find_bone("leg_%s_tip" % side)
		var knee_world: Vector3 = (
			skeleton.global_transform * skeleton.get_bone_global_pose(knee).origin
		)
		var height: float = knee_world.y - model.global_position.y
		assert_gt(height, 0.02, "the %s knee should stay above the ground" % side)
		assert_lt(height, 0.3, "the %s knee should not float" % side)


func test_cold_tints_the_surfaces_without_touching_the_import() -> void:
	var model: PrinceModel = await _spawn_model()
	var material: StandardMaterial3D = _first_material(model)
	assert_not_null(material, "every surface should get its own duplicated material")
	var warm: Color = material.albedo_color
	model.set_cold(1.0)
	var frozen: Color = material.albedo_color
	assert_gt(frozen.b, warm.b, "cold shifts the albedo toward pale blue")
	model.set_cold(0.0)
	assert_almost_eq(material.albedo_color.b, warm.b, 0.001, "warming restores the albedo")


func test_catch_point_sits_in_front_of_the_character() -> void:
	var model: PrinceModel = await _spawn_model()
	var forward: Vector3 = -model.global_transform.basis.z
	var offset: Vector3 = model.get_net_catch_point() - model.global_position
	assert_gt(offset.dot(forward), 0.05, "the catch point should sit in front of the duke")


func test_net_swing_opens_a_short_window() -> void:
	var model: PrinceModel = await _spawn_model()
	assert_false(model.is_net_active(), "the net idles inactive")
	model.play_net_swing()
	assert_false(model.is_net_active(), "the swing starts inactive")
	await wait_seconds(0.32)
	assert_true(model.is_net_active(), "the net is live mid-swing")
	await wait_seconds(0.5)
	assert_false(model.is_net_active(), "the window closes")


func test_cloak_is_simulated_by_its_own_node() -> void:
	var model: PrinceModel = await _spawn_model()
	var driver: Node = model.get_node_or_null("Cloak")
	assert_not_null(driver, "the cloak should run on its own simulation node")
	assert_true(driver is PrinceCloak, "the driver is a PrinceCloak, not a baked clip")
	assert_true((driver as PrinceCloak).is_active(), "the cloak should find its bone lattice")


func test_cloak_hangs_from_the_collar() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	await wait_seconds(0.6)
	var collar: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("cape_08_00")).origin
	var hem: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("cape_08_07")).origin
	var middle: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("cape_08_04")).origin
	assert_lt(hem.y, collar.y - 0.15, "the cloak should hang down from the collar")
	assert_lt(hem.y, middle.y, "the hem should sit under the middle of the cloak")


func test_cloak_keeps_its_collar_on_the_body() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	var collar: int = skeleton.find_bone("cape_03_00")
	var start: Vector3 = skeleton.get_bone_global_pose(collar).origin
	Input.action_press("move_forward")
	Input.action_press("run")
	var drift: float = 0.0
	for _step: int in 10:
		await wait_seconds(0.08)
		drift = maxf(drift, start.distance_to(skeleton.get_bone_global_pose(collar).origin))
	Input.action_release("run")
	Input.action_release("move_forward")
	assert_lt(drift, 0.01, "the collar must stay pinned to the shoulders")


func test_cloak_hem_swings_behind_a_running_duke() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	var hem: int = skeleton.find_bone("cape_08_07")
	var chest: int = skeleton.find_bone("body")
	await wait_seconds(0.3)
	var before: Vector3 = _offset(skeleton, hem, chest)
	Input.action_press("move_forward")
	Input.action_press("run")
	await wait_seconds(0.8)
	var after: Vector3 = _offset(skeleton, hem, chest)
	var forward: Vector3 = -player.global_transform.basis.z
	Input.action_release("run")
	Input.action_release("move_forward")
	assert_lt((after - before).dot(forward), -0.008, "the hem should trail behind the duke")


func test_cloak_swings_without_billowing() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	var hem: int = skeleton.find_bone("cape_08_07")
	var collar: int = skeleton.find_bone("cape_08_00")
	var hem_rest: Vector3 = skeleton.get_bone_global_rest(hem).origin
	var collar_rest: Vector3 = skeleton.get_bone_global_rest(collar).origin
	Input.action_press("move_forward")
	Input.action_press("run")
	var swing: float = 0.0
	var drift: float = 0.0
	for _step: int in 10:
		await wait_seconds(0.08)
		swing = maxf(swing, skeleton.get_bone_global_pose(hem).origin.distance_to(hem_rest))
		drift = maxf(drift, skeleton.get_bone_global_pose(collar).origin.distance_to(collar_rest))
	Input.action_release("run")
	Input.action_release("move_forward")
	assert_gt(swing, 0.03, "heavy cloth still leans when the duke accelerates")
	assert_lt(swing, 0.4, "the cloak must not fly off the shoulders")
	assert_lt(drift, 0.01, "the collar stays welded to the shoulders")


func test_head_plant_sits_still_when_the_duke_stands_still() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	var stem: int = skeleton.find_bone("stem_02")
	await wait_seconds(1.0)
	var start: Vector3 = skeleton.get_bone_global_pose(stem).origin
	var worst: float = 0.0
	for _step: int in 20:
		await wait_seconds(0.05)
		worst = maxf(worst, skeleton.get_bone_global_pose(stem).origin.distance_to(start))
	assert_lt(worst, 0.012, "the plant should not jiggle while the duke is idle")


func test_head_plant_root_is_welded_to_the_head() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	var head: int = skeleton.find_bone("head")
	var stem: int = skeleton.find_bone("stem_01")
	var rest: float = _bone_gap(skeleton, stem, head)
	Input.action_press("move_forward")
	Input.action_press("run")
	var worst: float = 0.0
	for _step: int in 10:
		await wait_seconds(0.08)
		worst = maxf(worst, absf(_bone_gap(skeleton, stem, head) - rest))
	Input.action_release("run")
	Input.action_release("move_forward")
	assert_lt(worst, 0.01, "the plant root has to ride the head, not drift off it")


func test_footfalls_emit_a_footstep_signal() -> void:
	var model: PrinceModel = await _spawn_model()
	var sides: Array[int] = []
	model.footstepped.connect(func(side: int) -> void: sides.append(side))
	for _step: int in 30:
		model.set_motion(1.0, true, false, 3.3, Vector3.BACK * 3.3)
		await wait_seconds(0.04)
	assert_gt(sides.size(), 0, "each foot plant should tell the player to play a step")
	assert_true(sides.has(0) and sides.has(1), "both feet should be heard")


func test_footfalls_puff_dust() -> void:
	var model: PrinceModel = await _spawn_model()
	await wait_seconds(0.3)
	assert_not_null(model.get_node_or_null("StepDustL"), "each foot needs its own dust puff")
	var before: int = model._steps
	for _step: int in 30:
		model.set_motion(1.0, true, false, 3.3, Vector3.BACK * 3.3)
		await wait_seconds(0.04)
	assert_gt(model._steps - before, 0, "walking should kick up dust at each footfall")


func test_legs_reach_their_inverse_kinematics_targets() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	await wait_seconds(0.3)
	var shin: float = model._leg_lengths[0].y
	var worst: float = 0.0
	var lift: float = 0.0
	for _step: int in 24:
		model.set_motion(1.0, true, false, 3.3, Vector3.BACK * 3.3)
		await wait_seconds(0.04)
		var pose: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("leg_L_tip"))
		var foot: Vector3 = (
			skeleton.global_transform * (pose.origin + pose.basis.y.normalized() * shin)
		)
		worst = maxf(worst, foot.distance_to(model._foot_targets[0]))
		lift = maxf(lift, foot.y - model.global_position.y)
	assert_lt(worst, 0.02, "the shin should land on its target every frame")
	assert_gt(lift, 0.008, "the foot should lift during the swing")


func test_standing_legs_keep_a_bent_knee() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	await wait_seconds(0.6)
	var hip: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("leg_L_hip")).origin
	var knee: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("leg_L_tip")).origin
	var foot: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("leg_L_tip")).origin
	foot += (
		skeleton.get_bone_global_pose(skeleton.find_bone("leg_L_tip")).basis.y.normalized()
		* model._leg_lengths[0].y
	)
	var thigh: Vector3 = (knee - hip).normalized()
	var shin: Vector3 = (foot - knee).normalized()
	assert_gt(rad_to_deg(thigh.angle_to(shin)), 8.0, "idle legs should stand with a bent knee")


func test_cloak_opens_upwards_when_the_duke_falls() -> void:
	var model: PrinceModel = await _spawn_model()
	var skeleton: Skeleton3D = _skeleton(model)
	await wait_seconds(0.4)
	var hem: int = skeleton.find_bone("cape_08_07")
	var collar: int = skeleton.find_bone("cape_08_00")
	var centre: Vector3 = skeleton.get_bone_global_pose(collar).origin
	var before: Vector3 = skeleton.get_bone_global_pose(hem).origin
	var reach_before: Vector3 = before - centre
	var radius_before: float = (reach_before - Vector3.UP * reach_before.dot(Vector3.UP)).length()
	var height_before: float = reach_before.dot(Vector3.UP)
	model.set_motion(2.0, false, false, 12.0, Vector3.DOWN * 12.0)
	await wait_seconds(0.7)
	var after: Vector3 = skeleton.get_bone_global_pose(hem).origin
	var reach_after: Vector3 = after - centre
	var radius_after: float = (reach_after - Vector3.UP * reach_after.dot(Vector3.UP)).length()
	var height_after: float = reach_after.dot(Vector3.UP)
	assert_gt(radius_after, radius_before + 0.01, "falling pushes the hem outwards")
	assert_gt(height_after, height_before + 0.005, "and lifts it up like air from below")


func test_smearing_crouches_and_spins_on_the_spot() -> void:
	var scene: PackedScene = load(GAME_PATH) as PackedScene
	var game: Node3D = scene.instantiate() as Node3D
	add_child_autofree(game)
	await wait_process_frames(2)
	var player: Boy = game.get_node("Player") as Boy
	var model: PrinceModel = player.get_node("%Visual") as PrinceModel
	var rig: Node3D = model.get_node("Rig") as Node3D
	var facing: Vector3 = -player.global_transform.basis.z
	player.start_smearing()
	await wait_seconds(0.5)
	var crouch: float = rig.position.y
	var first: float = rig.rotation.y
	await wait_seconds(0.25)
	var spun: float = absf(wrapf(rig.rotation.y - first, -PI, PI))
	player.end_smearing_pose()
	await wait_seconds(1.6)
	var settled: float = absf(wrapf(rig.rotation.y - PI, -PI, PI))
	var turned: float = facing.angle_to(-player.global_transform.basis.z)
	assert_lt(crouch, -0.15, "burying should press the duke into a crouch")
	assert_gt(spun, 0.6, "the duke should spin fast on the spot while burying")
	assert_lt(settled, 0.2, "the spin should fade out facing forward again")
	assert_lt(turned, 0.2, "only the model spins; the body keeps its heading")


func _bone_gap(skeleton: Skeleton3D, first: int, second: int) -> float:
	return skeleton.get_bone_global_pose(first).origin.distance_to(
		skeleton.get_bone_global_pose(second).origin
	)


func _offset(skeleton: Skeleton3D, first: int, second: int) -> Vector3:
	return (
		skeleton.global_transform * skeleton.get_bone_global_pose(first).origin
		- skeleton.global_transform * skeleton.get_bone_global_pose(second).origin
	)


func test_landing_squashes_then_recovers() -> void:
	var model: PrinceModel = await _spawn_model()
	var rig: Node3D = model.get_node("Rig") as Node3D
	model.play_land_squash(1.0)
	await wait_seconds(0.06)
	assert_lt(rig.scale.y, 0.98, "a landing should squash the body")
	await wait_seconds(0.5)
	assert_almost_eq(rig.scale.y, 1.0, 0.02, "the squash should recover")


func test_sitting_crouches_the_body() -> void:
	var model: PrinceModel = await _spawn_model()
	var rig: Node3D = model.get_node("Rig") as Node3D
	model.set_sitting(true)
	await wait_seconds(0.5)
	assert_lt(rig.position.y, -0.1, "sitting should lower the pumpkin")
	model.set_sitting(false)
	await wait_seconds(0.5)
	assert_gt(rig.position.y, -0.09, "standing up should raise it again")


func _spawn_model() -> PrinceModel:
	var scene: PackedScene = load(PLAYER_PATH) as PackedScene
	var player: Node3D = scene.instantiate() as Node3D
	add_child_autofree(player)
	await wait_process_frames(1)
	return player.get_node("%Visual") as PrinceModel


func _skeleton(model: PrinceModel) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


func _first_material(model: PrinceModel) -> StandardMaterial3D:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: Material = mesh_instance.get_surface_override_material(surface)
			if material is StandardMaterial3D:
				return material as StandardMaterial3D
	return null
