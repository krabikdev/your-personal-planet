class_name PrinceCloak
extends Node3D

const BONE_PREFIX: String = "cape_"
const LEAN_SPRING: float = 38.0
const LEAN_DAMPING: float = 6.8
const TWIST_SPRING: float = 34.0
const TWIST_DAMPING: float = 6.0
const MAX_LEAN: float = 30.0
const MAX_TWIST: float = 10.0
const LEAN_PER_SPEED: float = 5.2
const TWIST_PER_TURN: float = 0.08
const BEND_POWER: float = 1.7
const HEM_LAG: float = 0.4
const RIPPLE: float = 8.0
const RIPPLE_LAG: float = 0.9
const RIPPLE_SPEED: float = 3.4
const FLARE_MAX: float = 16.0
const FLARE_POWER: float = 1.15
const FALL_SPEED: float = 9.0
const FLARE_RESPONSE: float = 3.2
const LOG_LIMIT: float = 0.5
const MIN_DIRECTION: float = 0.000001

var _skeleton: Skeleton3D
var _body_bone: int = -1
var _columns: int = 0
var _rows: int = 0
var _bones: PackedInt32Array = PackedInt32Array()
var _rest_points: PackedVector3Array = PackedVector3Array()
var _rest_basis: Array[Basis] = []
var _factors: PackedFloat32Array = PackedFloat32Array()
var _column_axes: Array[Vector3] = []
var _pivot: Vector3 = Vector3.ZERO
var _lean: Vector3 = Vector3.ZERO
var _lean_velocity: Vector3 = Vector3.ZERO
var _twist: float = 0.0
var _twist_velocity: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _last_forward: Vector3 = Vector3.ZERO
var _has_history: bool = false
var _clock: float = 0.0
var _stamps: PackedFloat32Array = PackedFloat32Array()
var _lean_log: Array[Vector3] = []
var _twist_log: PackedFloat32Array = PackedFloat32Array()
var _sample_lean: Vector3 = Vector3.ZERO
var _sample_twist: float = 0.0
var _activity: float = 0.0
var _ripple_phase: float = 0.0
var _flare: float = 0.0
var _built: bool = false


func _ready() -> void:
	process_priority = 10


func setup(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_body_bone = skeleton.find_bone("body")
	var found: int = 0
	var max_column: int = -1
	var max_row: int = -1
	for bone: int in skeleton.get_bone_count():
		var name: String = skeleton.get_bone_name(bone)
		if not name.begins_with(BONE_PREFIX):
			continue
		var parts: PackedStringArray = name.substr(BONE_PREFIX.length()).split("_")
		if parts.size() < 2:
			continue
		found += 1
		max_column = maxi(max_column, parts[0].to_int())
		max_row = maxi(max_row, parts[1].to_int())
	_columns = max_column + 1
	_rows = max_row + 1
	var count: int = _columns * _rows
	if _rows < 2 or found != count:
		return
	_bones.resize(count)
	_rest_points.resize(count)
	_rest_basis.resize(count)
	_factors.resize(count)
	for column: int in _columns:
		for row: int in _rows:
			var index: int = _flat(column, row)
			var bone: int = _skeleton.find_bone("cape_%02d_%02d" % [column, row])
			if bone < 0:
				return
			_bones[index] = bone
			var rest: Transform3D = _skeleton.get_bone_global_rest(bone)
			_rest_points[index] = rest.origin
			_rest_basis[index] = rest.basis.orthonormalized()
			_factors[index] = pow(float(row) / float(_rows - 1), BEND_POWER)
	_pivot = Vector3.ZERO
	for column: int in _columns:
		_pivot += _rest_points[_flat(column, 0)]
	_pivot /= float(_columns)
	_column_axes.clear()
	for column: int in _columns:
		var middle: Vector3 = _rest_points[_flat(column, _rows / 2)]
		var radial: Vector3 = middle - _pivot
		radial -= Vector3.UP * radial.dot(Vector3.UP)
		if radial.length_squared() < 0.000001:
			radial = Vector3.RIGHT if column < _columns / 2 else Vector3.LEFT
		_column_axes.append(Vector3.UP.cross(radial.normalized()))
	_built = true
	_lean_log.append(Vector3.ZERO)
	_twist_log.append(0.0)
	_stamps.append(0.0)
	_apply()


func is_active() -> bool:
	return _built


func set_velocity(value: Vector3) -> void:
	_velocity = value


func set_gait(activity: float) -> void:
	_activity = clampf(activity, 0.0, 1.0)


func _flat(column: int, row: int) -> int:
	return column * _rows + row


func _process(delta: float) -> void:
	if not _built or _skeleton == null or delta <= 0.0:
		return
	_clock += delta
	_ripple_phase += delta * RIPPLE_SPEED * (0.25 + 0.75 * _activity)
	var frame: Transform3D = _skeleton.global_transform
	var forward: Vector3 = -frame.basis.z.normalized()
	var up: Vector3 = frame.basis.y.normalized()
	if _has_history:
		var flat: Vector3 = _velocity - up * _velocity.dot(up)
		var turn: float = _last_forward.signed_angle_to(forward, up) / delta
		var wanted_lean := Vector3.ZERO
		var axis: Vector3 = up.cross(flat.normalized())
		if flat.length() > 0.05 and axis.length_squared() > MIN_DIRECTION:
			wanted_lean = axis.normalized() * clampf(flat.length() * LEAN_PER_SPEED, 0.0, MAX_LEAN)
		_lean_velocity += (wanted_lean - _lean) * LEAN_SPRING * delta
		_lean_velocity *= exp(-LEAN_DAMPING * delta)
		_lean += _lean_velocity * delta
		if _lean.length() > MAX_LEAN:
			_lean = _lean.normalized() * MAX_LEAN
		var wanted_twist: float = clampf(turn * TWIST_PER_TURN, -MAX_TWIST, MAX_TWIST)
		_twist_velocity += (wanted_twist - _twist) * TWIST_SPRING * delta
		_twist_velocity *= exp(-TWIST_DAMPING * delta)
		_twist = clampf(_twist + _twist_velocity * delta, -MAX_TWIST, MAX_TWIST)
		var falling: float = clampf(-_velocity.dot(up) / FALL_SPEED, 0.0, 1.0)
		_flare = lerpf(_flare, falling, 1.0 - exp(-FLARE_RESPONSE * delta))
		_record()
	_last_forward = forward
	_has_history = true
	_apply()


func _record() -> void:
	_stamps.append(_clock)
	_lean_log.append(_lean)
	_twist_log.append(_twist)
	while _stamps.size() > 2 and _stamps[0] < _clock - LOG_LIMIT:
		_stamps.remove_at(0)
		_lean_log.remove_at(0)
		_twist_log.remove_at(0)


func _sample(time: float) -> void:
	_sample_lean = _lean
	_sample_twist = _twist
	var count: int = _stamps.size()
	if count < 2 or time >= _stamps[count - 1]:
		return
	if time <= _stamps[0]:
		_sample_lean = _lean_log[0]
		_sample_twist = _twist_log[0]
		return
	for index: int in range(count - 1, 0, -1):
		if _stamps[index - 1] > time:
			continue
		var span: float = _stamps[index] - _stamps[index - 1]
		var weight: float = 0.0 if span <= 0.0 else (time - _stamps[index - 1]) / span
		_sample_lean = _lean_log[index - 1].lerp(_lean_log[index], weight)
		_sample_twist = lerpf(_twist_log[index - 1], _twist_log[index], weight)
		return


func _carry() -> Transform3D:
	if _skeleton == null or _body_bone < 0:
		return Transform3D.IDENTITY
	return (
		_skeleton.get_bone_global_pose(_body_bone)
		* _skeleton.get_bone_global_rest(_body_bone).affine_inverse()
	)


func _apply() -> void:
	var carry: Transform3D = _carry()
	var carried_basis: Basis = carry.basis.orthonormalized()
	var up: Vector3 = (carried_basis * Vector3.UP).normalized()
	var pivot: Vector3 = carry * _pivot
	var skeleton_inverse: Basis = _skeleton.global_transform.basis.orthonormalized().inverse()
	var right: Vector3 = (carried_basis * Vector3.RIGHT).normalized()
	var flare_angle: float = deg_to_rad(FLARE_MAX * clampf(_flare, 0.0, 1.0))
	for column: int in _columns:
		var tangent: Vector3 = (carried_basis * _column_axes[column]).normalized()
		for row: int in _rows:
			var index: int = _flat(column, row)
			var factor: float = _factors[index]
			var rotation := Basis()
			if flare_angle > 0.0001 and row > 0:
				var flare_part: float = pow(float(row) / float(_rows - 1), FLARE_POWER)
				rotation = Basis(-tangent, flare_angle * flare_part)
			_sample(_clock - HEM_LAG * factor)
			var lean: Vector3 = _sample_lean * factor
			if lean.length() > 0.01:
				var axis: Vector3 = skeleton_inverse * lean.normalized()
				rotation = Basis(axis.normalized(), deg_to_rad(lean.length())) * rotation
			rotation = Basis(up, deg_to_rad(_sample_twist * factor)) * rotation
			if _activity > 0.0 and row > 0:
				var ripple: float = (
					sin(_ripple_phase - float(row) * RIPPLE_LAG) * RIPPLE * _activity * factor
				)
				if absf(ripple) > 0.01:
					rotation = Basis(right, deg_to_rad(ripple)) * rotation
			var origin: Vector3 = pivot + rotation * (carry * _rest_points[index] - pivot)
			_skeleton.set_bone_global_pose(
				_bones[index], Transform3D(rotation * carried_basis * _rest_basis[index], origin)
			)
