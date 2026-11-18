class_name PrinceModel
extends Node3D

signal footstepped(side: int)

const MODEL_SCENE: PackedScene = preload("res://assets/models/pumpkin_duke.glb")

const CROUCH: float = -0.035
const SIT_CROUCH: float = -0.15
const SIT_LEAN: float = 0.5
const SMEAR_CROUCH: float = -0.24
const SMEAR_SPIN: float = 15.0
const SMEAR_SPIN_RAMP: float = 7.0
const SMEAR_RAMP: float = 6.0
const SMEAR_ARM: float = 0.75
const HAMMER_ARM: float = 1.35
const HAMMER_TIME: float = 0.45
const BOB_AMPLITUDE: float = 0.055
const BOB_SWAY: float = 0.014
const WALK_CADENCE: float = 2.2
const RUN_CADENCE: float = 3.8
const SWING_PORTION: float = 0.4
const STRIDE_PER_SPEED: float = 0.06
const STRIDE_MIN: float = 0.07
const STRIDE_MAX: float = 0.26
const GAIT_LIFT: float = 0.085
const GAIT_ACTIVITY_SPEED: float = 0.6
const FOOT_SNAP: float = 26.0
const ARM_SWING: float = 0.5
const ARM_RESPONSE: float = 12.0
const BANK_PER_TURN: float = 0.05
const MAX_BANK: float = 0.16
const RUN_PITCH: float = 0.07
const PITCH_RESPONSE: float = 6.0
const HEAD_NOD: float = 0.03
const TAU: float = 6.2831855
const AIR_GRACE: float = 0.15
const STEP_LIFT: float = 0.05
const STEP_TIME: float = 0.16
const STEP_MIN: float = 0.11
const STEP_MAX: float = 0.24
const STEP_SPEED_GAIN: float = 0.1
const AIR_FOOT_LIFT: float = 0.07
const AIR_TUCK_LIFT: float = 0.3
const AIR_TUCK_FORWARD: float = 0.14
const AIR_PITCH: float = 0.3
const AIR_TUCK_RATE: float = 10.0
const LEAN_RATE: float = 5.0
const CATCH_ARM: float = 1.1
const CATCH_TIME: float = 0.55
const LEAN_TIME: float = 0.25

const NET_SWING_DURATION: float = 0.72
const NET_ACTIVE_START: float = 0.24
const NET_ACTIVE_END: float = 0.52
const NET_CATCH_FORWARD: float = 0.35
const NET_CATCH_HEIGHT: float = 0.35
const NET_SWING_LIFT: float = 0.9

const WATER_ARM: float = 1.05
const WATER_RAMP: float = 7.0
const CHARGE_CROUCH: float = 0.12
const CAN_TILT: float = 0.62
const CAN_BODY_COLOR := Color("7f9a90")
const CAN_RUST_COLOR := Color("8a5a3b")
const WATER_COLOR := Color(0.62, 0.85, 0.95, 0.85)

var _rig: Node3D
var _skeleton: Skeleton3D
var _cloak: PrinceCloak
var _sprigs: PrinceSprigs
var _catch_point: Vector3 = Vector3.ZERO
var _can_attachment: BoneAttachment3D
var _can: Node3D
var _can_pour: GPUParticles3D
var _watering: bool = false
var _water_amount: float = 0.0
var _charge: float = 0.0
var _hip_bones: Array[int] = []
var _knee_bones: Array[int] = []
var _arm_bones: Array[int] = []
var _claw_bone: int = -1
var _body_bone: int = -1
var _head_bone: int = -1
var _foot_targets: Array[Vector3] = []
var _leg_lengths: Array[Vector2] = []
var _speed: float = 0.0
var _speed_ratio: float = 0.0
var _grounded: bool = true
var _airborne: bool = false
var _air_time: float = 0.0
var _air_tuck: float = 0.0
var _pull: Vector3 = Vector3.ZERO
var _pull_weight: float = 0.0
var _pull_target: Vector3 = Vector3.ZERO
var _hang: float = 0.0
var _running: bool = false
var _sitting: bool = false
var _bob_phase: float = 0.0
var _gait_phase: float = 0.0
var _activity: float = 0.0
var _motion: float = 0.0
var _body_height: float = 0.0
var _bank: float = 0.0
var _pitch: float = 0.0
var _arm_swing: float = 0.0
var _catch_amount: float = 0.0
var _hammer_amount: float = 0.0
var _smearing: bool = false
var _smear_amount: float = 0.0
var _spin: float = 0.0
var _spin_speed: float = 0.0
var _last_forward: Vector3 = Vector3.ZERO
var _net_swinging: bool = false
var _net_swing_time: float = 0.0
var _net_active: bool = false
var _squash_tween: Tween
var _pose_tween: Tween
var _smear_dust: GPUParticles3D
var _land_dust: GPUParticles3D
var _step_dust: Array[GPUParticles3D] = []
var _stance: Array[bool] = []
var _steps: int = 0


func _ready() -> void:
	_build_rig()
	_build_dust()
	_place_feet()
	set_process(true)


func _process(delta: float) -> void:
	_update_air(delta)
	_update_body(delta)
	_update_legs(delta)
	if _sprigs != null:
		_sprigs.set_gait(_activity, _gait_phase)
	if _cloak != null:
		_cloak.set_gait(_motion)
	_update_water(delta)
	_pose_arms(delta)
	_update_can()
	_update_pose(delta)
	_update_net(delta)
	if _smear_dust != null:
		_smear_dust.emitting = _sitting or _smearing


func set_motion(
	speed_ratio: float,
	grounded: bool,
	running: bool = false,
	speed: float = 0.0,
	motion: Vector3 = Vector3.ZERO
) -> void:
	_speed_ratio = clampf(speed_ratio, 0.0, 3.0)
	_speed = absf(speed)
	_running = running
	_grounded = grounded
	if _cloak != null:
		_cloak.set_velocity(motion)


func set_sitting(active: bool) -> void:
	if active == _sitting:
		return
	_sitting = active
	_lean(1.0 if active else 0.0)
	if _smear_dust != null:
		_smear_dust.emitting = active


func is_sitting() -> bool:
	return _sitting


func set_smearing(active: bool) -> void:
	if active == _smearing:
		return
	_smearing = active
	_lean(1.0 if active else 0.0)
	if _smear_dust != null:
		_smear_dust.emitting = active or _sitting


func is_smearing() -> bool:
	return _smearing


## Where the rope is dragging him and how hard, so the body can hang from it
## instead of standing to attention in mid air. The direction eases toward its
## target so letting go of the winch settles the body instead of snapping it
## upright; the weight stays instant and the hang still fades at its own rate.
func set_pull(direction: Vector3, weight: float) -> void:
	_pull_target = direction
	_pull_weight = clampf(weight, 0.0, 1.0)


func get_lean() -> float:
	return _hang


func play_jump() -> void:
	_stretch()


func play_land_squash(strength: float = 1.0) -> void:
	if _rig == null:
		return
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	var amount: float = clampf(strength, 0.35, 1.4)
	_rig.scale = Vector3.ONE
	_squash_tween = create_tween()
	_squash_tween.tween_property(
		_rig, "scale", Vector3(1.0 + 0.12 * amount, 1.0 - 0.16 * amount, 1.0 + 0.12 * amount), 0.08
	)
	_squash_tween.set_trans(Tween.TRANS_QUAD)
	_squash_tween.tween_property(_rig, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK)
	play_land_dust()


func play_land_dust() -> void:
	if _land_dust == null:
		return
	_land_dust.restart()
	_land_dust.emitting = true


func play_catch_pose() -> void:
	if _arm_bones.is_empty():
		return
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_method(_apply_catch_pose, 0.0, 1.0, CATCH_TIME * 0.4)
	_pose_tween.tween_method(_apply_catch_pose, 1.0, 0.0, CATCH_TIME * 0.6)


func play_hammer_swing() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_method(_apply_hammer_pose, 0.0, 1.0, HAMMER_TIME * 0.35)
	_pose_tween.tween_method(_apply_hammer_pose, 1.0, 0.0, HAMMER_TIME * 0.65)


func play_net_swing() -> void:
	if _net_swinging:
		return
	_net_swinging = true
	_net_swing_time = 0.0
	_net_active = false


func is_net_active() -> bool:
	return _net_active


## The can lives in the right hand only while he is pouring. The pour itself is
## silent: it is the water the player is watching, not his ears.
func set_watering(active: bool) -> void:
	if active == _watering:
		return
	_watering = active
	if _can != null:
		_can.visible = active
	if _can_pour != null:
		_can_pour.emitting = active


func is_watering() -> bool:
	return _watering


## While the jump is being charged the duke sinks into his knees, so the player
## can see how much spring is loaded.
func set_charging(amount: float) -> void:
	_charge = clampf(amount, 0.0, 1.0)


func get_hand_position() -> Vector3:
	if _skeleton == null or _claw_bone < 0:
		return global_position + global_transform.basis.y * NET_CATCH_HEIGHT
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_claw_bone)).origin


func get_net_catch_point() -> Vector3:
	if _catch_point != Vector3.ZERO:
		return _catch_point
	var basis: Basis = global_transform.basis.orthonormalized()
	return global_position + basis.y * NET_CATCH_HEIGHT - basis.z * NET_CATCH_FORWARD


func _build_rig() -> void:
	_rig = MODEL_SCENE.instantiate() as Node3D
	if _rig == null:
		return
	_rig.name = "Rig"
	_rig.rotation.y = PI
	add_child(_rig)
	var skeletons: Array[Node] = _rig.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	_body_bone = _skeleton.find_bone("body")
	_head_bone = _skeleton.find_bone("head")
	_claw_bone = _skeleton.find_bone("claw_R")
	for side: String in ["L", "R"]:
		_hip_bones.append(_skeleton.find_bone("leg_%s_hip" % side))
		_knee_bones.append(_skeleton.find_bone("leg_%s_tip" % side))
		_arm_bones.append(_skeleton.find_bone("arm_%s" % side))
	_skeleton.reset_bone_poses()
	_measure_legs()
	_cloak = PrinceCloak.new()
	_cloak.name = "Cloak"
	add_child(_cloak)
	_cloak.setup(_skeleton)
	_sprigs = PrinceSprigs.new()
	_sprigs.name = "Sprigs"
	add_child(_sprigs)
	_sprigs.setup(_skeleton)
	_build_watering_can()


func _measure_legs() -> void:
	_leg_lengths.clear()
	for side: int in _hip_bones.size():
		var hip: Vector3 = _skeleton.get_bone_global_rest(_hip_bones[side]).origin
		var knee: Vector3 = _skeleton.get_bone_global_rest(_knee_bones[side]).origin
		_leg_lengths.append(Vector2(hip.distance_to(knee), absf(knee.y)))


## A small rusty hand can, hung off the right claw. Its orientation is redone
## every frame from the body, so it stays upright and readable no matter how the
## hand bone twists.
func _build_watering_can() -> void:
	if _skeleton == null:
		return
	var bone: int = _claw_bone
	if bone < 0:
		bone = _skeleton.find_bone("arm_R")
	if bone < 0:
		return
	_can_attachment = BoneAttachment3D.new()
	_can_attachment.name = "CanHand"
	_can_attachment.bone_name = _skeleton.get_bone_name(bone)
	_skeleton.add_child(_can_attachment)

	_can = Node3D.new()
	_can.name = "WateringCan"
	_can_attachment.add_child(_can)
	var metal := _flat_material(CAN_BODY_COLOR, 0.4, 0.6)
	var rust := _flat_material(CAN_RUST_COLOR, 0.92, 0.1)

	var body := CylinderMesh.new()
	body.top_radius = 0.16
	body.bottom_radius = 0.18
	body.height = 0.42
	body.radial_segments = 14
	body.rings = 2
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.material_override = metal
	body_node.position = Vector3(0.0, 0.21, 0.0)
	_can.add_child(body_node)

	var rim := CylinderMesh.new()
	rim.top_radius = 0.17
	rim.bottom_radius = 0.17
	rim.height = 0.04
	rim.radial_segments = 14
	rim.rings = 1
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.material_override = rust
	rim_node.position = Vector3(0.0, 0.43, 0.0)
	_can.add_child(rim_node)

	var spout := CylinderMesh.new()
	spout.top_radius = 0.032
	spout.bottom_radius = 0.06
	spout.height = 0.46
	spout.radial_segments = 8
	spout.rings = 1
	var spout_node := MeshInstance3D.new()
	spout_node.mesh = spout
	spout_node.material_override = rust
	spout_node.position = Vector3(0.0, 0.3, -0.3)
	spout_node.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	_can.add_child(spout_node)

	var rose := CylinderMesh.new()
	rose.top_radius = 0.075
	rose.bottom_radius = 0.035
	rose.height = 0.07
	rose.radial_segments = 10
	rose.rings = 1
	var rose_node := MeshInstance3D.new()
	rose_node.mesh = rose
	rose_node.material_override = rust
	rose_node.position = Vector3(0.0, 0.44, -0.48)
	rose_node.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	_can.add_child(rose_node)

	var handle := TorusMesh.new()
	handle.inner_radius = 0.1
	handle.outer_radius = 0.135
	handle.rings = 12
	handle.ring_segments = 6
	var handle_node := MeshInstance3D.new()
	handle_node.mesh = handle
	handle_node.material_override = metal
	handle_node.position = Vector3(0.0, 0.4, 0.04)
	handle_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_can.add_child(handle_node)

	_can_pour = GPUParticles3D.new()
	_can_pour.name = "Pour"
	_can_pour.amount = 26
	_can_pour.lifetime = 0.55
	_can_pour.local_coords = false
	_can_pour.emitting = false
	_can_pour.position = Vector3(0.0, 0.46, -0.52)
	var drop := QuadMesh.new()
	drop.size = Vector2(0.07, 0.07)
	drop.material = _particle_material(_soft_dot_texture())
	_can_pour.draw_pass_1 = drop
	var pour := _particle_process(WATER_COLOR, 0.7, 1.3, Vector3(0.0, -1.0, -0.35))
	pour.spread = 9.0
	pour.gravity = Vector3(0.0, -7.5, 0.0)
	pour.scale_min = 0.5
	pour.scale_max = 1.1
	_can_pour.process_material = pour
	_can.add_child(_can_pour)

	_can.visible = false


func _update_water(delta: float) -> void:
	_water_amount = lerpf(_water_amount, 1.0 if _watering else 0.0, 1.0 - exp(-WATER_RAMP * delta))


## Keeps the can in the claw but upright with the body, tilted forward to pour.
func _update_can() -> void:
	if _can == null or _can_attachment == null:
		return
	var hand: Vector3 = _can_attachment.global_position
	var basis: Basis = global_transform.basis.orthonormalized()
	var tilt: Basis = Basis(Vector3.RIGHT, -CAN_TILT * _water_amount)
	_can.global_transform = Transform3D(basis * tilt, hand)


func _flat_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _place_feet() -> void:
	_foot_targets.clear()
	for side: int in _hip_bones.size():
		_foot_targets.append(_ideal_foot(side))


func _ideal_foot(side: int) -> Vector3:
	var rest: Vector3 = _skeleton.get_bone_global_rest(_hip_bones[side]).origin
	var skeleton_basis: Basis = _skeleton.global_transform.basis.orthonormalized()
	var offset: Vector3 = skeleton_basis * Vector3(rest.x, 0.0, 0.0)
	return global_position + offset * _skeleton.global_transform.basis.get_scale().y


func _update_air(delta: float) -> void:
	_pull = _pull.lerp(_pull_target, 1.0 - exp(-LEAN_RATE * delta))
	if _grounded:
		if _airborne:
			_airborne = false
			_land()
		_air_time = 0.0
	else:
		_air_time += delta
		if not _airborne and _air_time >= AIR_GRACE:
			_airborne = true
			_stretch()
	_air_tuck = move_toward(_air_tuck, 1.0 if _airborne else 0.0, delta * AIR_TUCK_RATE)
	_hang = lerpf(_hang, _pull_weight if _airborne else 0.0, 1.0 - exp(-LEAN_RATE * delta))


func _update_body(delta: float) -> void:
	if _rig == null:
		return
	_smear_amount = lerpf(_smear_amount, 1.0 if _smearing else 0.0, 1.0 - exp(-SMEAR_RAMP * delta))
	var target: float = CROUCH
	if _smearing:
		target = SMEAR_CROUCH
	elif _sitting:
		target = SIT_CROUCH
	target -= CHARGE_CROUCH * _charge
	_body_height = lerpf(_body_height, target, 1.0 - exp(-9.0 * delta))
	var bob: float = 0.0
	var sway: float = 0.0
	if not _sitting and not _smearing and not _airborne:
		bob = (0.5 - 0.5 * cos(_bob_phase)) * BOB_AMPLITUDE * _activity
		sway = sin(_gait_phase) * BOB_SWAY * _activity
	_rig.position = Vector3(sway, _body_height + bob, 0.0)
	if _head_bone >= 0:
		var nod: float = sin(_bob_phase) * HEAD_NOD * _activity
		var tilt: float = clampf(_speed_ratio, 0.0, 1.0) * 0.16
		_swing_bone(_head_bone, global_transform.basis.x, -tilt - nod)


func _update_legs(delta: float) -> void:
	if _skeleton == null or _hip_bones.is_empty():
		return
	_motion = clampf(_speed / GAIT_ACTIVITY_SPEED, 0.0, 1.0)
	_activity = 0.0 if _airborne else _motion
	var blend: float = clampf(_speed_ratio / 1.8, 0.0, 1.0)
	var cadence: float = lerpf(WALK_CADENCE, RUN_CADENCE, blend)
	_gait_phase = fposmod(_gait_phase + TAU * cadence * _motion * delta, TAU)
	_bob_phase = _gait_phase * 2.0
	var basis: Basis = global_transform.basis.orthonormalized()
	var forward: Vector3 = -basis.z
	var up: Vector3 = basis.y
	var stride: float = clampf(_speed * STRIDE_PER_SPEED, STRIDE_MIN, STRIDE_MAX) * _activity
	for side: int in _hip_bones.size():
		var phase: float = _gait_phase + (PI if side == 1 else 0.0)
		var target: Vector3
		if _airborne:
			target = (
				_ideal_foot(side)
				+ up * (AIR_FOOT_LIFT + AIR_TUCK_LIFT * _air_tuck)
				+ forward * (AIR_TUCK_FORWARD * _air_tuck)
			)
		else:
			target = _ideal_foot(side) + _foot_offset(phase, stride, forward, up)
		_foot_targets[side] = target
		_solve_leg(side, _foot_targets[side])
		var cycle: float = fposmod(phase / TAU, 1.0)
		var planted: bool = cycle >= SWING_PORTION
		if planted and not _stance[side] and not _airborne and _activity > 0.15:
			_puff(side)
		if side < _stance.size():
			_stance[side] = planted


func _foot_offset(phase: float, stride: float, forward: Vector3, up: Vector3) -> Vector3:
	var cycle: float = fposmod(phase / TAU, 1.0)
	var lift: float = GAIT_LIFT * clampf(stride / STRIDE_MAX, 0.25, 1.0)
	if cycle < SWING_PORTION:
		var swing: float = cycle / SWING_PORTION
		var eased: float = smoothstep(0.0, 1.0, swing)
		var travel: float = lerpf(-0.5, 0.5, eased)
		return forward * travel * stride + up * sin(swing * PI) * lift
	var stance: float = (cycle - SWING_PORTION) / (1.0 - SWING_PORTION)
	return forward * lerpf(0.5, -0.5, stance) * stride


func _pose_arms(delta: float) -> void:
	if _skeleton == null or _arm_bones.is_empty():
		return
	var wanted: float = sin(_gait_phase + PI) * ARM_SWING * _activity
	_arm_swing = lerpf(_arm_swing, wanted, 1.0 - exp(-ARM_RESPONSE * delta))
	var axis: Vector3 = global_transform.basis.x
	for side: int in _arm_bones.size():
		var direction: float = -1.0 if side == 0 else 1.0
		var angle: float = _arm_swing * direction * (1.0 - _catch_amount)
		angle *= 1.0 - _smear_amount
		angle *= 1.0 - _water_amount
		angle += CATCH_ARM * _catch_amount + SMEAR_ARM * _smear_amount
		angle += HAMMER_ARM * _hammer_amount
		if side == 1:
			# The right arm holds the can out in front while the water runs.
			angle += WATER_ARM * _water_amount
		_swing_bone(_arm_bones[side], axis, angle)


func _update_pose(delta: float) -> void:
	if _rig == null:
		return
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var up: Vector3 = global_transform.basis.y.normalized()
	var turn: float = 0.0
	if _last_forward.length_squared() > 0.5 and delta > 0.0:
		turn = _last_forward.signed_angle_to(forward, up) / delta
	_last_forward = forward
	_spin_speed = lerpf(
		_spin_speed, SMEAR_SPIN * _smear_amount, 1.0 - exp(-SMEAR_SPIN_RAMP * delta)
	)
	_spin = wrapf(_spin + _spin_speed * delta, -PI, PI)
	if not _smearing and absf(_spin_speed) < 0.4:
		_spin = move_toward(_spin, 0.0, 6.0 * delta)
	var wanted_bank: float = 0.0
	if not _sitting and not _smearing:
		wanted_bank = clampf(turn * BANK_PER_TURN, -MAX_BANK, MAX_BANK)
	_bank = lerpf(_bank, wanted_bank, 1.0 - exp(-9.0 * delta))
	var wanted_pitch: float = 0.0
	if not _sitting and not _smearing:
		if _airborne:
			wanted_pitch = AIR_PITCH * _air_tuck
		else:
			wanted_pitch = RUN_PITCH * clampf(_activity, 0.0, 1.0)
	_pitch = lerpf(_pitch, wanted_pitch, 1.0 - exp(-PITCH_RESPONSE * delta))
	var pose: Quaternion = (
		Basis.from_euler(Vector3(_pitch, PI + _spin, _bank)).get_rotation_quaternion()
	)
	_rig.quaternion = _hang_quaternion() * pose


## Rotates the body so its up follows the rope: a boy hanging from a winch
## should hang, and near the ground the lean fades back to standing straight.
func _hang_quaternion() -> Quaternion:
	if _rig == null or _hang <= 0.001 or _pull.length_squared() < 0.000001:
		return Quaternion.IDENTITY
	var local: Vector3 = (global_transform.basis.inverse() * -_pull).normalized()
	if local.dot(Vector3.UP) < -0.999:
		local = Vector3(-1.0, 0.0, 0.0)
	return Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, local), clampf(_hang, 0.0, 1.0))


func _solve_leg(side: int, foot: Vector3) -> void:
	var body: Transform3D = _skeleton.global_transform
	var hip_bone: int = _hip_bones[side]
	var hip: Vector3 = (body * _skeleton.get_bone_global_pose(hip_bone)).origin
	var lengths: Vector2 = _leg_lengths[side] * body.basis.get_scale().y
	var upper: float = lengths.x
	var lower: float = lengths.y
	var to_foot: Vector3 = foot - hip
	var reach: float = upper + lower
	if to_foot.length() >= reach:
		_aim_bone(hip_bone, hip + to_foot.normalized() * upper)
		_aim_bone(_knee_bones[side], foot)
		return
	var distance: float = clampf(to_foot.length(), 0.02, reach * 0.985)
	var direction: Vector3 = to_foot.normalized()
	var forward: Vector3 = -global_transform.basis.z
	var bend: Vector3 = forward - direction * forward.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = global_transform.basis.x
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper * upper - along * along, 0.0))
	var knee: Vector3 = hip + direction * along + bend.normalized() * height
	_aim_bone(hip_bone, knee)
	_aim_bone(_knee_bones[side], foot)


func _aim_bone(bone: int, target: Vector3) -> void:
	if bone < 0:
		return
	var body: Transform3D = _skeleton.global_transform
	var pose: Transform3D = _skeleton.get_bone_global_pose(bone)
	var origin: Vector3 = pose.origin
	var current: Vector3 = pose.basis.orthonormalized().y.normalized()
	var desired: Vector3 = body.affine_inverse() * target - origin
	if desired.length_squared() < 0.000001:
		return
	var swing := Quaternion(current, desired.normalized())
	var basis: Basis = (Basis(swing) * pose.basis.orthonormalized()).orthonormalized()
	_skeleton.set_bone_global_pose(bone, Transform3D(basis, origin))


func _swing_bone(bone: int, axis: Vector3, angle: float) -> void:
	if _skeleton == null or bone < 0:
		return
	axis = axis.normalized()
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = Basis()
	if parent >= 0:
		parent_basis = (
			(_skeleton.global_transform * _skeleton.get_bone_global_pose(parent))
			. basis
			. orthonormalized()
		)
	var parent_rotation: Quaternion = parent_basis.get_rotation_quaternion()
	var rest: Quaternion = _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	var local: Quaternion = (
		parent_rotation.inverse() * Quaternion(axis, angle) * parent_rotation * rest
	)
	_skeleton.set_bone_pose_rotation(bone, local.normalized())


func _apply_catch_pose(amount: float) -> void:
	_catch_amount = clampf(amount, 0.0, 1.0)


func _apply_hammer_pose(amount: float) -> void:
	_hammer_amount = clampf(amount, 0.0, 1.0)


func _lean(amount: float) -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_method(_apply_lean, 0.0, amount, LEAN_TIME)


func _apply_lean(amount: float) -> void:
	_swing_bone(_body_bone, global_transform.basis.x, -SIT_LEAN * amount)


func _stretch() -> void:
	if _rig == null:
		return
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_rig, "scale", Vector3(0.95, 1.06, 0.95), 0.12)
	_squash_tween.tween_property(_rig, "scale", Vector3.ONE, 0.25)


func _land() -> void:
	for side: int in _foot_targets.size():
		_foot_targets[side] = _ideal_foot(side)


func _update_net(delta: float) -> void:
	if _skeleton == null or _claw_bone < 0:
		return
	if _net_swinging:
		_net_swing_time += delta
		_net_active = _net_swing_time >= NET_ACTIVE_START and _net_swing_time <= NET_ACTIVE_END
		if _net_swing_time >= NET_SWING_DURATION:
			_net_swinging = false
			_net_swing_time = 0.0
			_net_active = false
	var swing: float = _net_swing_amount()
	var body: Transform3D = _skeleton.global_transform
	var claw: Vector3 = (body * _skeleton.get_bone_global_pose(_claw_bone)).origin
	var body_scale: float = body.basis.get_scale().y
	var model_basis: Basis = global_transform.basis.orthonormalized()
	var forward: Vector3 = -model_basis.z
	var up: Vector3 = model_basis.y
	_catch_point = (
		claw
		+ forward * NET_CATCH_FORWARD * body_scale
		+ up * (NET_CATCH_HEIGHT + NET_SWING_LIFT * swing) * body_scale
	)


func _net_swing_amount() -> float:
	if not _net_swinging:
		return 0.0
	var t: float = _net_swing_time
	if t < 0.18:
		return smoothstep(0.0, 0.18, t)
	if t < 0.55:
		return 1.0
	return 1.0 - smoothstep(0.55, NET_SWING_DURATION, t)


func _foot_world(side: int) -> Vector3:
	var tip: Transform3D = _skeleton.get_bone_global_pose(_knee_bones[side])
	var shin: float = _leg_lengths[side].y
	return _skeleton.global_transform * (tip.origin + tip.basis.y.normalized() * shin)


func _puff(side: int) -> void:
	if side >= _step_dust.size():
		return
	var dust: GPUParticles3D = _step_dust[side]
	dust.global_position = _foot_world(side) + global_transform.basis.y * 0.012
	dust.restart()
	dust.emitting = true
	_steps += 1
	footstepped.emit(side)


func _build_dust() -> void:
	var texture := _soft_dot_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = _particle_material(texture)

	_smear_dust = GPUParticles3D.new()
	_smear_dust.name = "SmearDust"
	_smear_dust.amount = 56
	_smear_dust.lifetime = 1.45
	_smear_dust.local_coords = true
	_smear_dust.one_shot = false
	_smear_dust.emitting = false
	_smear_dust.position = Vector3(0.0, 0.12, -0.24)
	_smear_dust.draw_pass_1 = quad
	var pmat := _particle_process(
		Color(0.70, 0.56, 0.45, 0.80), 0.25, 0.85, Vector3(0.0, 0.55, -0.30)
	)
	pmat.spread = 110.0
	pmat.gravity = Vector3(0.0, -0.75, 0.0)
	pmat.scale_min = 0.45
	pmat.scale_max = 1.65
	_smear_dust.process_material = pmat
	add_child(_smear_dust)

	_land_dust = GPUParticles3D.new()
	_land_dust.name = "LandDust"
	_land_dust.amount = 18
	_land_dust.lifetime = 0.65
	_land_dust.local_coords = true
	_land_dust.one_shot = true
	_land_dust.explosiveness = 0.92
	_land_dust.emitting = false
	_land_dust.position = Vector3(0.0, 0.05, 0.0)
	_land_dust.draw_pass_1 = quad
	var lmat := _particle_process(Color(0.58, 0.49, 0.43, 0.7), 0.25, 0.85, Vector3(0.0, 0.5, 0.0))
	lmat.spread = 100.0
	lmat.gravity = Vector3(0.0, -1.2, 0.0)
	lmat.scale_min = 0.4
	lmat.scale_max = 1.4
	_land_dust.process_material = lmat
	add_child(_land_dust)

	var puff := QuadMesh.new()
	puff.size = Vector2(0.16, 0.16)
	puff.material = _particle_material(texture)
	for side: int in 2:
		var dust := GPUParticles3D.new()
		dust.name = "StepDust%s" % ("L" if side == 0 else "R")
		dust.amount = 7
		dust.lifetime = 0.38
		dust.one_shot = true
		dust.explosiveness = 0.95
		dust.local_coords = false
		dust.emitting = false
		dust.draw_pass_1 = puff
		var step_material := _particle_process(
			Color(0.84, 0.75, 0.63, 0.5), 0.2, 0.65, Vector3(0.0, 0.7, 0.0)
		)
		step_material.spread = 115.0
		step_material.gravity = Vector3(0.0, -0.22, 0.0)
		step_material.scale_min = 0.35
		step_material.scale_max = 0.85
		dust.process_material = step_material
		add_child(dust)
		_step_dust.append(dust)
		_stance.append(false)


func _particle_process(
	color: Color, speed_min: float, speed_max: float, direction: Vector3
) -> ParticleProcessMaterial:
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = direction
	pmat.initial_velocity_min = speed_min
	pmat.initial_velocity_max = speed_max
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.08
	pmat.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.18, color)
	ramp.add_point(0.55, Color(color.r, color.g, color.b, color.a * 0.55))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	pmat.color_ramp = ramp_texture
	return pmat


func _particle_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = false
	return material


func _soft_dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
