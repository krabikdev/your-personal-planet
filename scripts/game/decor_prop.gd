class_name DecorProp
extends Node3D

## One thing that shows up on the far side of the planet: a tuft of grass, a
## bush, a young tree, a full tree, a big tree, or a wandering monster. Every
## prop is built from primitives, so the game needs no new assets. A prop never
## changes its own size: when the planet grows it only rides the surface.

signal acid_hit

enum Kind { GRASS, BUSH, SAPLING, TREE, BIG_TREE, MONSTER }

const MONSTER_WANDER_RADIUS: float = 0.38
const MONSTER_WANDER_SPEED: float = 0.9

var kind: int = Kind.GRASS
var anchor_dir: Vector3 = Vector3.UP
var monster_level: int = 1

var _seed: int = 0
var _rng: RandomNumberGenerator
var _time: float = 0.0
var _visual: Node3D
var _body: Node3D


func setup(p_kind: int, p_seed: int, p_level: int = 1) -> void:
	kind = p_kind
	_seed = p_seed
	monster_level = clampi(p_level, 1, 4)
	_rng = RandomNumberGenerator.new()
	_rng.seed = _seed
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	match kind:
		Kind.GRASS:
			_build_grass()
		Kind.BUSH:
			_build_bush()
		Kind.SAPLING:
			_build_sapling()
		Kind.TREE:
			_build_tree()
		Kind.BIG_TREE:
			_build_big_tree()
		_:
			_build_monster()
	set_process(kind == Kind.MONSTER)
	if kind == Kind.MONSTER:
		add_to_group("monsters")
	# A soft pop-in makes a new arrival readable without moving the prop itself.
	_visual.scale = Vector3.ONE * 0.12
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(_visual, "scale", Vector3.ONE, 0.55)


func is_monster() -> bool:
	return kind == Kind.MONSTER


## One blob of acid is enough: the monster dissolves and leaves the garden.
func hit_by_acid() -> void:
	acid_hit.emit()
	queue_free()


func _process(delta: float) -> void:
	if _body == null:
		return
	# Monsters pace in a small circle around their spawn point, so they look
	# alive without ever leaving the far side or touching the boy.
	_time += delta
	var angle: float = _time * MONSTER_WANDER_SPEED
	var step: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
	_body.position = Vector3(cos(angle), 0.0, sin(angle)) * MONSTER_WANDER_RADIUS
	_body.position.y = absf(sin(_time * 4.4 + float(_seed % 11))) * 0.05
	if step.length_squared() > 0.001:
		_body.rotation.y = atan2(-step.x, -step.z)


func _build_grass() -> void:
	var blades: int = _rng.randi_range(5, 8)
	for i: int in blades:
		var height: float = _rng.randf_range(0.16, 0.34)
		var blade := CylinderMesh.new()
		blade.top_radius = 0.0015
		blade.bottom_radius = _rng.randf_range(0.005, 0.013)
		blade.height = height
		blade.radial_segments = 4
		blade.rings = 1
		var green := Color("6f9a5a").lerp(Color("a8c47a"), _rng.randf())
		var node: MeshInstance3D = _add_mesh(
			blade, _material(green, 0.9), Vector3.ZERO, Vector3.ZERO, false
		)
		var spread: float = _rng.randf_range(0.0, 0.07)
		var around: float = _rng.randf_range(0.0, TAU)
		node.position = Vector3(cos(around), 0.0, sin(around)) * spread
		node.position.y = height * 0.5
		node.rotation_degrees = Vector3(
			_rng.randf_range(-16.0, 16.0),
			_rng.randf_range(0.0, 360.0),
			_rng.randf_range(-16.0, 16.0)
		)


func _build_bush() -> void:
	var clusters: int = _rng.randi_range(3, 4)
	for i: int in clusters:
		var blob := SphereMesh.new()
		blob.radius = _rng.randf_range(0.16, 0.24)
		blob.height = blob.radius * 1.7
		blob.radial_segments = 12
		blob.rings = 6
		var green := Color("4f7a4c").lerp(Color("7fa25f"), _rng.randf())
		var node: MeshInstance3D = _add_mesh(blob, _material(green, 0.88), Vector3.ZERO)
		var around: float = TAU * float(i) / float(clusters) + _rng.randf_range(-0.4, 0.4)
		node.position = Vector3(cos(around), 0.0, sin(around)) * _rng.randf_range(0.02, 0.14)
		node.position.y = blob.radius * 0.85 + _rng.randf_range(0.0, 0.12)
	# A couple of tiny berries so the bush is not a green blob.
	for i: int in 3:
		var berry := SphereMesh.new()
		berry.radius = 0.024
		berry.height = 0.048
		berry.radial_segments = 6
		berry.rings = 3
		var node: MeshInstance3D = _add_mesh(berry, _material(Color("b0555a"), 0.6), Vector3.ZERO)
		var around: float = _rng.randf_range(0.0, TAU)
		node.position = Vector3(cos(around), 0.0, sin(around)) * 0.16
		node.position.y = _rng.randf_range(0.18, 0.34)


func _build_sapling() -> void:
	_trunk(0.55, 0.026, 0.019)
	for i: int in 3:
		_leaf_cluster(
			_rng.randf_range(0.45, 0.68), _rng.randf_range(0.12, 0.18), Color("6d975b"), 10
		)


func _build_tree() -> void:
	_trunk(1.05, 0.075, 0.045)
	for i: int in 4:
		_leaf_cluster(
			_rng.randf_range(0.78, 1.22), _rng.randf_range(0.26, 0.38), Color("547f4a"), 12
		)
	# A couple of branches leaves no doubt it is a tree.
	var branch := CylinderMesh.new()
	branch.top_radius = 0.018
	branch.bottom_radius = 0.032
	branch.height = 0.52
	branch.radial_segments = 6
	branch.rings = 1
	var branch_node: MeshInstance3D = _add_mesh(
		branch, _material(Color("6a5140"), 0.95), Vector3.ZERO
	)
	branch_node.position = Vector3(0.16, 0.78, 0.0)
	branch_node.rotation_degrees = Vector3(0.0, 0.0, -34.0)


func _build_big_tree() -> void:
	_trunk(1.9, 0.15, 0.09)
	for i: int in 6:
		_leaf_cluster(_rng.randf_range(1.4, 2.2), _rng.randf_range(0.5, 0.72), Color("416b42"), 14)
	var bough := CylinderMesh.new()
	bough.top_radius = 0.03
	bough.bottom_radius = 0.065
	bough.height = 0.9
	bough.radial_segments = 6
	bough.rings = 1
	for side: float in [-1.0, 1.0]:
		var node: MeshInstance3D = _add_mesh(bough, _material(Color("5d4636"), 0.95), Vector3.ZERO)
		node.position = Vector3(0.26 * side, 1.42, 0.0)
		node.rotation_degrees = Vector3(0.0, 0.0, -38.0 * side)


func _build_monster() -> void:
	var palette: Array[Color] = [Color("8a6fb5"), Color("6f92a8"), Color("b07a68"), Color("8ba86f")]
	var skin: Color = palette[_seed % palette.size()]
	var body := SphereMesh.new()
	body.radius = 0.26
	body.height = 0.44
	body.radial_segments = 16
	body.rings = 8
	var body_node: MeshInstance3D = _add_mesh(body, _material(skin, 0.62, 0.05), Vector3.ZERO)
	body_node.position = Vector3(0.0, 0.32, 0.0)
	body_node.scale = Vector3(1.0, 0.92, 0.86)

	var belly := SphereMesh.new()
	belly.radius = 0.16
	belly.height = 0.26
	belly.radial_segments = 12
	belly.rings = 6
	var belly_node: MeshInstance3D = _add_mesh(
		belly, _material(skin.lightened(0.28), 0.7), Vector3.ZERO
	)
	belly_node.position = Vector3(0.0, 0.26, -0.14)
	belly_node.scale = Vector3(0.95, 0.9, 0.5)

	var eye_white: StandardMaterial3D = _material(Color("f2ece0"), 0.55)
	var pupil: StandardMaterial3D = _material(Color("241f2b"), 0.4)
	for side: float in [-1.0, 1.0]:
		var white := SphereMesh.new()
		white.radius = 0.062
		white.height = 0.124
		white.radial_segments = 10
		white.rings = 5
		var white_node: MeshInstance3D = _add_mesh(white, eye_white, Vector3.ZERO)
		white_node.position = Vector3(0.085 * side, 0.38, -0.2)
		var dark := SphereMesh.new()
		dark.radius = 0.03
		dark.height = 0.06
		dark.radial_segments = 8
		dark.rings = 4
		var dark_node: MeshInstance3D = _add_mesh(dark, pupil, Vector3.ZERO)
		dark_node.position = Vector3(0.085 * side, 0.38, -0.25)

	# Antennae, arms and legs: just enough to read as a creature at a glance.
	var horn := CylinderMesh.new()
	horn.top_radius = 0.006
	horn.bottom_radius = 0.016
	horn.height = 0.17
	horn.radial_segments = 5
	horn.rings = 1
	for side: float in [-1.0, 1.0]:
		var horn_node: MeshInstance3D = _add_mesh(
			horn, _material(skin.darkened(0.2), 0.7), Vector3.ZERO
		)
		horn_node.position = Vector3(0.11 * side, 0.55, 0.02)
		horn_node.rotation_degrees = Vector3(0.0, 0.0, -22.0 * side)

	var limb := CylinderMesh.new()
	limb.top_radius = 0.03
	limb.bottom_radius = 0.042
	limb.height = 0.19
	limb.radial_segments = 6
	limb.rings = 1
	for side: float in [-1.0, 1.0]:
		var leg: MeshInstance3D = _add_mesh(limb, _material(skin.darkened(0.12), 0.8), Vector3.ZERO)
		leg.position = Vector3(0.1 * side, 0.09, 0.0)
		var arm: MeshInstance3D = _add_mesh(limb, _material(skin.darkened(0.06), 0.8), Vector3.ZERO)
		arm.position = Vector3(0.24 * side, 0.3, 0.0)
		arm.rotation_degrees = Vector3(0.0, 0.0, -18.0 * side)
		arm.scale = Vector3(0.8, 0.7, 0.8)


func _trunk(height: float, top_radius: float, bottom_radius: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = top_radius
	trunk.bottom_radius = bottom_radius
	trunk.height = height
	trunk.radial_segments = 8
	trunk.rings = 1
	var node: MeshInstance3D = _add_mesh(trunk, _material(Color("6b5140"), 0.95), Vector3.ZERO)
	node.position = Vector3(0.0, height * 0.5, 0.0)


func _leaf_cluster(height: float, radius: float, color: Color, segments: int) -> void:
	var blob := SphereMesh.new()
	blob.radius = radius
	blob.height = radius * 1.75
	blob.radial_segments = segments
	blob.rings = segments / 2
	var tint: Color = color.lerp(Color("7fa25f"), _rng.randf() * 0.45)
	var node: MeshInstance3D = _add_mesh(blob, _material(tint, 0.9), Vector3.ZERO)
	var around: float = _rng.randf_range(0.0, TAU)
	var spread: float = _rng.randf_range(0.0, radius * 0.9)
	node.position = Vector3(cos(around), 0.0, sin(around)) * spread
	node.position.y = height + _rng.randf_range(-0.08, 0.08)


func _add_mesh(
	mesh: Mesh,
	material: Material,
	local: Vector3,
	rotation_deg: Vector3 = Vector3.ZERO,
	shadow: bool = true
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = local
	node.rotation_degrees = rotation_deg
	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_body.add_child(node)
	return node


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
