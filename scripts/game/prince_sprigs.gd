class_name PrinceSprigs
extends Node3D

const CHAIN_ROOTS: Array[StringName] = [&"vine_L_01", &"vine_R_01", &"stem_01", &"spike_01"]
const MAX_BONES: int = 3
const CONSTRAINT_PASSES: int = 4
const MAX_STEP: float = 1.0 / 30.0
const MAX_SPEED: float = 8.0

const VINE_STIFFNESS: float = 150.0
const VINE_DRAG: float = 8.5
const VINE_LAG: float = 0.5
const VINE_SAG: float = 1.6
const VINE_SWAY: float = 10.0
const VINE_DIP: float = 6.0
const STEM_SWAY_SHARE: float = 0.4
const IDLE_SWAY: float = 1.5
const IDLE_RATE: float = 2.2
const TURN_GAIN: float = 0.06
const TURN_MAX: float = 0.15
const TURN_ATTACK: float = 8.0
const TURN_RELEASE: float = 2.5

const STEM_STIFFNESS: float = 260.0
const STEM_DRAG: float = 10.5
const STEM_LAG: float = 0.5
const STEM_SAG: float = 0.6

const MIN_DIRECTION: float = 0.000001

var _skeleton: Skeleton3D
var _chains: Array[PackedInt32Array] = []
var _roots: PackedInt32Array = PackedInt32Array()
var _lengths: Array[PackedFloat32Array] = []
var _rest_points: Array[PackedVector3Array] = []
var _rest_basis: Array[PackedVector3Array] = []
var _points: Array[PackedVector3Array] = []
var _velocities: Array[PackedVector3Array] = []
var _lag_limits: PackedFloat32Array = PackedFloat32Array()
var _stiffness: PackedFloat32Array = PackedFloat32Array()
var _drag: PackedFloat32Array = PackedFloat32Array()
var _sag: PackedFloat32Array = PackedFloat32Array()
var _activity: float = 0.0
var _phase: float = 0.0
var _turn: float = 0.0
var _turn_target: float = 0.0
var _time: float = 0.0
var _built: bool = false


func setup(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	for root: StringName in CHAIN_ROOTS:
		_build_chain(root)
	_built = not _chains.is_empty()


func is_active() -> bool:
	return _built


func set_gait(activity: float, phase: float) -> void:
	_activity = clampf(activity, 0.0, 1.0)
	_phase = phase


## How fast the body is spinning, so the tips can fling outward in turns.
## The angle eases toward the target instead of snapping with every step.
func set_turn(rate: float) -> void:
	_turn_target = clampf(rate * TURN_GAIN, -TURN_MAX, TURN_MAX)


func _build_chain(root: StringName) -> void:
	var stem: bool = _is_stem(root)
	var stiffness: float = STEM_STIFFNESS if stem else VINE_STIFFNESS
	var drag: float = STEM_DRAG if stem else VINE_DRAG
	var lag: float = STEM_LAG if stem else VINE_LAG
	var sag: float = STEM_SAG if stem else VINE_SAG
	var chain := PackedInt32Array()
	var bone: int = _skeleton.find_bone(root)
	if bone < 0:
		return
	chain.append(bone)
	while chain.size() < MAX_BONES:
		var child: int = _first_child_bone(bone)
		if child < 0:
			break
		chain.append(child)
		bone = child
	if chain.size() < 2:
		return
	var points := PackedVector3Array()
	var basis_list := PackedVector3Array()
	for part: int in chain:
		var rest: Transform3D = _skeleton.get_bone_global_rest(part)
		points.append(rest.origin)
		var orthonormal: Basis = rest.basis.orthonormalized()
		basis_list.append(orthonormal.x)
		basis_list.append(orthonormal.y)
		basis_list.append(orthonormal.z)
	var last: Transform3D = _skeleton.get_bone_global_rest(chain[chain.size() - 1])
	var tip_length: float = points[points.size() - 1].distance_to(points[points.size() - 2])
	points.append(points[points.size() - 1] + last.basis.y.normalized() * tip_length)
	var lengths := PackedFloat32Array()
	for index: int in points.size() - 1:
		lengths.append(points[index].distance_to(points[index + 1]))
	var parent: int = _skeleton.get_bone_parent(chain[0])
	var carried: Transform3D = _skeleton.global_transform
	if parent >= 0:
		carried *= (
			_skeleton.get_bone_global_pose(parent)
			* _skeleton.get_bone_global_rest(parent).affine_inverse()
		)
	var world_points := PackedVector3Array()
	for point: Vector3 in points:
		world_points.append(carried * point)
	_chains.append(chain)
	_roots.append(parent)
	_lengths.append(lengths)
	_rest_points.append(points)
	_rest_basis.append(basis_list)
	_points.append(world_points)
	_velocities.append(_zeroes(points.size()))
	_lag_limits.append(lengths[0] * chain.size() * lag)
	_stiffness.append(stiffness)
	_drag.append(drag)
	_sag.append(sag)


func _zeroes(count: int) -> PackedVector3Array:
	var values := PackedVector3Array()
	values.resize(count)
	return values


func _is_stem(root: StringName) -> bool:
	return String(root).begins_with("stem")


func _first_child_bone(bone: int) -> int:
	for other: int in _skeleton.get_bone_count():
		if _skeleton.get_bone_parent(other) == bone:
			return other
	return -1


func _process(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	var step: float = minf(delta, MAX_STEP)
	_time += step
	# Fast attack, slow release: a turn is caught the frame it happens, and
	# the tips trail off after it instead of snapping back with the next frame.
	var rate: float = TURN_ATTACK if absf(_turn_target) > absf(_turn) else TURN_RELEASE
	_turn = lerpf(_turn, _turn_target, 1.0 - exp(-rate * step))
	# Two half steps: stiff springs ring on a single explicit step, and the
	# ringing reads as jitter on the shortest chains.
	var half: float = step * 0.5
	for chain: int in _chains.size():
		_simulate(chain, half)
		_simulate(chain, half)
		_apply(chain)


func _carry(chain: int) -> Transform3D:
	var parent: int = _roots[chain]
	if parent < 0:
		return Transform3D.IDENTITY
	return (
		_skeleton.get_bone_global_pose(parent)
		* _skeleton.get_bone_global_rest(parent).affine_inverse()
	)


## The rest pose, rocked by the walk: each side swings against its own
## footfall, the stem bounces along at a share of it, turns roll the tips
## outward, and standing still leaves a slow idle breath so nothing hangs dead.
func _sway(chain: int, world: Transform3D) -> Basis:
	var root_name: StringName = _skeleton.get_bone_name(_chains[chain][0])
	var stem: bool = _is_stem(root_name)
	var share: float = STEM_SWAY_SHARE if stem else 1.0
	var step: float = _phase * 2.0
	if not stem and String(root_name).contains("_R"):
		step += PI
	var fore: float = sin(step) * VINE_SWAY * _activity
	var dip: float = cos(step) * VINE_DIP * _activity
	if _activity <= 0.01:
		fore = sin(_time * IDLE_RATE + float(chain) * 2.1) * IDLE_SWAY
		dip = cos(_time * IDLE_RATE * 0.83 + float(chain)) * IDLE_SWAY * 0.6
	var x_axis: Vector3 = world.basis.x.normalized()
	var z_axis: Vector3 = world.basis.z.normalized()
	var fore_aft := Basis(x_axis, deg_to_rad(fore))
	var bounce := Basis(z_axis, deg_to_rad(dip))
	var roll := Basis(-z_axis, _turn * share)
	return roll * bounce * fore_aft


func _simulate(chain: int, step: float) -> void:
	var points: PackedVector3Array = _points[chain]
	var velocities: PackedVector3Array = _velocities[chain]
	var rest: PackedVector3Array = _rest_points[chain]
	var lengths: PackedFloat32Array = _lengths[chain]
	var world: Transform3D = _skeleton.global_transform
	var carried: Transform3D = world * _carry(chain)
	var scale: float = world.basis.get_scale().y
	var gravity: Vector3 = -world.basis.y.normalized() * _sag[chain]
	var decay: float = exp(-_drag[chain] * step)
	var sway: Basis = _sway(chain, world)
	var anchor: Vector3 = carried * rest[0]
	points[0] = anchor
	velocities[0] = Vector3.ZERO
	for index: int in range(1, points.size()):
		var target: Vector3 = anchor + sway * (carried * rest[index] - anchor)
		var acceleration: Vector3 = (target - points[index]) * _stiffness[chain] + gravity
		var velocity: Vector3 = (velocities[index] + acceleration * step) * decay
		if velocity.length() > MAX_SPEED:
			velocity = velocity.normalized() * MAX_SPEED
		velocities[index] = velocity
		points[index] = points[index] + velocity * step
	for _pass: int in CONSTRAINT_PASSES:
		for index: int in range(1, points.size()):
			var direction: Vector3 = points[index] - points[index - 1]
			var length: float = direction.length()
			if length < MIN_DIRECTION:
				continue
			points[index] = points[index - 1] + direction / length * lengths[index - 1] * scale
	var limit: float = _lag_limits[chain] * scale
	for index: int in range(1, points.size()):
		var rest_point: Vector3 = anchor + sway * (carried * rest[index] - anchor)
		points[index] = rest_point + (points[index] - rest_point).limit_length(limit)
	_points[chain] = points
	_velocities[chain] = velocities


func _apply(chain: int) -> void:
	var chain_bones: PackedInt32Array = _chains[chain]
	var rest: PackedVector3Array = _rest_points[chain]
	var basis_list: PackedVector3Array = _rest_basis[chain]
	var points: PackedVector3Array = _points[chain]
	var world: Transform3D = _skeleton.global_transform
	var carried: Transform3D = _carry(chain)
	var carried_basis: Basis = carried.basis.orthonormalized()
	var inverse: Basis = world.basis.orthonormalized().inverse()
	for segment: int in chain_bones.size():
		var direction: Vector3 = inverse * (points[segment + 1] - points[segment])
		if direction.length_squared() < MIN_DIRECTION:
			continue
		var rest_direction: Vector3 = (rest[segment + 1] - rest[segment]).normalized()
		var swing := Quaternion(
			(carried_basis * rest_direction).normalized(), direction.normalized()
		)
		var basis := Basis(
			basis_list[segment * 3], basis_list[segment * 3 + 1], basis_list[segment * 3 + 2]
		)
		var desired: Basis = Basis(swing) * (carried_basis * basis).orthonormalized()
		var origin: Vector3 = carried * rest[segment]
		_skeleton.set_bone_global_pose(
			chain_bones[segment], Transform3D(desired.orthonormalized(), origin)
		)
