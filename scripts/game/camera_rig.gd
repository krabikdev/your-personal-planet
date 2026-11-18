class_name CameraRig
extends Node3D

## A chase camera that keeps the planet's local "up" as its up vector. The
## heading is parallel transported as the boy walks around the sphere, so the
## view rolls smoothly with him and never flips at the poles.

@export var base_lift: float = 3.0
@export var base_distance: float = 3.4
@export var mouse_sensitivity: float = 0.0025
@export var sky_head_height: float = 1.72
@export var sky_blend_speed: float = 6.0

var _target: Node3D
var _planet: Planet
var _orbit: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.FORWARD
var _view_yaw: float = 0.0
var _shake: float = 0.0
var _intro: float = 1.0
var _time: float = 0.0
var _focus: float = 1.0
var _altitude: float = 0.0
var _target_focus: float = 1.0
var _sky: bool = false
var _sky_blend: float = 0.0
var _sky_yaw: float = 0.0
var _sky_pitch: float = PI * 0.5

@onready var _camera: Camera3D = %Camera


func setup(target: Node3D, planet: Planet) -> void:
	_target = target
	_planet = planet
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _camera != null:
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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


## Holding Q lifts the camera to the duke's head and aims it straight up, so
## only space is visible. The mouse then looks around freely from there.
func set_sky_view(value: bool) -> void:
	if value == _sky:
		return
	_sky = value
	if value:
		_sky_yaw = _view_yaw
		_sky_pitch = PI * 0.5


func is_sky_view() -> bool:
	return _sky


func get_sky_pitch() -> float:
	return _sky_pitch


func get_sky_yaw() -> float:
	return _sky_yaw


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
		var motion := event as InputEventMouseMotion
		if _sky:
			_sky_yaw = wrapf(_sky_yaw - motion.relative.x * mouse_sensitivity, -PI, PI)
			_sky_pitch = clampf(
				_sky_pitch - motion.relative.y * mouse_sensitivity, -PI * 0.5, PI * 0.5
			)
		else:
			orbit_by(motion.relative.x)


func _process(delta: float) -> void:
	if _target == null or _planet == null:
		return
	_time += delta
	_intro = move_toward(_intro, 0.0, delta * 0.55)
	_shake = move_toward(_shake, 0.0, delta * 2.2)
	_focus = lerpf(_focus, _target_focus, 1.0 - exp(-3.5 * delta))
	_sky_blend = move_toward(_sky_blend, 1.0 if _sky else 0.0, delta * sky_blend_speed)

	var target_position: Vector3 = _target.get_global_transform_interpolated().origin
	var horizon: float = (target_position - _planet.get_center()).length() - _planet.radius
	_orbit = _orbit.lerp(target_position, 1.0 - exp(-18.0 * delta))
	var orbit_up: Vector3 = (_orbit - _planet.get_center()).normalized()

	_heading = _heading - orbit_up * _heading.dot(orbit_up)
	if _heading.length_squared() < 0.0001:
		_heading = orbit_up.cross(Vector3.RIGHT)
	_heading = _heading.normalized()

	var altitude: float = maxf(horizon, 0.0)
	_altitude = lerpf(_altitude, altitude, 1.0 - exp(-2.5 * delta))
	var lift: float = base_lift + _planet.radius * 0.11
	lift += clampf(_altitude * 0.55, 0.0, 30.0)
	var distance: float = base_distance + _planet.radius * 0.19
	distance += clampf(_altitude * 0.35, 0.0, 22.0)
	lift += _intro * 5.0
	distance += _intro * 9.0
	lift /= _focus
	distance /= _focus

	var view_forward: Vector3 = _heading.rotated(orbit_up, _view_yaw)
	var desired: Vector3 = _orbit + orbit_up * lift - view_forward * distance
	_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-20.0 * delta))
	if _shake > 0.001:
		var offset := Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		)
		_camera.global_position += offset * _shake

	var look_target: Vector3 = _orbit + orbit_up * 0.55 + view_forward * 1.1
	var up_hint: Vector3 = orbit_up
	if _sky_blend > 0.0001:
		var frame_forward: Vector3 = _heading.rotated(orbit_up, _sky_yaw)
		var sky_forward: Vector3 = (
			(frame_forward * cos(_sky_pitch) + orbit_up * sin(_sky_pitch)).normalized()
		)
		var head: Vector3 = _orbit + orbit_up * sky_head_height
		_camera.global_position = _camera.global_position.lerp(head, _sky_blend)
		look_target = look_target.lerp(head + sky_forward * 3.0, _sky_blend)
		var steep: float = clampf((absf(_sky_pitch) - 1.3) / 0.25, 0.0, 1.0)
		up_hint = orbit_up.lerp(frame_forward, steep * _sky_blend).normalized()

	_camera.look_at(look_target, up_hint)
	_camera.fov = lerpf(
		_camera.fov, 52.0 + clampf(_altitude * 0.20, 0.0, 10.0), 1.0 - exp(-2.0 * delta)
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
