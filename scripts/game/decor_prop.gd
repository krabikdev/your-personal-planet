class_name DecorProp
extends Node3D

## One thing that shows up on the far side of the planet: a tuft of grass, a
## bush, a young tree, a full tree, a big tree, or a wandering monster. Every
## prop is built from primitives, so the game needs no new assets. A prop never
## changes its own size: when the planet grows it only rides the surface.

signal acid_hit

enum Kind { GRASS, BUSH, SAPLING, TREE, BIG_TREE, MONSTER }
enum State { WANDER, REST, CHASE }

const WANDER_TIME: float = 5.0
const REST_MIN: float = 5.0
const REST_MAX: float = 10.0
const WANDER_SPEED: float = 0.85
const CHASE_SPEED: float = 1.9
const CHASE_SPEED_PER_LEVEL: float = 0.1
const CONTACT_RADIUS: float = 0.85
## How sharply a wandering monster bends its path, in radians per second.
const WANDER_CURVE: float = 0.9
const REST_TURN_EVERY_MIN: float = 1.1
const REST_TURN_EVERY_MAX: float = 2.4
const AGGRO_STEP: float = 5.0
const CONTACT_DAMAGE_STEP: float = 1.0

var kind: int = Kind.GRASS
var anchor_dir: Vector3 = Vector3.UP
var monster_level: int = 1

var planet: Planet
var boy: Boy

var _seed: int = 0
var _rng: RandomNumberGenerator
var _time: float = 0.0
var _visual: Node3D
var _body: Node3D
var _state: int = State.WANDER
var _timer: float = WANDER_TIME
var _heading: Vector3 = Vector3.FORWARD
var _idle_timer: float = 1.0
var _idle_yaw: float = 0.0
var _spin: float = 0.0
var _base_scale: float = 1.0


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
		_base_scale = 0.78 + 0.16 * float(monster_level)
	# A soft pop-in makes a new arrival readable without moving the prop itself.
	_visual.scale = Vector3.ONE * 0.12
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(_visual, "scale", Vector3.ONE * _base_scale, 0.55)


func is_monster() -> bool:
	return kind == Kind.MONSTER


## Where the monster is in its day: wandering, resting, or running at the boy.
func get_state() -> int:
	return _state


func get_aggro_radius() -> float:
	return aggro_radius_for_level(monster_level)


func get_contact_damage() -> float:
	return contact_damage_for_level(monster_level)


## Monsters get meaner in steps: 5/10/15/20 metres and 1/2/3/4 health a second.
static func aggro_radius_for_level(level: int) -> float:
	return AGGRO_STEP * float(clampi(level, 1, 4))


static func contact_damage_for_level(level: int) -> float:
	return CONTACT_DAMAGE_STEP * float(clampi(level, 1, 4))


## Hands the monster the world it lives in. The spawner calls this after the
## prop has been settled on the surface.
func configure_monster(p_planet: Planet, p_boy: Boy, p_level: int) -> void:
	planet = p_planet
	boy = p_boy
	monster_level = clampi(p_level, 1, 4)
	_rng.seed = _seed + 31 * monster_level
	_enter_wander()


## One blob of acid is enough: the monster dissolves and leaves the garden.
func hit_by_acid() -> void:
	acid_hit.emit()
	queue_free()


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	if planet == null or boy == null or not is_instance_valid(boy):
		_idle_bob()
		return
	_advance(delta)


## Advances the monster's whole brain by `seconds` in small steps. Tests use it
## instead of waiting out five-second wander and ten-second rest phases.
func debug_step(seconds: float) -> void:
	var steps: int = maxi(1, ceili(seconds / 0.05))
	var step: float = seconds / float(steps)
	for _i: int in steps:
		_advance(step)


## Puts the monster `distance` metres from the boy along the surface. Negative
## is not allowed; zero means it is standing on top of him.
func debug_place_near(boy_position: Vector3, distance: float) -> void:
	if planet == null:
		return
	var up: Vector3 = (boy_position - planet.get_center()).normalized()
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(up)) > 0.9:
		reference = Vector3.RIGHT
	var tangent: Vector3 = (reference - up * reference.dot(up)).normalized()
	var angle: float = maxf(distance, 0.0) / maxf(planet.radius, 0.001)
	anchor_dir = (up * cos(angle) + tangent * sin(angle)).normalized()
	_heading = tangent
	_update_transform(tangent)


func _advance(delta: float) -> void:
	var up: Vector3 = anchor_dir
	var mine: Vector3 = _world_position()
	var to_boy: Vector3 = boy.global_position - mine
	var distance: float = to_boy.length()
	var chasing: bool = distance <= get_aggro_radius()
	if chasing:
		if _state != State.CHASE:
			_state = State.CHASE
			_spin = 0.0
		_body.rotation.y = 0.0
		if distance > CONTACT_RADIUS:
			var toward: Vector3 = to_boy - up * to_boy.dot(up)
			if toward.length_squared() > 0.0001:
				var speed: float = CHASE_SPEED + CHASE_SPEED_PER_LEVEL * float(monster_level)
				_step(toward.normalized(), speed, delta)
		else:
			boy.take_damage(get_contact_damage() * delta)
		_idle_bob()
		return
	if _state == State.CHASE:
		_enter_wander()
	_timer -= delta
	if _timer <= 0.0:
		if _state == State.WANDER:
			_enter_rest()
		else:
			_enter_wander()
	if _state == State.WANDER:
		var bend: float = _rng.randf_range(-1.0, 1.0) * WANDER_CURVE * delta
		_heading = _heading.rotated(up, bend).normalized()
		_step(_heading, WANDER_SPEED, delta)
		_spin = lerpf(_spin, 0.0, 1.0 - exp(-5.0 * delta))
		_body.rotation.y = _spin
	else:
		# Resting: it stands still but keeps glancing around.
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_idle_timer = _rng.randf_range(REST_TURN_EVERY_MIN, REST_TURN_EVERY_MAX)
			_idle_yaw = _rng.randf_range(-0.9, 0.9)
		_spin = lerpf(_spin, _idle_yaw, 1.0 - exp(-3.5 * delta))
		_body.rotation.y = _spin
	_idle_bob()


func _idle_bob() -> void:
	if _body == null:
		return
	_body.position.y = absf(sin(_time * 4.4 + float(_seed % 11))) * 0.05


func _enter_wander() -> void:
	_state = State.WANDER
	_timer = WANDER_TIME * _rng.randf_range(0.85, 1.15)
	_heading = _random_tangent()


func _enter_rest() -> void:
	_state = State.REST
	_timer = _rng.randf_range(REST_MIN, REST_MAX)
	_idle_timer = _rng.randf_range(0.6, REST_TURN_EVERY_MAX)


func _random_tangent() -> Vector3:
	var up: Vector3 = anchor_dir
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(up)) > 0.9:
		reference = Vector3.RIGHT
	var first: Vector3 = (reference - up * reference.dot(up)).normalized()
	var second: Vector3 = up.cross(first).normalized()
	var bearing: float = _rng.randf() * TAU
	return (first * cos(bearing) + second * sin(bearing)).normalized()


func _world_position() -> Vector3:
	var center: Vector3 = planet.get_center()
	return center + anchor_dir * planet.radius


func _step(direction: Vector3, speed: float, delta: float) -> void:
	var up: Vector3 = anchor_dir
	var angle: float = speed * delta / maxf(planet.radius, 0.001)
	anchor_dir = (up * cos(angle) + direction * sin(angle)).normalized()
	_heading = direction - anchor_dir * direction.dot(anchor_dir)
	if _heading.length_squared() < 0.0001:
		_heading = _random_tangent()
	_heading = _heading.normalized()
	_update_transform(direction)


func _update_transform(forward: Vector3) -> void:
	if planet == null:
		return
	var up: Vector3 = anchor_dir
	var tangent: Vector3 = forward - up * forward.dot(up)
	if tangent.length_squared() < 0.0001:
		tangent = _random_tangent()
	tangent = tangent.normalized()
	var right: Vector3 = tangent.cross(up).normalized()
	global_transform = Transform3D(Basis(right, up, -tangent), _world_position())


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
	var skin: Color = palette[monster_level - 1]
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
