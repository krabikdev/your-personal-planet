class_name RopeAnchor
extends Node3D

## The small stake the boy hammers into the ground, plus the taut rope that ties
## him to it. The rope is a plain distance limit: it never changes the boy's
## physics until it is fully stretched, and then it stops him and throws him back
## instead of letting him drift off.

signal planted
signal removed
signal snapped(force: float)

const ROPE_FRACTION: float = 0.95
const STAKE_HEIGHT: float = 0.5
const STAKE_SINK: float = 0.06
const ROPE_RADIUS: float = 0.01
const FOOT_HEIGHT: float = 0.03
const WOOD := Color("7b5c45")
const WOOD_DARK := Color("5c4433")
const ROPE_COLOR := Color("cdb38d")
const IRON := Color("4f4a52")

var planet: Planet
var player: Boy

var _planted: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _stake: Node3D
var _rope: MeshInstance3D


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


func clear() -> void:
	if not _planted:
		return
	_planted = false
	if _stake != null:
		_stake.queue_free()
		_stake = null
	if _rope != null:
		_rope.queue_free()
		_rope = null
	removed.emit()


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
			Basis(Quaternion(Vector3.UP, up)), _anchor - up * STAKE_SINK
		)


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
	_rope = MeshInstance3D.new()
	_rope.name = "Rope"
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = ROPE_RADIUS
	rope_mesh.bottom_radius = ROPE_RADIUS
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 6
	rope_mesh.rings = 1
	_rope.mesh = rope_mesh
	_rope.material_override = _material(ROPE_COLOR, 0.88)
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)


func _update_rope() -> void:
	if not _planted or _rope == null or player == null or planet == null:
		return
	var up: Vector3 = planet.get_center().direction_to(_anchor)
	if up.length_squared() < 0.1:
		up = Vector3.UP
	var from: Vector3 = _anchor + up * (STAKE_HEIGHT - STAKE_SINK - 0.04)
	var to: Vector3 = player.global_position + player.get_up() * FOOT_HEIGHT
	var offset: Vector3 = to - from
	var length: float = offset.length()
	_rope.visible = length > 0.03
	if not _rope.visible:
		return
	var direction: Vector3 = offset / length
	var basis := Basis(Quaternion(Vector3.UP, direction))
	basis = basis * Basis.from_scale(Vector3(1.0, length, 1.0))
	_rope.global_transform = Transform3D(basis, (from + to) * 0.5)


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
