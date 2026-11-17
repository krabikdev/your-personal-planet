class_name RopeAnchor
extends Node3D

## The stake the boy hammers into the ground, plus the rope that ties him to it.
## The rope is a plain distance limit: it does nothing while slack, and once it
## is taut it stops the boy and throws him back instead of letting him drift off.

signal planted
signal snapped(force: float)

const ROPE_FRACTION: float = 0.95
const STAKE_HEIGHT: float = 1.25
const ROPE_RADIUS: float = 0.012
const HAND_HEIGHT: float = 0.55
const ROPE_SAG: float = 0.22
const WOOD := Color("7b5c45")
const WOOD_DARK := Color("5c4433")
const ROPE_COLOR := Color("cdb38d")
const IRON := Color("4f4a52")

var planet: Planet
var player: Boy

var _planted: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _stake: Node3D
var _rope_segments: Array[MeshInstance3D] = []


func setup(p_planet: Planet, p_player: Boy) -> void:
	planet = p_planet
	player = p_player
	if planet != null and not planet.radius_changed.is_connected(_on_radius_changed):
		planet.radius_changed.connect(_on_radius_changed)


func is_planted() -> bool:
	return _planted


func get_anchor_position() -> Vector3:
	return _anchor


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
	_build_stake(up)
	_build_rope()
	planted.emit()


func notify_snap(force: float) -> void:
	snapped.emit(force)


func _process(_delta: float) -> void:
	_update_rope()


func _on_radius_changed(_new_radius: float) -> void:
	if not _planted or planet == null:
		return
	var up: Vector3 = (_anchor - planet.get_center()).normalized()
	_anchor = planet.get_center() + up * planet.radius
	if _stake != null:
		_stake.global_transform = Transform3D(
			Basis(Quaternion(Vector3.UP, up)), _anchor - up * 0.18
		)


func _build_stake(up: Vector3) -> void:
	if _stake != null:
		_stake.queue_free()
	_stake = Node3D.new()
	_stake.name = "Stake"
	add_child(_stake)
	_stake.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), _anchor - up * 0.18)

	var wood: StandardMaterial3D = _material(WOOD, 0.92)
	var dark: StandardMaterial3D = _material(WOOD_DARK, 0.94)
	var iron: StandardMaterial3D = _material(IRON, 0.55)

	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.075
	post.height = STAKE_HEIGHT
	post.radial_segments = 10
	post.rings = 3
	_add_mesh(_stake, post, wood, Vector3(0.0, STAKE_HEIGHT * 0.5, 0.0))

	var cap := CylinderMesh.new()
	cap.top_radius = 0.085
	cap.bottom_radius = 0.07
	cap.height = 0.11
	cap.radial_segments = 10
	_add_mesh(_stake, cap, iron, Vector3(0.0, STAKE_HEIGHT - 0.03, 0.0))

	var band := CylinderMesh.new()
	band.top_radius = 0.078
	band.bottom_radius = 0.078
	band.height = 0.035
	band.radial_segments = 10
	_add_mesh(_stake, band, dark, Vector3(0.0, STAKE_HEIGHT - 0.16, 0.0))

	var peg := CylinderMesh.new()
	peg.top_radius = 0.035
	peg.bottom_radius = 0.02
	peg.height = 0.09
	peg.radial_segments = 8
	var peg_node := _add_mesh(_stake, peg, iron, Vector3(0.0, STAKE_HEIGHT - 0.24, 0.075))
	peg_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	_stake.scale = Vector3(1.0, 0.25, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_stake, "scale", Vector3.ONE, 0.22)


func _build_rope() -> void:
	for segment: MeshInstance3D in _rope_segments:
		segment.queue_free()
	_rope_segments.clear()
	var rope_material: StandardMaterial3D = _material(ROPE_COLOR, 0.88)
	for _i: int in 2:
		var segment := MeshInstance3D.new()
		segment.name = "Rope"
		var rope_mesh := CylinderMesh.new()
		rope_mesh.top_radius = ROPE_RADIUS
		rope_mesh.bottom_radius = ROPE_RADIUS
		rope_mesh.height = 1.0
		rope_mesh.radial_segments = 6
		rope_mesh.rings = 1
		segment.mesh = rope_mesh
		segment.material_override = rope_material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(segment)
		_rope_segments.append(segment)


func _update_rope() -> void:
	if not _planted or _rope_segments.is_empty() or player == null or planet == null:
		return
	var up: Vector3 = planet.get_center().direction_to(_anchor)
	if up.length_squared() < 0.1:
		up = Vector3.UP
	var from: Vector3 = _anchor + up * (STAKE_HEIGHT - 0.16)
	var to: Vector3 = player.global_position + player.get_up() * HAND_HEIGHT
	var offset: Vector3 = to - from
	var length: float = offset.length()
	if length < 0.05:
		for segment: MeshInstance3D in _rope_segments:
			segment.visible = false
		return
	var slack: float = clampf(get_max_length() - length, 0.0, ROPE_SAG)
	var middle: Vector3 = (from + to) * 0.5 - up * slack
	_place_segment(_rope_segments[0], from, middle)
	_place_segment(_rope_segments[1], middle, to)


func _place_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var offset: Vector3 = to - from
	var length: float = offset.length()
	segment.visible = length > 0.03
	if not segment.visible:
		return
	var direction: Vector3 = offset / length
	var basis := Basis(Quaternion(Vector3.UP, direction))
	basis = basis.scaled(Vector3(1.0, length, 1.0))
	segment.global_transform = Transform3D(basis, (from + to) * 0.5)


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
