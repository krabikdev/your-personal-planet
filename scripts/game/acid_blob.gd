class_name AcidBlob
extends Node3D

## The little pumpkin head's spit: a purple blob of acid that flies straight at
## the monster it was aimed at. One hit is enough to dissolve a monster.

const SPEED: float = 9.0
const LIFETIME: float = 4.0
const HIT_DISTANCE: float = 0.3
const ACID_COLOR := Color("a05ac8")

var _target: Node3D
var _life: float = 0.0
var _speed: float = SPEED


func setup(from: Vector3, target: Node3D, speed: float = SPEED) -> void:
	global_position = from
	_target = target
	_speed = maxf(speed, 0.1)
	_build()


func _process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var goal: Vector3 = _goal()
	var step: float = _speed * delta
	if global_position.distance_to(goal) <= maxf(step, HIT_DISTANCE):
		_hit()
		return
	global_position = global_position.move_toward(goal, step)
	rotate_y(delta * 6.0)


## Advances the blob straight onto its target. Tests use it instead of waiting
## out the flight.
func debug_reach() -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	global_position = _goal()
	_hit()


func _goal() -> Vector3:
	# Aim a little above the monster's feet so the blob visibly lands on it.
	return _target.global_position + Vector3.UP * 0.35


func _hit() -> void:
	if _target != null and is_instance_valid(_target):
		AudioDirector.play_sfx_3d("acid_hit", global_position, get_parent(), -3.0, 4.0)
		if _target.has_method("hit_by_acid"):
			_target.hit_by_acid()
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
