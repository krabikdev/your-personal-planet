class_name PumpkinPlant
extends Node3D

## A watered patch of ground. A stalk creeps out of the dust and swells for
## five minutes of ordinary time; every unit of water poured on it skips two
## minutes of that wait. Once the stalk has grown a little pumpkin head the
## plant guards the ground around it and spits acid at nearby monsters.

signal matured

const GROWTH_SECONDS: float = 300.0
const SECONDS_PER_WATER: float = 120.0
const HEAD_START: float = 0.72
const STALK_MIN_HEIGHT: float = 0.1
const STALK_MAX_HEIGHT: float = 1.0
const ATTACK_RADIUS: float = 10.0
const ATTACK_INTERVAL: float = 2.0
const HEAD_RADIUS: float = 0.21
const PUMPKIN_COLOR := Color("dd8a3c")
const PUMPKIN_DARK := Color("b96b2c")
const STEM_COLOR := Color("6b7a3c")
const LEAF_COLOR := Color("5f8a4e")
const EYE_COLOR := Color("2a1d24")

var planet: Planet
var ground_dir: Vector3 = Vector3.UP

var _growth: float = 0.0
var _mature: bool = false
var _attack_cooldown: float = ATTACK_INTERVAL
var _time: float = 0.0
var _stalk: MeshInstance3D
var _stalk_mesh: CylinderMesh
var _leaves: Array[MeshInstance3D] = []
var _head: Node3D


func setup(p_planet: Planet, p_dir: Vector3) -> void:
	planet = p_planet
	ground_dir = p_dir.normalized()
	_build()
	_place()
	_update_visual()


func is_mature() -> bool:
	return _mature


func get_progress() -> float:
	return clampf(_growth / GROWTH_SECONDS, 0.0, 1.0)


func get_growth_seconds() -> float:
	return _growth


func get_head_position() -> Vector3:
	if _head != null and _head.visible:
		return _head.global_position
	return global_position


## Each unit of water is a two-minute shortcut on the stalk's growth.
func water(amount: float) -> void:
	if amount <= 0.0 or _mature:
		return
	_growth = minf(_growth + amount * SECONDS_PER_WATER, GROWTH_SECONDS)
	_update_visual()
	if _growth >= GROWTH_SECONDS:
		_mature = true
		matured.emit()


func _process(delta: float) -> void:
	_time += delta
	if not _mature:
		_growth = minf(_growth + delta, GROWTH_SECONDS)
		_update_visual()
		if _growth >= GROWTH_SECONDS:
			_mature = true
			matured.emit()
		return
	_maybe_attack(delta)
	if _head != null and _head.visible:
		_head.rotation.y = sin(_time * 0.9) * 0.06


func _place() -> void:
	if planet == null:
		return
	var up: Vector3 = ground_dir
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(up)) > 0.9:
		reference = Vector3.RIGHT
	var forward: Vector3 = (reference - up * reference.dot(up)).normalized()
	var right: Vector3 = forward.cross(up).normalized()
	global_transform = Transform3D(
		Basis(right, up, -forward), planet.get_center() + up * planet.radius
	)


func _build() -> void:
	_stalk_mesh = CylinderMesh.new()
	_stalk_mesh.top_radius = 0.012
	_stalk_mesh.bottom_radius = 0.028
	_stalk_mesh.height = STALK_MIN_HEIGHT
	_stalk_mesh.radial_segments = 8
	_stalk_mesh.rings = 2
	_stalk = MeshInstance3D.new()
	_stalk.name = "Stalk"
	_stalk.mesh = _stalk_mesh
	_stalk.material_override = _material(LEAF_COLOR.darkened(0.15), 0.9, 0.0)
	add_child(_stalk)

	for side: int in 2:
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf%d" % side
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.1
		mesh.radial_segments = 10
		mesh.rings = 5
		leaf.mesh = mesh
		leaf.material_override = _material(LEAF_COLOR, 0.85, 0.0)
		leaf.rotation_degrees = Vector3(0.0, 0.0, -55.0 if side == 0 else 55.0)
		add_child(leaf)
		_leaves.append(leaf)

	_head = _build_head()
	add_child(_head)


func _build_head() -> Node3D:
	var head := Node3D.new()
	head.name = "Head"
	var pumpkin := _material(PUMPKIN_COLOR, 0.62, 0.0)
	var dark := _material(PUMPKIN_DARK, 0.75, 0.0)
	var eye := _material(EYE_COLOR, 0.5, 0.0)

	var core := SphereMesh.new()
	core.radius = HEAD_RADIUS
	core.height = HEAD_RADIUS * 1.7
	core.radial_segments = 18
	core.rings = 10
	_add_mesh(head, core, pumpkin, Vector3.ZERO)

	# Six squashed lobes around the middle read as a ribbed pumpkin.
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		var lobe := SphereMesh.new()
		lobe.radius = HEAD_RADIUS * 0.42
		lobe.height = HEAD_RADIUS * 1.5
		lobe.radial_segments = 10
		lobe.rings = 6
		var node := _add_mesh(
			head,
			lobe,
			dark if i % 2 == 0 else pumpkin,
			Vector3(cos(angle), 0.0, sin(angle)) * HEAD_RADIUS * 0.66
		)
		node.scale = Vector3(0.9, 1.0, 0.9)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.018
	stem.bottom_radius = HEAD_RADIUS * 0.22
	stem.height = HEAD_RADIUS * 0.7
	stem.radial_segments = 6
	stem.rings = 1
	var stem_node := _add_mesh(
		head, stem, _material(STEM_COLOR, 0.9, 0.0), Vector3(0.0, HEAD_RADIUS * 0.95, 0.0)
	)
	stem_node.rotation_degrees = Vector3(0.0, 0.0, 8.0)

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = HEAD_RADIUS * 0.12
	eye_mesh.height = HEAD_RADIUS * 0.24
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	for side: float in [-1.0, 1.0]:
		var socket := _add_mesh(
			head,
			eye_mesh,
			eye,
			Vector3(HEAD_RADIUS * 0.34 * side, HEAD_RADIUS * 0.16, -HEAD_RADIUS * 0.86)
		)
		socket.scale = Vector3(1.0, 1.35, 0.7)

	var tooth := BoxMesh.new()
	tooth.size = Vector3(HEAD_RADIUS * 0.16, HEAD_RADIUS * 0.16, HEAD_RADIUS * 0.08)
	for i: int in 4:
		var x: float = lerpf(-HEAD_RADIUS * 0.34, HEAD_RADIUS * 0.34, float(i) / 3.0)
		var node := _add_mesh(
			head,
			tooth,
			eye,
			Vector3(x, -HEAD_RADIUS * 0.22 + (0.05 if i % 2 == 0 else 0.0), -HEAD_RADIUS * 0.9)
		)
		node.rotation_degrees = Vector3(0.0, 0.0, -18.0 if i % 2 == 0 else 18.0)

	head.visible = false
	return head


func _update_visual() -> void:
	var progress: float = get_progress()
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var height: float = lerpf(STALK_MIN_HEIGHT, STALK_MAX_HEIGHT, eased)
	_stalk_mesh.height = height
	_stalk_mesh.bottom_radius = lerpf(0.02, 0.034, eased)
	_stalk_mesh.top_radius = lerpf(0.008, 0.016, eased)
	_stalk.position.y = height * 0.5

	for side: int in _leaves.size():
		var leaf: MeshInstance3D = _leaves[side]
		var amount: float = clampf((progress - 0.15) / 0.5, 0.0, 1.0)
		leaf.visible = amount > 0.01
		leaf.scale = Vector3.ONE * (0.35 + 0.65 * amount)
		leaf.position = Vector3(
			(0.07 + 0.05 * amount) * (-1.0 if side == 0 else 1.0),
			height * (0.62 + 0.08 * float(side)),
			0.02
		)

	var head_amount: float = clampf((progress - HEAD_START) / (1.0 - HEAD_START), 0.0, 1.0)
	_head.visible = head_amount > 0.01
	_head.scale = Vector3.ONE * maxf(head_amount, 0.01)
	_head.position = Vector3(0.0, height + HEAD_RADIUS * 0.86, 0.0)


func _maybe_attack(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL
	_try_attack()


## Finds the nearest monster the head can see and spits a blob at it.
func _try_attack() -> AcidBlob:
	if planet == null or _head == null:
		return null
	var origin: Vector3 = get_head_position()
	var nearest: Node3D = null
	var best: float = ATTACK_RADIUS
	for node: Node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Node3D
		if monster == null or not is_instance_valid(monster):
			continue
		var distance: float = origin.distance_to(monster.global_position)
		if distance <= best:
			best = distance
			nearest = monster
	if nearest == null:
		return null
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var blob := AcidBlob.new()
	blob.name = "AcidBlob"
	parent.add_child(blob)
	blob.setup(origin, nearest)
	return blob


func debug_attack_now() -> AcidBlob:
	_attack_cooldown = 0.0
	return _try_attack()


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
