class_name SkeletonProp
extends Node3D

## The old traveller's remains near the boy's landing spot. A rusty watering
## can lies by the skeleton's hands; walking up to it tucks it into the bag.
## As the planet grows, the ground creeps up over the bones and slowly swallows
## them where they lie.

signal item_picked(kind: int)

const SPAWN_ANGLE: float = 0.45
const PICKUP_RADIUS: float = 1.05
## How much of the new ground the skeleton keeps under itself. Just under 1
## means it stays in place on the surface but loses a little height each time,
## so it sinks into the dust slowly instead of vanishing with the first stone.
const RISE_WITH_GROUND: float = 0.92
const BURY_DEPTH: float = 0.1
const BONE_COLOR := Color("e2dcc8")
const JOINT_COLOR := Color("c6bea6")
const CAN_COLOR := Color("7f9a90")
const RUST_COLOR := Color("8a5a3b")

var planet: Planet
var player: Boy

var _origin_distance: float = 5.0
var _ground_dir: Vector3 = Vector3.UP
var _can: Node3D
var _can_picked: bool = false
var _buried: bool = false


func setup(p_planet: Planet, p_player: Boy) -> void:
	planet = p_planet
	player = p_player
	_origin_distance = planet.radius

	var right: Vector3 = player.global_transform.basis.x
	var ahead: Vector3 = -player.global_transform.basis.z
	var tangent: Vector3 = (ahead * 0.55 + right * 0.84).normalized()
	_ground_dir = ((player.get_up() * cos(SPAWN_ANGLE) + tangent * sin(SPAWN_ANGLE)).normalized())
	global_position = planet.get_center() + _ground_dir * planet.radius

	var body_axis: Vector3 = tangent - _ground_dir * tangent.dot(_ground_dir)
	if body_axis.length_squared() < 0.01:
		body_axis = _ground_dir.cross(Vector3.RIGHT)
	body_axis = body_axis.normalized()
	var side_axis: Vector3 = body_axis.cross(_ground_dir).normalized()
	global_transform = Transform3D(Basis(body_axis, _ground_dir, side_axis), global_position)

	_build()
	if not planet.radius_changed.is_connected(_on_radius_changed):
		planet.radius_changed.connect(_on_radius_changed)


func is_buried() -> bool:
	return _buried


func has_can() -> bool:
	return not _can_picked


func get_can_position() -> Vector3:
	return _can.global_position if _can != null else global_position


func _process(_delta: float) -> void:
	if _buried or player == null:
		return
	if (
		not _can_picked
		and _can != null
		and player.global_position.distance_to(_can.global_position) < PICKUP_RADIUS
	):
		_can_picked = true
		_can.visible = false
		AudioDirector.play_sfx("ui_click", 0.05, -5.0)
		item_picked.emit(StoneItem.Kind.WATERING_CAN)


func _on_radius_changed(new_radius: float) -> void:
	if _buried or planet == null:
		return
	var growth: float = new_radius - _origin_distance
	if growth <= 0.0:
		return
	# The skeleton rides the rising ground almost completely, so it keeps its
	# spot in the landscape and only loses a few centimetres of clearance per
	# growth. That makes the burial a slow, visible slide into the dust.
	var distance: float = _origin_distance + growth * RISE_WITH_GROUND
	global_position = planet.get_center() + _ground_dir * distance
	if new_radius - distance >= BURY_DEPTH:
		_buried = true
		visible = false
		set_process(false)


func _build() -> void:
	var bone: StandardMaterial3D = _material(BONE_COLOR, 0.88, 0.0)
	var joint: StandardMaterial3D = _material(JOINT_COLOR, 0.92, 0.0)
	var can_metal: StandardMaterial3D = _material(CAN_COLOR, 0.38, 0.65)
	var rust: StandardMaterial3D = _material(RUST_COLOR, 0.92, 0.1)

	_build_skull(bone, joint)
	_build_spine(bone, joint)
	_build_arms(bone, joint)
	_build_legs(bone, joint)
	_build_pelvis(joint)

	_can = Node3D.new()
	_can.name = "WateringCan"
	_can.position = Vector3(-0.04, 0.0, 0.78)
	_can.rotation_degrees = Vector3(0.0, 18.0, 9.0)
	add_child(_can)
	_build_can(_can, can_metal, rust)


func _build_skull(bone: StandardMaterial3D, joint: StandardMaterial3D) -> void:
	var skull := SphereMesh.new()
	skull.radius = 0.13
	skull.height = 0.26
	skull.radial_segments = 16
	skull.rings = 8
	_add_mesh(self, skull, bone, Vector3(-0.86, 0.105, 0.0), Vector3(1.15, 0.85, 0.95))

	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.13, 0.05, 0.16)
	_add_mesh(self, jaw, joint, Vector3(-0.98, 0.032, 0.0), Vector3(1.0, 1.0, 1.0))

	var socket := SphereMesh.new()
	socket.radius = 0.028
	socket.height = 0.056
	socket.radial_segments = 8
	socket.rings = 4
	var dark: StandardMaterial3D = _material(Color("2c2724"), 0.9, 0.0)
	_add_mesh(self, socket, dark, Vector3(-0.9, 0.19, 0.048), Vector3.ONE)
	_add_mesh(self, socket, dark, Vector3(-0.9, 0.19, -0.048), Vector3.ONE)
	_add_mesh(self, socket, dark, Vector3(-0.97, 0.145, 0.0), Vector3(0.55, 0.7, 0.55))

	# A cracked collarbone for a little storytelling.
	_bone(Vector3(-0.76, 0.022, -0.14), Vector3(-0.66, 0.026, 0.12), 0.012, bone)


func _build_spine(bone: StandardMaterial3D, joint: StandardMaterial3D) -> void:
	# Every bone is laid on the ground line: the spine rests at its own radius,
	# so nothing floats above the dust.
	_bone(Vector3(-0.75, 0.03, 0.0), Vector3(-0.04, 0.03, 0.0), 0.026, bone)
	for i: int in 4:
		var x: float = -0.58 + float(i) * 0.125
		var ribs := TorusMesh.new()
		ribs.inner_radius = 0.105 - float(i) * 0.006
		ribs.outer_radius = 0.148 - float(i) * 0.006
		ribs.rings = 14
		ribs.ring_segments = 6
		var node := MeshInstance3D.new()
		node.mesh = ribs
		node.material_override = bone
		node.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(x, 0.052, 0.0))
		# Squashed along the mesh X axis, which becomes "up" after the rotation.
		node.scale = Vector3(0.34, 1.0, 0.85)
		add_child(node)
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = 0.042
	joint_mesh.height = 0.084
	joint_mesh.radial_segments = 8
	joint_mesh.rings = 4
	_add_mesh(self, joint_mesh, joint, Vector3(0.04, 0.045, 0.0), Vector3(1.2, 0.8, 1.0))


func _build_arms(bone: StandardMaterial3D, joint: StandardMaterial3D) -> void:
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(-0.56, 0.032, 0.19 * side)
		var elbow := Vector3(-0.32, 0.03, 0.44 * side)
		var wrist := Vector3(-0.1, 0.028, 0.61 * side)
		_bone(shoulder, elbow, 0.019, bone)
		_bone(elbow, wrist, 0.016, bone)
		_joint(elbow, 0.026, joint)
		_joint(wrist, 0.024, joint)
		var hand := SphereMesh.new()
		hand.radius = 0.055
		hand.height = 0.075
		hand.radial_segments = 8
		hand.rings = 4
		_add_mesh(
			self, hand, bone, wrist + Vector3(-0.04, 0.0, 0.05 * side), Vector3(1.0, 0.55, 1.25)
		)


func _build_legs(bone: StandardMaterial3D, joint: StandardMaterial3D) -> void:
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(0.1, 0.032, 0.13 * side)
		var knee := Vector3(0.47, 0.03, 0.14 * side)
		var ankle := Vector3(0.82, 0.028, 0.14 * side)
		_bone(hip, knee, 0.024, bone)
		_bone(knee, ankle, 0.02, bone)
		_joint(knee, 0.034, joint)
		_joint(ankle, 0.028, joint)
		var foot := BoxMesh.new()
		foot.size = Vector3(0.17, 0.055, 0.09)
		_add_mesh(self, foot, bone, ankle + Vector3(0.07, 0.0, 0.0), Vector3.ONE)


func _build_pelvis(joint: StandardMaterial3D) -> void:
	var pelvis := SphereMesh.new()
	pelvis.radius = 0.11
	pelvis.height = 0.17
	pelvis.radial_segments = 12
	pelvis.rings = 6
	_add_mesh(self, pelvis, joint, Vector3(0.05, 0.055, 0.0), Vector3(1.25, 0.62, 1.0))


func _build_can(parent: Node3D, metal: StandardMaterial3D, rust: StandardMaterial3D) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.1
	body.bottom_radius = 0.115
	body.height = 0.27
	body.radial_segments = 14
	body.rings = 2
	_add_mesh(parent, body, metal, Vector3(0.0, 0.135, 0.0), Vector3.ONE)

	var rim := CylinderMesh.new()
	rim.top_radius = 0.105
	rim.bottom_radius = 0.105
	rim.height = 0.025
	rim.radial_segments = 14
	rim.rings = 1
	_add_mesh(parent, rim, rust, Vector3(0.0, 0.275, 0.0), Vector3.ONE)

	var spout := CylinderMesh.new()
	spout.top_radius = 0.022
	spout.bottom_radius = 0.04
	spout.height = 0.3
	spout.radial_segments = 8
	spout.rings = 1
	var spout_node := _add_mesh(parent, spout, rust, Vector3(0.2, 0.22, 0.0), Vector3.ONE)
	spout_node.rotation_degrees = Vector3(0.0, 0.0, -38.0)

	var rose := CylinderMesh.new()
	rose.top_radius = 0.055
	rose.bottom_radius = 0.025
	rose.height = 0.045
	rose.radial_segments = 8
	rose.rings = 1
	var rose_node := _add_mesh(parent, rose, rust, Vector3(0.31, 0.335, 0.0), Vector3.ONE)
	rose_node.rotation_degrees = Vector3(0.0, 0.0, -38.0)

	var handle := TorusMesh.new()
	handle.inner_radius = 0.07
	handle.outer_radius = 0.095
	handle.rings = 12
	handle.ring_segments = 6
	var handle_node := _add_mesh(parent, handle, metal, Vector3(-0.09, 0.25, 0.0), Vector3.ONE)
	handle_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _bone(from: Vector3, to: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var offset: Vector3 = to - from
	var length: float = offset.length()
	if length < 0.001:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, offset.normalized())), (from + to) * 0.5
	)
	add_child(node)


func _joint(at: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 8
	mesh.rings = 4
	_add_mesh(self, mesh, material, at, Vector3.ONE)


func _add_mesh(
	parent: Node3D, mesh: Mesh, material: Material, position: Vector3, scale: Vector3
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.scale = scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
