class_name DecorProp  # gdlint:ignore=max-public-methods
extends Node3D

## One thing that shows up on the far side of the planet: a tuft of dry grass, a
## tumbleweed, a bare young tree, a larger one, a huge oak whose branch tips are
## flat platforms, or a wandering monster. Every prop is built from primitives
## and merged into a few meshes, so detail costs geometry rather than draw calls.
## A prop never changes its own size: when the planet grows it only rides the
## surface, and a cluster keeps its real spacing.

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

## Dry planet shades, pale straw down to a gloomy brown. There is no green here
## on purpose: everything that grows is dead grass and dead wood.
const DRY_COLORS: Array[Color] = [
	Color("e6d29a"),
	Color("dbc389"),
	Color("cdb277"),
	Color("bda066"),
	Color("ab8d58"),
	Color("987a4c"),
	Color("856a43"),
	Color("715839"),
	Color("5f4a31"),
]
const BARK_COLORS: Array[Color] = [
	Color("6b533c"), Color("5d4732"), Color("523e2c"), Color("473628")
]
const LIANA_COLORS: Array[Color] = [
	Color("dcc681"), Color("cfb56b"), Color("c2a65e"), Color("b39752")
]
const SCALE_MIN: float = 0.9
const SCALE_MAX: float = 1.2
## Level four is a monster the size of a small house, so the scales climb hard.
const MONSTER_SCALES: Array[float] = [0.95, 1.35, 1.6, 2.05]

var kind: int = Kind.GRASS
var anchor_dir: Vector3 = Vector3.UP
var monster_level: int = 1
## Which of the several shapes this prop picked.
var variant: int = 0

var planet: Planet
var boy: Boy

## Where the prop was born: a direction on the sphere plus an offset in real
## metres. Keeping the offset in metres is what stops a cluster from spreading
## across half a growing planet.
var spawn_base: Vector3 = Vector3.UP
var spawn_offset: Vector3 = Vector3.ZERO

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
var _size_scale: float = 1.0
var _twig_count: int = 0
var _liana_count: int = 0
var _mesh_parts: int = 0
var _monster_name: String = ""
var _platforms: Array[Vector3] = []
var _platform_radii: Array[float] = []


func setup(p_kind: int, p_seed: int, p_level: int = 1) -> void:
	kind = p_kind
	_seed = p_seed
	monster_level = clampi(p_level, 1, 4)
	_rng = RandomNumberGenerator.new()
	_rng.seed = _seed
	variant = _rng.randi_range(0, 2)
	_size_scale = _rng.randf_range(SCALE_MIN, SCALE_MAX)
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
		_base_scale = MONSTER_SCALES[monster_level - 1] * _rng.randf_range(0.96, 1.04)
	else:
		_base_scale = _size_scale
	# A soft pop-in makes a new arrival readable without moving the prop itself.
	_visual.scale = Vector3.ONE * 0.12
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(_visual, "scale", Vector3.ONE * _base_scale, 0.55)


func is_monster() -> bool:
	return kind == Kind.MONSTER


## The random size every decoration rolls: 90% to 120%.
func get_size_scale() -> float:
	return _size_scale


func get_visual_scale() -> float:
	return _base_scale


func get_twig_count() -> int:
	return _twig_count


func get_liana_count() -> int:
	return _liana_count


func get_platform_count() -> int:
	return _platforms.size()


func get_platform_heights() -> Array[float]:
	var heights: Array[float] = []
	for platform: Vector3 in _platforms:
		heights.append(platform.y)
	return heights


func get_platform_collider() -> StaticBody3D:
	return get_node_or_null("Platforms") as StaticBody3D


## The world position of a platform's centre, for tests and for anyone who has
## to know where to jump.
func get_platform_point(index: int) -> Vector3:
	if index < 0 or index >= _platforms.size():
		return global_position
	return global_transform * (_platforms[index] * _size_scale)


func get_monster_name() -> String:
	return _monster_name


func get_mesh_parts() -> int:
	return _mesh_parts


## Remembers the spot the spawner picked: a base direction and a real-world
## offset across the surface.
func set_spawn_spot(base: Vector3, offset: Vector3) -> void:
	spawn_base = base.normalized()
	spawn_offset = offset - spawn_base * offset.dot(spawn_base)
	refresh_anchor()


## Rebuilds the surface direction from the metric offset. The offset stays the
## same size when the planet grows, so a cluster of bushes does not stretch out
## into empty space on a huge planet.
func refresh_anchor() -> void:
	var length: float = spawn_offset.length()
	if length < 0.0001 or planet == null:
		anchor_dir = spawn_base
		return
	var angle: float = length / maxf(planet.radius, 0.001)
	anchor_dir = (spawn_base * cos(angle) + (spawn_offset / length) * sin(angle)).normalized()


## Where the monster is in its day: wandering, resting, or running at the boy.
func get_state() -> int:
	return _state


func get_aggro_radius() -> float:
	return aggro_radius_for_level(monster_level)


func get_contact_damage() -> float:
	return contact_damage_for_level(monster_level)


## Bigger bodies bite from further out, otherwise a huge monster would have to
## stand inside the duke before it counts as touching him.
func get_contact_radius() -> float:
	return CONTACT_RADIUS + 0.25 * maxf(_base_scale - 1.0, 0.0)


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
		if distance > get_contact_radius():
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


# ------------------------------------------------------------------ the plants


## A tuft of dead straw: thin tapered blades that lean out of the dust.
func _build_grass() -> void:
	var mesher := PropMesher.new()
	var straw: StandardMaterial3D = _dry_material()
	var pale: StandardMaterial3D = _dry_material()
	var blades: int = _rng.randi_range(6, 10)
	for i: int in blades:
		var height: float = _rng.randf_range(0.24, 0.5)
		var blade := CylinderMesh.new()
		blade.top_radius = 0.002
		blade.bottom_radius = _rng.randf_range(0.006, 0.014)
		blade.height = height
		blade.radial_segments = 4
		blade.rings = 1
		var around: float = _rng.randf_range(0.0, TAU)
		var spread: float = _rng.randf_range(0.0, 0.09)
		var lean := (
			Vector3(_rng.randf_range(-0.3, 0.3), 1.0, _rng.randf_range(-0.3, 0.3)).normalized()
		)
		var base := Vector3(cos(around), 0.0, sin(around)) * spread
		mesher.add_along(blade, base + lean * height * 0.5, lean, straw if i % 2 == 0 else pale)
	# A few dry seed heads so the tuft is not just a fan of sticks.
	for i: int in _rng.randi_range(1, 3):
		var head := SphereMesh.new()
		head.radius = _rng.randf_range(0.014, 0.024)
		head.height = head.radius * 2.4
		head.radial_segments = 8
		head.rings = 4
		var around: float = _rng.randf_range(0.0, TAU)
		var pos := Vector3(cos(around), 0.0, sin(around)) * _rng.randf_range(0.02, 0.1)
		pos.y = _rng.randf_range(0.2, 0.4)
		mesher.add_at(head, pos, pale, Vector3(0.0, 0.0, _rng.randf_range(-20.0, 20.0)))
	_mesh_parts = mesher.get_part_count()
	mesher.commit(_body)


## A tumbleweed that never rolls away: a loose ball of dry twigs.
func _build_bush() -> void:
	var mesher := PropMesher.new()
	var twig: StandardMaterial3D = _dry_material()
	var pale: StandardMaterial3D = _dry_material()
	var ball: float = _rng.randf_range(0.32, 0.42)
	var center := Vector3(0.0, ball * 0.92, 0.0)
	var count: int = _rng.randi_range(38, 52)
	for i: int in count:
		var normal: Vector3 = _random_unit()
		var start: Vector3 = center + normal * ball * _rng.randf_range(0.25, 0.98)
		var across: Vector3 = _random_unit().cross(normal)
		if across.length_squared() < 0.001:
			across = Vector3.RIGHT
		var direction := (across.normalized() + normal * _rng.randf_range(-0.35, 0.5)).normalized()
		var length: float = _rng.randf_range(0.18, 0.38)
		var stick := CylinderMesh.new()
		stick.top_radius = 0.004
		stick.bottom_radius = 0.011
		stick.height = length
		stick.radial_segments = 4
		stick.rings = 1
		var material: StandardMaterial3D = twig if i % 3 else pale
		mesher.add_along(stick, start + direction * length * 0.5, direction, material)
		# Every other twig forks near its far end.
		if i % 2 == 0:
			var tip: Vector3 = start + direction * length
			var fork := (direction + _random_unit() * 0.8).normalized()
			var short: CylinderMesh = stick.duplicate() as CylinderMesh
			short.height = length * 0.55
			mesher.add_along(short, tip + fork * length * 0.25, fork, material)
	_twig_count = count
	_mesh_parts = mesher.get_part_count()
	mesher.commit(_body)


func _build_sapling() -> void:
	_build_dry_oak(
		_rng.randf_range(0.95, 1.2), _rng.randf_range(0.05, 0.07), 5, _rng.randi_range(6, 9)
	)


func _build_tree() -> void:
	_build_dry_oak(
		_rng.randf_range(2.0, 2.6), _rng.randf_range(0.12, 0.16), 6, _rng.randi_range(9, 13)
	)


## A bare oak: a crooked trunk, a handful of forked branches, and pale yellow
## lianas hanging off the tips. Three variants change the silhouette.
func _build_dry_oak(height: float, girth: float, branches: int, lianas: int) -> void:
	var mesher := PropMesher.new()
	var bark: StandardMaterial3D = _bark_material()
	var bark_dark: StandardMaterial3D = _bark_material(true)
	var vine: StandardMaterial3D = _liana_material()
	var tips: Array[Vector3] = []

	var lean: float = 0.16 if variant == 1 else 0.07
	var trunk_top := Vector3(
		_rng.randf_range(-lean, lean), height * 0.64, _rng.randf_range(-lean, lean)
	)
	_branch(mesher, Vector3.ZERO, trunk_top, girth, girth * 0.42, bark)
	# Roots splaying into the dust.
	for i: int in 3:
		var around: float = TAU * float(i) / 3.0 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(around), 0.0, sin(around))
		_branch(
			mesher,
			Vector3(0.0, girth * 1.2, 0.0),
			out * girth * 3.2 + Vector3(0.0, -girth * 0.9, 0.0),
			girth * 0.6,
			girth * 0.18,
			bark_dark,
		)

	# One leader, or a fork into two on the third variant.
	var leaders: int = 2 if variant == 2 else 1
	for leader: int in leaders:
		var base: Vector3 = trunk_top
		if leaders > 1:
			base += Vector3(0.09 * (1.0 if leader == 0 else -1.0), 0.0, 0.0)
		var crest: Vector3 = (
			base
			+ Vector3(_rng.randf_range(-0.12, 0.12), height * 0.22, _rng.randf_range(-0.12, 0.12))
		)
		_branch(mesher, base, crest, girth * 0.42, girth * 0.18, bark)
		tips.append(crest)
		var spread: float = 0.75 if variant == 0 else 1.15
		for i: int in branches:
			# Branches leave at every height of the leader, not all from the top,
			# so the crown has the layered look of a real oak.
			var attach: Vector3 = base.lerp(crest, _rng.randf_range(0.05, 0.95))
			var around: float = TAU * float(i) / float(branches) + _rng.randf_range(-0.5, 0.5)
			var reach: float = height * _rng.randf_range(0.16, 0.3) * spread
			var tip := (
				attach
				+ Vector3(
					cos(around) * reach, reach * _rng.randf_range(0.5, 1.1), sin(around) * reach
				)
			)
			var thickness: float = lerpf(
				girth * 0.42, girth * 0.14, attach.distance_to(base) / maxf(height, 0.01)
			)
			_branch(mesher, attach, tip, thickness, girth * 0.07, bark)
			tips.append(tip)
			# Each bough forks twice, which is what makes a bare tree read.
			for fork_index: int in 2:
				var fork_side: float = -1.0 if fork_index == 0 else 1.0
				var fork := (
					(
						Vector3(cos(around), 0.85, sin(around)) * 0.6
						+ Vector3(-sin(around), 0.2, cos(around)) * 0.55 * fork_side
						+ _random_unit() * 0.35
					)
					. normalized()
				)
				var fork_tip: Vector3 = tip + fork * reach * _rng.randf_range(0.4, 0.7)
				_branch(mesher, tip, fork_tip, girth * 0.07, girth * 0.022, bark_dark)
				tips.append(fork_tip)

	# Lianas hang from the fork tips all around the crown.
	for i: int in lianas:
		var tip: Vector3 = tips[_rng.randi_range(0, tips.size() - 1)]
		var length: float = minf(_rng.randf_range(0.3, 0.72) * height, tip.y - 0.2)
		if length > 0.12:
			_liana(mesher, tip, length, vine)
	_mesh_parts = mesher.get_part_count()
	mesher.commit(_body)


## The huge oak: branch tips flatten into amoeba-shaped platforms at climbing
## heights, with yellow lianas hanging off their rims.
func _build_big_tree() -> void:
	var mesher := PropMesher.new()
	var bark: StandardMaterial3D = _bark_material()
	var bark_dark: StandardMaterial3D = _bark_material(true)
	var vine: StandardMaterial3D = _liana_material()
	var pad: StandardMaterial3D = _liana_material()
	var pad_alt: StandardMaterial3D = _liana_material()
	var height: float = 3.6
	var girth: float = _rng.randf_range(0.4, 0.48)
	var trunk_top := Vector3(
		_rng.randf_range(-0.1, 0.1), height * 0.62, _rng.randf_range(-0.1, 0.1)
	)
	_branch(mesher, Vector3.ZERO, trunk_top, girth, girth * 0.55, bark)
	for i: int in 4:
		var around: float = TAU * float(i) / 4.0 + _rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(around), 0.0, sin(around))
		_branch(
			mesher,
			Vector3(0.0, girth * 1.1, 0.0),
			out * girth * 2.8 + Vector3(0.0, -girth * 0.7, 0.0),
			girth * 0.62,
			girth * 0.2,
			bark_dark,
		)
	# A knot of thick boughs above the trunk, so the crown reads as one oak.
	for i: int in 3:
		var around: float = TAU * float(i) / 3.0 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(around), 0.0, sin(around))
		_branch(
			mesher,
			trunk_top,
			trunk_top + out * _rng.randf_range(0.5, 0.9) + Vector3(0.0, 0.55, 0.0),
			girth * 0.5,
			girth * 0.18,
			bark,
		)

	# Platforms climb in a spiral, each step low enough for a charged jump.
	var count: int = _rng.randi_range(5, 9)
	var lowest: float = 0.72
	var highest: float = 3.4
	for i: int in count:
		var step: float = float(i) / float(maxi(count - 1, 1))
		var platform_height: float = lerpf(lowest, highest, step)
		var around: float = _rng.randf_range(-0.2, 0.2) + float(i) * 0.62
		var distance: float = _rng.randf_range(1.05, 1.45)
		var radius: float = _rng.randf_range(0.7, 1.05)
		var centre := Vector3(cos(around) * distance, platform_height, sin(around) * distance)
		var attach := Vector3(
			cos(around) * girth * 0.7, platform_height - 0.55, sin(around) * girth * 0.7
		)
		_branch(mesher, attach, centre, 0.18, 0.09, bark)
		_platform(mesher, centre, radius, pad if i % 2 == 0 else pad_alt)
		_platforms.append(centre)
		_platform_radii.append(radius)
		for _j: int in _rng.randi_range(1, 3):
			var rim_angle: float = _rng.randf() * TAU
			var rim := Vector3(
				centre.x + cos(rim_angle) * radius * 0.85,
				centre.y - 0.03,
				centre.z + sin(rim_angle) * radius * 0.85
			)
			var length: float = minf(_rng.randf_range(0.45, 1.4), rim.y - 0.1)
			if length > 0.15:
				_liana(mesher, rim, length, vine)
	# A few bare twigs poking out of the crown.
	for i: int in _rng.randi_range(4, 7):
		var around: float = _rng.randf() * TAU
		var start := Vector3(
			cos(around) * 0.15, height * _rng.randf_range(0.62, 0.78), sin(around) * 0.15
		)
		var tip := (
			start
			+ Vector3(
				cos(around) * _rng.randf_range(0.3, 0.7),
				_rng.randf_range(0.3, 0.75),
				sin(around) * _rng.randf_range(0.3, 0.7)
			)
		)
		_branch(mesher, start, tip, girth * 0.16, 0.012, bark_dark)

	_mesh_parts = mesher.get_part_count()
	mesher.commit(_body)
	_build_platform_collision()


## A platform is a lumpy pancake rather than a disc: a few squashed spheres
## merged together give the amoeba outline, and one flat collider makes it
## walkable.
func _platform(
	mesher: PropMesher, centre: Vector3, radius: float, material: StandardMaterial3D
) -> void:
	var tilt := Vector3(
		_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-6.0, 6.0)
	)
	var core := SphereMesh.new()
	core.radius = radius
	core.height = radius * 0.36
	core.radial_segments = 20
	core.rings = 8
	mesher.add_at(core, centre, material, tilt, Vector3(1.0, 0.5, 1.0))
	var blobs: int = _rng.randi_range(3, 5)
	for i: int in blobs:
		var around: float = TAU * float(i) / float(blobs) + _rng.randf_range(-0.3, 0.3)
		var blob := SphereMesh.new()
		blob.radius = radius * _rng.randf_range(0.42, 0.62)
		blob.height = blob.radius * 0.42
		blob.radial_segments = 16
		blob.rings = 6
		var offset := Vector3(
			cos(around) * radius * 0.62, _rng.randf_range(-0.02, 0.04), sin(around) * radius * 0.62
		)
		mesher.add_at(blob, centre + offset, material, tilt)


func _build_platform_collision() -> void:
	if _platforms.is_empty():
		return
	# The collider lives on the prop root, already at the final size, so the
	# duke can land on a pad the moment the oak appears.
	var body := StaticBody3D.new()
	body.name = "Platforms"
	body.collision_layer = 1
	body.collision_mask = 1
	for i: int in _platforms.size():
		var holder := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = _platform_radii[i] * 0.8 * _size_scale
		shape.height = 0.18
		holder.shape = shape
		holder.position = _platforms[i] * _size_scale + Vector3(0.0, 0.02, 0.0)
		body.add_child(holder)
	add_child(body)


# ------------------------------------------------------------------- monsters


func _build_monster() -> void:
	var mesher := PropMesher.new()
	MonsterBuilder.build(monster_level, _rng, mesher)
	_mesh_parts = mesher.get_part_count()
	_monster_name = MonsterBuilder.name_for_level(monster_level)
	mesher.commit(_body)


# ------------------------------------------------------------------- helpers


## A tapered branch between two local points.
func _branch(
	mesher: PropMesher,
	from: Vector3,
	to: Vector3,
	r0: float,
	r1: float,
	material: StandardMaterial3D
) -> void:
	var length: float = from.distance_to(to)
	if length < 0.004:
		return
	var limb := CylinderMesh.new()
	limb.bottom_radius = maxf(r0, 0.004)
	limb.top_radius = maxf(r1, 0.002)
	limb.height = length
	limb.radial_segments = 7
	limb.rings = 1
	mesher.add_along(limb, (from + to) * 0.5, to - from, material)


## A strand of lianas hanging straight down, ending in a dry leaf or two.
func _liana(
	mesher: PropMesher, start: Vector3, length: float, material: StandardMaterial3D
) -> void:
	_liana_count += 1
	var points: int = 4
	var sway := Vector3(_rng.randf_range(-0.09, 0.09), 0.0, _rng.randf_range(-0.09, 0.09))
	var point: Vector3 = start
	for i: int in points:
		var next: Vector3 = (
			point + Vector3(0.0, -length / float(points), 0.0) + sway * (0.6 + 0.55 * float(i))
		)
		var strand := CylinderMesh.new()
		strand.top_radius = 0.005
		strand.bottom_radius = 0.009
		strand.height = point.distance_to(next)
		strand.radial_segments = 4
		strand.rings = 1
		mesher.add_along(strand, (point + next) * 0.5, next - point, material)
		point = next
	for i: int in _rng.randi_range(2, 3):
		var leaf := SphereMesh.new()
		leaf.radius = _rng.randf_range(0.045, 0.07)
		leaf.height = leaf.radius * 0.5
		leaf.radial_segments = 10
		leaf.rings = 5
		var at: Vector3 = (
			start
			+ Vector3(
				_rng.randf_range(-0.03, 0.03),
				-length * _rng.randf_range(0.3, 0.95),
				_rng.randf_range(-0.03, 0.03)
			)
		)
		(
			mesher
			. add_at(
				leaf,
				at,
				material,
				Vector3(_rng.randf_range(-25.0, 25.0), 0.0, _rng.randf_range(-25.0, 25.0)),
				Vector3(1.0, 0.6, 0.8),
			)
		)


func _random_unit() -> Vector3:
	var value := Vector3(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	)
	if value.length_squared() < 0.0001:
		return Vector3.UP
	return value.normalized()


## Picks a random shade between pale straw and gloomy brown.
func _dry_color() -> Color:
	var scaled: float = _rng.randf() * float(DRY_COLORS.size() - 1)
	var index: int = mini(int(scaled), DRY_COLORS.size() - 2)
	return (DRY_COLORS[index] as Color).lerp(DRY_COLORS[index + 1], scaled - float(index))


func _dry_material() -> StandardMaterial3D:
	return _material(_dry_color(), 0.94)


func _bark_material(dark: bool = false) -> StandardMaterial3D:
	var color: Color = BARK_COLORS[_rng.randi_range(0, BARK_COLORS.size() - 1)]
	if dark:
		color = color.darkened(0.16)
	return _material(color, 0.96)


func _liana_material() -> StandardMaterial3D:
	return _material(LIANA_COLORS[_rng.randi_range(0, LIANA_COLORS.size() - 1)], 0.9)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
