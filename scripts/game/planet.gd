class_name Planet
extends StaticBody3D

## The little bare stone world. Radius, collision and surface shader all follow
## one radius value, so growing the planet is a single animated number.

signal radius_changed(new_radius: float)
signal growth_finished(added_radius: float)

## One measurement per SphereMesh resource, however many planets use it.
static var _sphere_ratios: Dictionary[int, Vector2] = {}

@export var initial_radius: float = 5.0

var radius: float = 5.0

var _sphere_shape: SphereShape3D
var _surface_material: ShaderMaterial
var _surface_mid_ratio: float = 1.0
var _surface_spread: float = 0.0
var _growing: bool = false
var _grow_tween: Tween

@onready var _collision: CollisionShape3D = %Collision
@onready var _surface: MeshInstance3D = %Surface


func _ready() -> void:
	radius = initial_radius
	_surface_material = _surface.material_override as ShaderMaterial
	_measure_surface_sphere()
	_sphere_shape = SphereShape3D.new()
	_sphere_shape.radius = radius
	_collision.shape = _sphere_shape
	_apply_radius(radius)


## A sphere that is drawn as triangles is not a sphere: every flat face sits a
## little inside the true sphere, and how far it sits grows with the radius. At
## five metres the gap is a millimetre; at a few hundred it is tens of
## centimetres, which is why objects on the ground start to look like they are
## floating once the planet grows. Measuring the mesh lets us scale it so the
## drawn faces are centred on the collision sphere instead.
func _measure_surface_sphere() -> void:
	_surface_mid_ratio = 1.0
	_surface_spread = 0.0
	var mesh: Mesh = _surface.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var mesh_id: int = mesh.get_instance_id()
	if _sphere_ratios.has(mesh_id):
		_surface_mid_ratio = _sphere_ratios[mesh_id].x
		_surface_spread = _sphere_ratios[mesh_id].y
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.size() < Mesh.ARRAY_MAX:
		return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		return
	var lowest: float = 1.0
	var highest: float = 0.0
	for i: int in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		var cross: Vector3 = (b - a).cross(c - a)
		if cross.length_squared() < 0.000000000001:
			continue
		var distance: float = absf(cross.normalized().dot(a))
		lowest = minf(lowest, distance)
		highest = maxf(highest, distance)
	if highest <= 0.0 or lowest <= 0.5:
		return
	_surface_mid_ratio = (lowest + highest) * 0.5
	_surface_spread = (highest - lowest) * 0.5
	_sphere_ratios[mesh_id] = Vector2(_surface_mid_ratio, _surface_spread)


## How far the drawn ground can stray from the collision sphere, in metres.
func get_surface_error() -> float:
	if _surface_mid_ratio <= 0.0:
		return 0.0
	return radius * _surface_spread / _surface_mid_ratio


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
	_surface.scale = Vector3.ONE * (radius / _surface_mid_ratio)
	if _sphere_shape != null:
		_sphere_shape.radius = radius
	if _surface_material != null:
		_surface_material.set_shader_parameter("planet_radius", radius)
	radius_changed.emit(radius)
