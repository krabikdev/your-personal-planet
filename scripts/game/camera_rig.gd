class_name CameraRig
extends Node3D

## A chase camera that keeps the planet's local "up" as its up vector. The
## heading is parallel transported as the boy walks around the sphere, so the
## view rolls smoothly with him and never flips at the poles.

@export var base_lift: float = 3.0
@export var base_distance: float = 3.4
@export var mouse_sensitivity: float = 0.0025

var _target: Node3D
var _planet: Planet
var _orbit: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.FORWARD
var _view_yaw: float = 0.0
var _shake: float = 0.0
var _intro: float = 1.0
var _time: float = 0.0
var _focus: float = 1.0
var _target_focus: float = 1.0

@onready var _camera: Camera3D = %Camera


func setup(target: Node3D, planet: Planet) -> void:
	_target = target
	_planet = planet
	var up: Vector3 = (target.global_position - planet.get_center()).normalized()
	var desired_heading: Vector3 = Vector3.FORWARD - up * up.dot(Vector3.FORWARD)
	if desired_heading.length_squared() < 0.01:
		desired_heading = up.cross(Vector3.RIGHT)
	_heading = desired_heading.normalized()
	_orbit = target.global_position
	_snap()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func play_intro() -> void:
	_intro = 1.0


func set_focus(value: float) -> void:
	_target_focus = clampf(value, 1.0, 2.2)


func orbit_by(pixels: float) -> void:
	_view_yaw = wrapf(_view_yaw - pixels * mouse_sensitivity, -PI, PI)


func get_view_yaw() -> float:
	return _view_yaw


func get_tangent_forward(up: Vector3) -> Vector3:
	var forward: Vector3 = _heading - up * _heading.dot(up)
	if forward.length_squared() < 0.0001:
		forward = up.cross(Vector3.RIGHT)
	return forward.normalized().rotated(up, _view_yaw)


func get_tangent_right(up: Vector3) -> Vector3:
	return get_tangent_forward(up).cross(up).normalized()


func get_camera() -> Camera3D:
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		orbit_by((event as InputEventMouseMotion).relative.x)


func _process(delta: float) -> void:
	if _target == null or _planet == null:
		return
	_time += delta
	_intro = move_toward(_intro, 0.0, delta * 0.55)
	_shake = move_toward(_shake, 0.0, delta * 2.2)
	_focus = lerpf(_focus, _target_focus, 1.0 - exp(-3.5 * delta))

	var target_position: Vector3 = _target.global_position
	var horizon: float = (target_position - _planet.get_center()).length() - _planet.radius
	_orbit = _orbit.lerp(target_position, 1.0 - exp(-11.0 * delta))
	var orbit_up: Vector3 = (_orbit - _planet.get_center()).normalized()

	_heading = _heading - orbit_up * _heading.dot(orbit_up)
	if _heading.length_squared() < 0.0001:
		_heading = orbit_up.cross(Vector3.RIGHT)
	_heading = _heading.normalized()

	var altitude: float = maxf(horizon, 0.0)
	var lift: float = base_lift + _planet.radius * 0.11
	lift += clampf(altitude * 0.55, 0.0, 30.0)
	var distance: float = base_distance + _planet.radius * 0.19
	distance += clampf(altitude * 0.35, 0.0, 22.0)
	lift += _intro * 5.0
	distance += _intro * 9.0
	lift /= _focus
	distance /= _focus

	var view_forward: Vector3 = _heading.rotated(orbit_up, _view_yaw)
	var desired: Vector3 = _orbit + orbit_up * lift - view_forward * distance
	_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-9.0 * delta))
	if _shake > 0.001:
		var offset := Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		)
		_camera.global_position += offset * _shake

	var sway: Vector3 = orbit_up * (sin(_time * 0.45) * 0.06)
	var look_target: Vector3 = _orbit + orbit_up * 0.55 + view_forward * 1.1 + sway
	_camera.look_at(look_target, orbit_up)
	_camera.fov = lerpf(
		_camera.fov, 52.0 + clampf(altitude * 0.20, 0.0, 10.0), 1.0 - exp(-2.0 * delta)
	)


func _snap() -> void:
	if _target == null or _planet == null:
		return
	var target_position: Vector3 = _target.global_position
	var up: Vector3 = (target_position - _planet.get_center()).normalized()
	var lift: float = base_lift + _planet.radius * 0.11
	var distance: float = base_distance + _planet.radius * 0.19
	_camera.global_position = target_position + up * lift - _heading * distance
	_camera.look_at(target_position + up * 0.55 + _heading * 1.1, up)
