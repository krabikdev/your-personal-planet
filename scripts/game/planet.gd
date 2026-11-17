class_name Planet
extends StaticBody3D

## The little bare stone world. Radius, collision and surface shader all follow
## one radius value, so growing the planet is a single animated number.

signal radius_changed(new_radius: float)
signal growth_finished(added_radius: float)

@export var initial_radius: float = 5.0

var radius: float = 5.0

var _sphere_shape: SphereShape3D
var _surface_material: ShaderMaterial
var _growing: bool = false
var _grow_tween: Tween

@onready var _collision: CollisionShape3D = %Collision
@onready var _surface: MeshInstance3D = %Surface


func _ready() -> void:
	radius = initial_radius
	_surface_material = _surface.material_override as ShaderMaterial
	_sphere_shape = SphereShape3D.new()
	_sphere_shape.radius = radius
	_collision.shape = _sphere_shape
	_apply_radius(radius)


func get_center() -> Vector3:
	return global_position


func get_surface_point(direction: Vector3) -> Vector3:
	return global_position + direction.normalized() * radius


func surface_gravity() -> float:
	return PlanetProfile.surface_gravity(radius)


func gravity_at(world_position: Vector3) -> float:
	var distance: float = (world_position - global_position).length()
	return PlanetProfile.gravity_at(radius, distance)


func get_jump_speed() -> float:
	return PlanetProfile.jump_speed(radius)


func is_jump_safe() -> bool:
	return PlanetProfile.is_jump_safe(radius)


func cold_altitude() -> float:
	return PlanetProfile.cold_altitude(radius)


func grow(size_factor: float) -> float:
	var added: float = PlanetProfile.growth_for_stone(radius, size_factor)
	var target: float = radius + added
	if _grow_tween != null and _grow_tween.is_valid():
		_grow_tween.kill()
	_growing = true
	_grow_tween = create_tween()
	_grow_tween.set_trans(Tween.TRANS_SINE)
	_grow_tween.set_ease(Tween.EASE_IN_OUT)
	_grow_tween.tween_method(_apply_radius, radius, target, 1.8)
	_grow_tween.finished.connect(
		func() -> void:
			_growing = false
			growth_finished.emit(added)
			radius_changed.emit(radius),
		CONNECT_ONE_SHOT
	)
	return added


func is_growing() -> bool:
	return _growing


func apply_radius(value: float) -> void:
	_apply_radius(value)


func _apply_radius(value: float) -> void:
	radius = maxf(value, 2.0)
	_surface.scale = Vector3.ONE * radius
	if _sphere_shape != null:
		_sphere_shape.radius = radius
	if _surface_material != null:
		_surface_material.set_shader_parameter("planet_radius", radius)
	radius_changed.emit(radius)
