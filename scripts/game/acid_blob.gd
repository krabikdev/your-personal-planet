class_name AcidBlob
extends Node3D

## The little pumpkin head's spit: a purple blob of acid that skims just above
## the planet's surface. It keeps a constant height over the ground and curves
## with it, so the shot reads as a low arc across the dust rather than a line
## through the air. Whatever it lands on burns.

const SPEED: float = 4.5
const LIFETIME: float = 8.0
const HIT_DISTANCE: float = 0.35
## How high above the ground the blob flies, in metres.
const ARC_HEIGHT: float = 0.55
const DEFAULT_DAMAGE: float = 10.0
const ACID_COLOR := Color("a05ac8")

var _target: Node3D
var _planet: Planet
var _dir: Vector3 = Vector3.UP
var _life: float = 0.0
var _speed: float = SPEED
var _damage: float = DEFAULT_DAMAGE


func setup(
	from: Vector3,
	target: Node3D,
	speed: float = SPEED,
	damage: float = DEFAULT_DAMAGE,
	planet_ref: Planet = null
) -> void:
	_target = target
	_speed = maxf(speed, 0.1)
	_damage = maxf(damage, 0.0)
	_planet = planet_ref
	if _planet != null:
		_dir = (from - _planet.get_center()).normalized()
		if _dir.length_squared() < 0.0001:
			_dir = Vector3.UP
		global_position = _planet.get_center() + _dir * (_planet.radius + ARC_HEIGHT)
	else:
		global_position = from
	_build()


func _process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	_advance(delta)


## One step of the flight, used by `_process` and by tests that would rather not
## wait out the frames. Returns false once the blob has landed and freed itself.
func debug_advance(delta: float) -> bool:
	_life += delta
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return false
	_advance(delta)
	return not is_queued_for_deletion()


## How high above the ground the blob is right now.
func get_altitude() -> float:
	if _planet == null:
		return 0.0
	return global_position.distance_to(_planet.get_center()) - _planet.radius


func get_damage() -> float:
	return _damage


## Advances the blob straight onto its target. Tests use it instead of waiting
## out the flight.
func debug_reach() -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	global_position = _goal()
	_hit()


func _advance(delta: float) -> void:
	if _planet == null:
		_fly_straight(delta)
		return
	var center: Vector3 = _planet.get_center()
	var orbit: float = maxf(_planet.radius + ARC_HEIGHT, 0.001)
	var goal_dir: Vector3 = (_goal() - center).normalized()
	if goal_dir.length_squared() < 0.0001:
		goal_dir = _dir
	var angle: float = _dir.angle_to(goal_dir)
	var step: float = _speed * delta / orbit
	if angle <= maxf(step, HIT_DISTANCE / orbit):
		_dir = goal_dir
		global_position = center + goal_dir * orbit
		_hit()
		return
	_dir = _dir.slerp(goal_dir, step / maxf(angle, 0.0001)).normalized()
	global_position = center + _dir * orbit
	rotate_y(delta * 6.0)


## Fallback for a blob with no planet to hug: a plain straight line.
func _fly_straight(delta: float) -> void:
	var goal: Vector3 = _goal()
	var step: float = _speed * delta
	if global_position.distance_to(goal) <= maxf(step, HIT_DISTANCE):
		_hit()
		return
	global_position = global_position.move_toward(goal, step)
	rotate_y(delta * 6.0)


func _goal() -> Vector3:
	# Aim a little above the monster's feet so the blob visibly lands on it.
	return _target.global_position + Vector3.UP * 0.35


func _hit() -> void:
	if _target != null and is_instance_valid(_target):
		AudioDirector.play_sfx_3d("acid_hit", global_position, get_parent(), -3.0, 4.0)
		if _target.has_method("hit_by_acid"):
			_target.hit_by_acid(_damage)
	queue_free()


func _build() -> void:
	var blob := MeshInstance3D.new()
	blob.name = "Blob"
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.19
	mesh.radial_segments = 14
	mesh.rings = 7
	blob.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = ACID_COLOR
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = ACID_COLOR
	material.emission_energy_multiplier = 1.4
	blob.material_override = material
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

	var trail := MeshInstance3D.new()
	trail.name = "Trail"
	var tail := SphereMesh.new()
	tail.radius = 0.06
	tail.height = 0.12
	tail.radial_segments = 10
	tail.rings = 5
	trail.mesh = tail
	var faint: StandardMaterial3D = material.duplicate() as StandardMaterial3D
	faint.albedo_color = Color(ACID_COLOR.r, ACID_COLOR.g, ACID_COLOR.b, 0.55)
	faint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faint.emission_energy_multiplier = 0.7
	trail.material_override = faint
	trail.position = Vector3(0.0, 0.0, 0.16)
	add_child(trail)
