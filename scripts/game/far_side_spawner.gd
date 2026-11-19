class_name FarSideSpawner
extends Node3D

## Populates the far side of the planet. Every so often a roll picks something
## from the decoration-and-monster group and places it in a wide cap of surface
## exactly opposite the boy. The cap grows with the planet, the wait shrinks as
## the planet grows, and what can appear depends on how big the planet is.

signal spawned(kind: int)

## Order must stay in sync with DecorProp.Kind.
enum Kind { GRASS, BUSH, SAPLING, TREE, BIG_TREE, MONSTER }

const REGION_ANGLE: float = 0.9
## However big the planet gets, arrivals stay inside this many metres of the
## spawn centre: a cluster spread across a whole huge planet is never found.
const REGION_MAX_METRES: float = 22.0
## The walk to the spawn centre is capped too. On a big world the antipode can
## be kilometres away, which is why nothing seemed to appear any more.
const SPAWN_DISTANCE_MAX: float = 60.0
const FIRST_INTERVAL: float = 600.0
const LAST_INTERVAL: float = 1.0
const FIRST_SIZE: float = 20.0
const FULL_SIZE: float = 1000.0
const MAX_PROPS: int = 120
## A group (a monster pair, for instance) stands within this many metres.
const CLUSTER_SPREAD_METRES: float = 3.0
const DEBUG_SPREAD_METRES: float = 2.8

var planet: Planet
var player: Boy

var _timer: float = FIRST_INTERVAL
var _props: Array[DecorProp] = []


func setup(p_planet: Planet, p_player: Boy) -> void:
	planet = p_planet
	player = p_player
	_timer = get_interval()
	if not planet.radius_changed.is_connected(_on_radius_changed):
		planet.radius_changed.connect(_on_radius_changed)


func _process(delta: float) -> void:
	if planet == null or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		spawn_one()
		_timer = get_interval()


func get_interval() -> float:
	if planet == null:
		return FIRST_INTERVAL
	return interval_for_size(PlanetProfile.diameter_in_boys(planet.radius))


func get_time_left() -> float:
	return _timer


func get_prop_count() -> int:
	return _props.size()


func get_props() -> Array[DecorProp]:
	return _props


func get_region_radius() -> float:
	if planet == null:
		return 0.0
	return planet.radius * sin(_region_angle())


## How far from the boy the next arrival lands, along the surface. The antipode
## is used while it is close enough; past that the walk is capped so a huge
## planet still has something to find.
func get_spawn_distance() -> float:
	if planet == null:
		return 0.0
	return minf(PI * planet.radius, SPAWN_DISTANCE_MAX)


func _region_angle() -> float:
	if planet == null:
		return REGION_ANGLE
	return minf(REGION_ANGLE, REGION_MAX_METRES / maxf(planet.radius, 0.001))


## Seconds between spawns: 600 s at size 20, easing down to 1 s at size 1000.
## The curve is an inverse progression, so it never jumps or goes backwards.
static func interval_for_size(size: float) -> float:
	var s: float = maxf(size, FIRST_SIZE)
	var k: float = (FIRST_INTERVAL / LAST_INTERVAL - 1.0) / (FULL_SIZE - FIRST_SIZE)
	return clampf(FIRST_INTERVAL / (1.0 + (s - FIRST_SIZE) * k), LAST_INTERVAL, FIRST_INTERVAL)


## The weighted group for a planet of the given size. Weights add up to 100.
static func spawn_table_for_size(size: float) -> Array[Dictionary]:
	if size < 50.0:
		return [
			{"kind": Kind.GRASS, "count": 1, "weight": 80.0},
			{"kind": Kind.MONSTER, "count": 1, "weight": 20.0, "level": 1},
		]
	if size < 200.0:
		return [
			{"kind": Kind.GRASS, "count": 1, "weight": 50.0},
			{"kind": Kind.BUSH, "count": 1, "weight": 25.0},
			{"kind": Kind.MONSTER, "count": 1, "weight": 20.0, "level": 1},
			{"kind": Kind.MONSTER, "count": 2, "weight": 5.0, "level": 2},
		]
	if size < 500.0:
		return [
			{"kind": Kind.GRASS, "count": 1, "weight": 30.0},
			{"kind": Kind.BUSH, "count": 1, "weight": 15.0},
			{"kind": Kind.SAPLING, "count": 1, "weight": 5.0},
			{"kind": Kind.MONSTER, "count": 1, "weight": 30.0, "level": 1},
			{"kind": Kind.MONSTER, "count": 2, "weight": 15.0, "level": 2},
			{"kind": Kind.MONSTER, "count": 3, "weight": 5.0, "level": 3},
		]
	return [
		{"kind": Kind.GRASS, "count": 1, "weight": 20.0},
		{"kind": Kind.BUSH, "count": 1, "weight": 15.0},
		{"kind": Kind.SAPLING, "count": 1, "weight": 10.0},
		{"kind": Kind.TREE, "count": 1, "weight": 5.0},
		{"kind": Kind.MONSTER, "count": 1, "weight": 20.0, "level": 1},
		{"kind": Kind.MONSTER, "count": 2, "weight": 15.0, "level": 2},
		{"kind": Kind.MONSTER, "count": 3, "weight": 10.0, "level": 3},
		{"kind": Kind.MONSTER, "count": 4, "weight": 5.0, "level": 4},
	]


## Turns a 0..1 roll into one entry of the group, so the weights stay testable.
static func roll_spawn(size: float, roll: float) -> Dictionary:
	var table: Array[Dictionary] = spawn_table_for_size(size)
	var total: float = 0.0
	for entry: Dictionary in table:
		total += float(entry["weight"])
	var target: float = clampf(roll, 0.0, 0.9999) * total
	var passed: float = 0.0
	for entry: Dictionary in table:
		passed += float(entry["weight"])
		if target < passed:
			return entry
	return table[table.size() - 1]


func spawn_one() -> DecorProp:
	if planet == null or player == null:
		return null
	var size: float = PlanetProfile.diameter_in_boys(planet.radius)
	var entry: Dictionary = roll_spawn(size, randf())
	var kind: int = int(entry["kind"])
	var count: int = int(entry["count"])
	var level: int = int(entry.get("level", 1))
	var direction: Vector3 = _region_direction()
	var placed: DecorProp = null
	for i: int in count:
		var offset: float = 0.0
		if count > 1:
			offset = CLUSTER_SPREAD_METRES * sqrt(float(i) / float(count))
		placed = _place(kind, direction, level, offset)
	spawned.emit(kind)
	return placed


## Places one monster of the given level right where a test needs it.
func debug_spawn_monster(direction: Vector3, level: int = 1) -> DecorProp:
	if planet == null or player == null:
		return null
	return _place(Kind.MONSTER, direction.normalized(), level)


func debug_spawn_all() -> void:
	if planet == null or player == null:
		return
	var kinds: Array[int] = [
		Kind.GRASS,
		Kind.BUSH,
		Kind.SAPLING,
		Kind.TREE,
		Kind.BIG_TREE,
		Kind.MONSTER,
		Kind.MONSTER,
		Kind.MONSTER,
		Kind.MONSTER,
	]
	var base: Vector3 = -player.get_up()
	var middle: float = (float(kinds.size()) - 1.0) * 0.5
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(base)) > 0.9:
		reference = Vector3.RIGHT
	var line: Vector3 = (reference - base * reference.dot(base)).normalized()
	var level: int = 1
	for i: int in kinds.size():
		var offset: Vector3 = line * ((float(i) - middle) * DEBUG_SPREAD_METRES)
		_place_offset(kinds[i], base, offset, level)
		if kinds[i] == Kind.MONSTER:
			level = mini(level + 1, 4)


func _place(kind: int, direction: Vector3, level: int = 1, offset: float = 0.0) -> DecorProp:
	return _place_offset(kind, direction, _tangent_offset(direction, absf(offset)), level)


func _place_offset(kind: int, direction: Vector3, offset: Vector3, level: int = 1) -> DecorProp:
	var prop := DecorProp.new()
	prop.name = "Prop%d" % _props.size()
	add_child(prop)
	prop.planet = planet
	prop.setup(kind, randi(), level)
	prop.set_spawn_spot(direction, offset)
	_settle(prop)
	if kind == Kind.MONSTER:
		prop.configure_monster(planet, player, level)
	prop.tree_exiting.connect(_on_prop_exiting.bind(prop), CONNECT_ONE_SHOT)
	_props.append(prop)
	if _props.size() > MAX_PROPS:
		var oldest: DecorProp = _props.pop_front()
		oldest.queue_free()
	return prop


func _on_prop_exiting(prop: DecorProp) -> void:
	_props.erase(prop)


func _settle(prop: DecorProp) -> void:
	var up: Vector3 = prop.anchor_dir
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(up)) > 0.9:
		reference = Vector3.RIGHT
	var forward: Vector3 = (reference - up * reference.dot(up)).normalized()
	var right: Vector3 = forward.cross(up).normalized()
	prop.global_transform = Transform3D(
		Basis(right, up, -forward), planet.get_center() + up * planet.radius
	)


func _on_radius_changed(new_radius: float) -> void:
	if planet == null:
		return
	# Props keep their size; the ground under them rises. Static plants also
	# rebuild their spot from the metric offset they were born with, so a
	# cluster stays a cluster instead of stretching across a bigger planet.
	for prop: DecorProp in _props:
		if not is_instance_valid(prop):
			continue
		if not prop.is_monster():
			prop.refresh_anchor()
		prop.global_position = planet.get_center() + prop.anchor_dir * new_radius
	# A bigger planet also means a faster cadence: an already pending arrival
	# should not keep waiting out the old, slower timer.
	_timer = minf(_timer, get_interval())


func _region_direction() -> Vector3:
	var up: Vector3 = player.get_up()
	var angle: float = clampf(SPAWN_DISTANCE_MAX / maxf(planet.radius, 0.001), 0.0, PI)
	var centre: Vector3 = _tilted(up, angle)
	var spread: float = _region_angle()
	if spread <= 0.0:
		return centre
	return _tilted(centre, spread * sqrt(randf()))


## A point `metres` away from `base` across the surface, at a random bearing.
func _tangent_offset(base: Vector3, metres: float) -> Vector3:
	if metres <= 0.0:
		return Vector3.ZERO
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(base)) > 0.9:
		reference = Vector3.RIGHT
	var first: Vector3 = (reference - base * reference.dot(base)).normalized()
	var second: Vector3 = base.cross(first).normalized()
	var bearing: float = randf() * TAU
	return (first * cos(bearing) + second * sin(bearing)) * metres


## A direction `angle` radians away from `base`, at a random bearing.
func _tilted(base: Vector3, angle: float) -> Vector3:
	var reference: Vector3 = Vector3.FORWARD
	if absf(reference.dot(base)) > 0.9:
		reference = Vector3.RIGHT
	var first: Vector3 = (reference - base * reference.dot(base)).normalized()
	var second: Vector3 = base.cross(first).normalized()
	var bearing: float = randf() * TAU
	var tangent: Vector3 = first * cos(bearing) + second * sin(bearing)
	return (base * cos(angle) + tangent * sin(angle)).normalized()
