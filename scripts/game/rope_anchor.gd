class_name RopeAnchor
extends Node3D

## The small stake the boy hammers into the ground, plus the rope that ties him
## to it. The rope is a plain distance limit: it never changes the boy's physics
## until it is fully stretched, and then it stops him and throws him back
## instead of letting him drift off. The cord itself is the shortest path that
## fits: a straight line while it clears the planet, otherwise the ground arc
## plus the tangent up to his hand, so it drapes and the winch follows what is
## actually drawn instead of cutting through the air.

signal planted
signal removed
signal snapped(force: float)

const ROPE_FRACTION: float = 0.95
const STAKE_HEIGHT: float = 0.5
const STAKE_SINK: float = 0.06
const ROPE_RADIUS: float = 0.01
const ROPE_POINTS_MAX: int = 96
const ROPE_REEL_SPAN: float = 6.0
const ROPE_REEL_SHARE: float = 0.3
const ROPE_MIN_SPACING: float = 0.5
const ROPE_SEGMENT_MIN: float = 0.2
const ROPE_SPACING_RATIO: float = 0.02
const ROPE_SLACK: float = 0.005
const ROPE_CLEARANCE: float = 0.06
const ROPE_GROUND_STEP: float = 0.05
const WOOD := Color("7b5c45")
const WOOD_DARK := Color("5c4433")
const ROPE_COLOR := Color("cdb38d")
const IRON := Color("4f4a52")

var planet: Planet
var player: Boy

var _planted: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _stake: Node3D
var _rope: MultiMeshInstance3D
var _points: PackedVector3Array = PackedVector3Array()
var _reel: Vector3 = Vector3.ZERO
var _pin: Vector3 = Vector3.ZERO
var _previous: PackedVector3Array = PackedVector3Array()
var _segment: float = 0.25
var _shown: int = 0
var _pending: float = 0.0


func setup(p_planet: Planet, p_player: Boy) -> void:
	planet = p_planet
	player = p_player
	if planet != null and not planet.radius_changed.is_connected(_on_radius_changed):
		planet.radius_changed.connect(_on_radius_changed)


func is_planted() -> bool:
	return _planted


func get_anchor_position() -> Vector3:
	return _anchor


func get_rope_points() -> PackedVector3Array:
	return _points


## The way home is along the cord, not through the air to the stake: the first
## few metres of rope behind the boy's hand are what a winch would wind in.
func peek_reel_direction() -> Vector3:
	if _reel.length_squared() > 0.5:
		return _reel
	if player == null:
		return Vector3.ZERO
	return (_anchor - player.global_position).normalized()


func get_reel_direction() -> Vector3:
	var count: int = _points.size()
	if count < 3:
		if player == null:
			return Vector3.ZERO
		return (_anchor - player.global_position).normalized()
	var hand: Vector3 = _points[count - 1]
	var span: float = 0.0
	for index: int in count - 1:
		span += _points[index].distance_to(_points[index + 1])
	span = clampf(span * ROPE_REEL_SHARE, 1.0, ROPE_REEL_SPAN)
	var travelled: float = 0.0
	var index: int = count - 1
	while index > 0 and travelled < span:
		travelled += _points[index].distance_to(_points[index - 1])
		index -= 1
	var along: Vector3 = _points[index] - hand
	if along.length_squared() < 0.0001:
		along = _anchor - hand
	along = along.normalized()
	if _reel.length_squared() < 0.5:
		_reel = along
	else:
		_reel = _reel.lerp(along, 0.25).normalized()
	return _reel


func debug_advance(seconds: float) -> void:
	if not _planted or planet == null or player == null:
		return
	var step: float = 1.0 / 60.0
	var from: Vector3 = _stake_top()
	var to: Vector3 = _hand_point()
	for _index: int in int(ceil(seconds / step)):
		_spool(step, from, to)
		_step(step, from, to)
	_draw_rope()


func get_max_length() -> float:
	if planet == null:
		return 0.0
	return PlanetProfile.death_altitude(planet.radius) * ROPE_FRACTION


func plant(surface_position: Vector3) -> void:
	if planet == null:
		return
	var up: Vector3 = (surface_position - planet.get_center()).normalized()
	if up.length_squared() < 0.1:
		up = Vector3.UP
	_anchor = planet.get_center() + up * planet.radius
	_planted = true
	_reel = Vector3.ZERO
	_pin = Vector3.ZERO
	_build_stake(up)
	_build_rope()
	planted.emit()


func clear() -> void:
	if not _planted:
		return
	_planted = false
	_reel = Vector3.ZERO
	_pin = Vector3.ZERO
	if _stake != null:
		_stake.queue_free()
		_stake = null
	if _rope != null:
		_rope.queue_free()
		_rope = null
	removed.emit()


func notify_snap(force: float) -> void:
	snapped.emit(force)


func _process(delta: float) -> void:
	if not _planted or _rope == null or planet == null or player == null:
		return
	var from: Vector3 = _stake_top()
	var to: Vector3 = _hand_point()
	if from.distance_to(to) <= 0.03:
		_rope.visible = false
		_hide_segments(0)
		return
	_rope.visible = true
	if _points.size() < 4:
		_reset_rope()
	var step: float = 1.0 / 60.0
	_pending = minf(_pending + delta, step * 3.0)
	var taken: int = 0
	while _pending >= step and taken < 3:
		_spool(step, from, to)
		_step(step, from, to)
		_pending -= step
		taken += 1
	if taken > 0:
		_draw_rope()


func _on_radius_changed(_new_radius: float) -> void:
	if not _planted or planet == null:
		return
	var up: Vector3 = (_anchor - planet.get_center()).normalized()
	_anchor = planet.get_center() + up * planet.radius
	if _stake != null:
		_stake.global_transform = Transform3D(
			Basis(Quaternion(Vector3.UP, up)), _anchor - up * STAKE_SINK
		)
	_reset_rope()


func _build_stake(up: Vector3) -> void:
	if _stake != null:
		_stake.queue_free()
	_stake = Node3D.new()
	_stake.name = "Stake"
	add_child(_stake)
	_stake.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, up)), _anchor - up * STAKE_SINK
	)

	var wood: StandardMaterial3D = _material(WOOD, 0.92)
	var dark: StandardMaterial3D = _material(WOOD_DARK, 0.94)
	var iron: StandardMaterial3D = _material(IRON, 0.55)

	var post := CylinderMesh.new()
	post.top_radius = 0.022
	post.bottom_radius = 0.03
	post.height = STAKE_HEIGHT
	post.radial_segments = 10
	post.rings = 3
	_add_mesh(_stake, post, wood, Vector3(0.0, STAKE_HEIGHT * 0.5, 0.0))

	var cap := CylinderMesh.new()
	cap.top_radius = 0.035
	cap.bottom_radius = 0.028
	cap.height = 0.05
	cap.radial_segments = 10
	_add_mesh(_stake, cap, iron, Vector3(0.0, STAKE_HEIGHT - 0.015, 0.0))

	var band := CylinderMesh.new()
	band.top_radius = 0.032
	band.bottom_radius = 0.032
	band.height = 0.016
	band.radial_segments = 10
	_add_mesh(_stake, band, dark, Vector3(0.0, STAKE_HEIGHT - 0.07, 0.0))

	var peg := CylinderMesh.new()
	peg.top_radius = 0.014
	peg.bottom_radius = 0.008
	peg.height = 0.04
	peg.radial_segments = 8
	var peg_node := _add_mesh(_stake, peg, iron, Vector3(0.0, STAKE_HEIGHT - 0.1, 0.03))
	peg_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	_stake.scale = Vector3(1.0, 0.25, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_stake, "scale", Vector3.ONE, 0.22)


func _build_rope() -> void:
	if _rope != null:
		_rope.queue_free()
	_rope = MultiMeshInstance3D.new()
	_rope.name = "Rope"
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.material_override = _material(ROPE_COLOR, 0.88)
	var segment := CylinderMesh.new()
	segment.top_radius = ROPE_RADIUS
	segment.bottom_radius = ROPE_RADIUS
	segment.height = 1.0
	segment.radial_segments = 6
	segment.rings = 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = segment
	multimesh.instance_count = ROPE_POINTS_MAX
	_rope.multimesh = multimesh
	add_child(_rope)
	_hide_segments(0)
	_reset_rope()


func _reset_rope() -> void:
	if planet == null or player == null or _rope == null:
		return
	_pin = Vector3.ZERO
	var from: Vector3 = _stake_top()
	var to: Vector3 = _hand_point()
	var path: PackedVector3Array = _tangent_path(from, to)
	var length: float = 0.0
	for index: int in path.size() - 1:
		length += path[index].distance_to(path[index + 1])
	var count: int = clampi(int(ceil(length / ROPE_SEGMENT_MIN)) + 1, 8, ROPE_POINTS_MAX)
	_points = _resample(path, count)
	_previous = _points.duplicate()
	_segment = maxf(_points[0].distance_to(_points[1]), 0.05)
	_pending = 0.0
	_draw_rope()


func _stake_top() -> Vector3:
	var up: Vector3 = planet.get_center().direction_to(_anchor)
	if up.length_squared() < 0.1:
		up = Vector3.UP
	return _anchor + up * ROPE_CLEARANCE


func _hand_point() -> Vector3:
	var target: Vector3 = player.get_hand_position()
	if _pin == Vector3.ZERO or _pin.distance_to(target) > 2.0:
		_pin = target
	else:
		_pin = _pin.lerp(target, 0.2)
	# A smoothed pin may lag behind a teleport; it must never sink into the world.
	var centre: Vector3 = planet.get_center()
	var contact: float = planet.radius + ROPE_CLEARANCE
	var offset: Vector3 = _pin - centre
	if offset.length() < contact:
		_pin = centre + offset.normalized() * contact
	return _pin


## The winch pays line out quickly and reels it back slowly, so the chain always
## has just enough length to reach the boy plus a hand of slack to sag with.
func _spool(_delta: float, from: Vector3, to: Vector3) -> bool:
	var straight: float = from.distance_to(to)
	var target: float = maxf(_path_length(from, to) + ROPE_SLACK, straight + 0.01)
	target = clampf(target, 0.3, get_max_length())
	_fit_count(target)
	var wanted: float = target / float(_points.size() - 1)
	var before: float = _segment
	_segment = wanted
	return not is_equal_approx(before, _segment)


## One position-based step: gravity, then the chain is pulled back to its
## segment length against the planet, and the ground drags on whatever touches
## it. Friction is what stops the rope from skating across the world.
## The length of the shortest cord that actually fits: a straight line while
## that line clears the planet, and otherwise the ground arc plus the tangent
## up to the hand. Handing it the arc plus the rise even when he is right next
## to the stake is what used to leave a short rope bulging.
func _path_length(from: Vector3, to: Vector3) -> float:
	var centre: Vector3 = planet.get_center()
	var rest: float = planet.radius + ROPE_CLEARANCE
	var from_dir: Vector3 = (from - centre).normalized()
	var to_dir: Vector3 = (to - centre).normalized()
	var reach: float = (to - centre).length()
	var angle: float = from_dir.angle_to(to_dir)
	var theta: float = angle
	if reach > rest + 0.0005:
		theta = acos(clampf(rest / reach, 0.0, 1.0))
	if angle < 0.0005 or theta >= angle:
		return from.distance_to(to)
	var drop: float = maxf((from - centre).length() - rest, 0.0)
	return drop + rest * (angle - theta) + sqrt(maxf(reach * reach - rest * rest, 0.0))


## A chain whose masses sit centimetres apart cannot follow a hand that moves
## faster than they do: the pin jumps past them and the cord folds. Short ropes
## therefore get fewer, longer links, and only a change of a quarter in the
## count is worth re-cutting the chain for.
func _fit_count(length: float) -> void:
	var wanted: int = clampi(int(ceil(length / ROPE_SEGMENT_MIN)) + 1, 8, ROPE_POINTS_MAX)
	var current: int = _points.size()
	if absi(wanted - current) <= maxi(2, current / 4):
		return
	_points = _resample(_points, wanted)
	var centre: Vector3 = planet.get_center()
	var contact: float = planet.radius + ROPE_CLEARANCE
	for index: int in _points.size():
		var offset: Vector3 = _points[index] - centre
		if offset.length() < contact:
			_points[index] = centre + offset.normalized() * contact
	_previous = _points.duplicate()


func _step(_delta: float, from: Vector3, to: Vector3) -> void:
	var path: PackedVector3Array = _tangent_path(from, to)
	if path.size() < 2:
		return
	_points = _resample(path, _points.size())
	_points[0] = from
	_points[_points.size() - 1] = to
	_previous = _points.duplicate()


func _draw_rope() -> void:
	if _rope == null:
		return
	var segments: int = mini(_points.size() - 1, ROPE_POINTS_MAX)
	for index: int in segments:
		var a: Vector3 = _points[index]
		var b: Vector3 = _points[index + 1]
		var span: Vector3 = b - a
		var length: float = span.length()
		if length < 0.0005:
			_rope.multimesh.set_instance_transform(index, _hidden_transform())
			continue
		var basis: Basis = (
			Basis(Quaternion(Vector3.UP, span / length))
			* Basis.from_scale(Vector3(1.0, length, 1.0))
		)
		_rope.multimesh.set_instance_transform(index, Transform3D(basis, (a + b) * 0.5))
	if segments < _shown:
		_hide_segments(segments)
	_shown = segments


## The starting shape the chain is handed on the first frame: off the stake,
## along the ground, and lifted only where the straight pull to the boy stops
## touching the planet.
func _tangent_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var centre: Vector3 = planet.get_center()
	var path: PackedVector3Array = PackedVector3Array()
	path.append(from)
	var rest: float = planet.radius + ROPE_CLEARANCE
	var from_dir: Vector3 = (from - centre).normalized()
	var to_dir: Vector3 = (to - centre).normalized()
	var reach: float = (to - centre).length()
	var angle: float = from_dir.angle_to(to_dir)
	var theta: float = angle
	if reach > rest + 0.0005:
		theta = acos(clampf(rest / reach, 0.0, 1.0))
	if angle < 0.0005 or theta >= angle:
		path.append(to)
		return path
	var ground_angle: float = angle - theta
	var steps: int = clampi(int(ceil(ground_angle / ROPE_GROUND_STEP)), 3, 160)
	var tangent: Vector3 = to_dir.slerp(from_dir, theta / angle).normalized()
	for step: int in steps:
		var blend: float = float(step) / float(steps)
		var direction: Vector3 = from_dir.slerp(tangent, blend).normalized()
		path.append(centre + direction * rest)
	path.append(to)
	return path


func _resample(path: PackedVector3Array, count: int) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var lengths: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	lengths.append(0.0)
	for index: int in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
		lengths.append(total)
	if total < 0.0001 or count < 2:
		result.resize(count)
		return result
	var cursor: int = 0
	for step: int in count:
		var wanted: float = total * float(step) / float(count - 1)
		while cursor < lengths.size() - 2 and lengths[cursor + 1] < wanted:
			cursor += 1
		var span: float = lengths[cursor + 1] - lengths[cursor]
		var blend: float = 0.0 if span < 0.00001 else (wanted - lengths[cursor]) / span
		result.append(path[cursor].lerp(path[cursor + 1], clampf(blend, 0.0, 1.0)))
	return result


func _hide_segments(from: int) -> void:
	var hidden: Transform3D = _hidden_transform()
	for index: int in range(from, ROPE_POINTS_MAX):
		_rope.multimesh.set_instance_transform(index, hidden)
	_shown = from


func _hidden_transform() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = offset
	parent.add_child(node)
	return node
