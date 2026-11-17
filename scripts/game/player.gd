class_name Boy
extends CharacterBody3D

## Spherical-gravity character controller. The boy walks on the outside of the
## planet, so "up" is recomputed from the planet centre every physics tick.

signal froze
signal cold_changed(amount: float)
signal jumped
signal landed(strength: float)

@export var walk_speed: float = 3.3
@export var run_multiplier: float = 1.8
@export var ground_acceleration: float = 26.0
@export var air_acceleration: float = 8.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.14
@export var cold_seconds: float = 4.0
@export var footstep_distance: float = 1.45
@export var catch_hint_height: float = 1.75

var planet: Planet
var camera_rig: Node3D
var locked: bool = false
var smearing: bool = false
var dead: bool = false

var _facing: Vector3 = Vector3.BACK
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_grounded: bool = true
var _fall_speed: float = 0.0
var _step_distance: float = 0.0
var _cold: float = 0.0
var _step_toggle: bool = false
var _running: bool = false
var _hint_time: float = 0.0
var _streams: Dictionary[String, AudioStream] = {}

@onready var _model: BoyModel = %Visual
@onready var _audio: AudioStreamPlayer3D = %Audio
@onready var _catch_hint: Node3D = %CatchHint


func _ready() -> void:
	floor_snap_length = 0.55
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(80.0)
	for key: String in ["footstep_1", "footstep_2", "jump", "land", "whoosh"]:
		var stream: AudioStream = load("res://assets/audio/%s.wav" % key) as AudioStream
		if stream != null:
			_streams[key] = stream


func _process(delta: float) -> void:
	if _catch_hint == null or not _catch_hint.visible:
		return
	_hint_time += delta
	_catch_hint.position.y = catch_hint_height + sin(_hint_time * 2.6) * 0.05
	var pulse: float = 1.0 + sin(_hint_time * 4.2) * 0.045
	_catch_hint.scale = Vector3.ONE * pulse


func set_catch_hint(value: bool) -> void:
	if _catch_hint == null or value == _catch_hint.visible:
		return
	_catch_hint.visible = value
	_hint_time = 0.0


func set_planet(value: Planet) -> void:
	planet = value


func set_camera_rig(value: Node3D) -> void:
	camera_rig = value


func snap_to_surface() -> void:
	if planet == null:
		return
	var up: Vector3 = (global_position - planet.get_center()).normalized()
	if up.length_squared() < 0.1:
		up = Vector3.UP
	global_position = planet.get_center() + up * (planet.radius + 0.02)
	_facing = (_facing - up * _facing.dot(up)).normalized()
	_update_basis(up)
	velocity = Vector3.ZERO


func get_up() -> Vector3:
	if planet == null:
		return Vector3.UP
	var up: Vector3 = global_position - planet.get_center()
	if up.length_squared() < 0.0001:
		return Vector3.UP
	return up.normalized()


func get_altitude() -> float:
	if planet == null:
		return 0.0
	return (global_position - planet.get_center()).length() - planet.radius


func get_cold() -> float:
	return _cold


func get_speed_ratio() -> float:
	return velocity.length() / maxf(walk_speed, 0.01)


func start_smearing() -> void:
	locked = true
	smearing = true
	velocity = Vector3.ZERO
	set_catch_hint(false)
	_model.set_sitting(true)


func finish_smearing() -> void:
	smearing = false
	locked = false
	_model.set_sitting(false)


func end_smearing_pose() -> void:
	smearing = false
	_model.set_sitting(false)


func release_control() -> void:
	locked = false


func freeze() -> void:
	if dead:
		return
	dead = true
	locked = true
	set_catch_hint(false)
	_model.set_sitting(false)
	velocity = Vector3.ZERO
	froze.emit()


func debug_jump() -> void:
	if planet == null or dead or locked:
		return
	var up: Vector3 = get_up()
	var tangent: Vector3 = velocity - up * velocity.dot(up)
	velocity = tangent + up * planet.get_jump_speed()
	_was_grounded = false
	_fall_speed = 0.0
	jumped.emit()


func play_catch_pose() -> void:
	_model.play_catch_pose()


func swing_net() -> void:
	if dead or locked:
		return
	_model.play_net_swing()
	_play("whoosh", -13.0, 0.12)


func is_net_active() -> bool:
	return _model.is_net_active()


func get_net_catch_point() -> Vector3:
	return _model.get_net_catch_point()


func _physics_process(delta: float) -> void:
	if planet == null:
		return
	var up: Vector3 = get_up()
	up_direction = up
	if dead:
		_update_basis(up)
		return

	var grounded_before: bool = is_on_floor()
	if not locked:
		_apply_gravity(up, delta)
		if not grounded_before:
			_fall_speed = maxf(_fall_speed, -velocity.dot(up))
		_handle_jump(up, grounded_before)
		_handle_movement(up, delta)
	else:
		var tangent: Vector3 = velocity - up * velocity.dot(up)
		tangent = tangent.move_toward(Vector3.ZERO, ground_acceleration * delta)
		var radial: float = velocity.dot(up)
		if is_on_floor() and radial < 0.0:
			radial = 0.0
		velocity = tangent + up * radial

	_update_basis(up)
	move_and_slide()

	var after_up: Vector3 = get_up()
	_update_basis(after_up)
	_keep_above_surface(after_up)

	var grounded_now: bool = is_on_floor()
	if grounded_now and not _was_grounded:
		if _fall_speed > 1.2:
			var strength: float = clampf(_fall_speed / 6.0, 0.25, 1.2)
			_model.play_land_squash(strength)
			_play("land", -2.0, 0.12)
			landed.emit(strength)
	if not grounded_now:
		_fall_speed = maxf(_fall_speed, -velocity.dot(after_up))
	else:
		_fall_speed = 0.0
	_was_grounded = grounded_now

	_update_footsteps(delta, grounded_now)
	_update_cold(delta)
	_model.set_motion(get_speed_ratio(), grounded_now, _running)


func _apply_gravity(up: Vector3, delta: float) -> void:
	var gravity: float = planet.gravity_at(global_position)
	velocity -= up * gravity * delta
	if is_on_floor():
		var radial: float = velocity.dot(up)
		if radial < 0.0:
			velocity -= up * radial


func _handle_jump(up: Vector3, grounded: bool) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - get_physics_process_delta_time(), 0.0)
	if grounded:
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - get_physics_process_delta_time(), 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		var tangent: Vector3 = velocity - up * velocity.dot(up)
		velocity = tangent + up * planet.get_jump_speed()
		_jump_buffer = 0.0
		_coyote = 0.0
		_fall_speed = 0.0
		_play("jump", -4.0, 0.08)
		jumped.emit()


func _handle_movement(up: Vector3, delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := _facing
	var right: Vector3 = _facing.cross(up).normalized()
	if camera_rig != null:
		if camera_rig.has_method("get_tangent_forward"):
			forward = camera_rig.get_tangent_forward(up)
		right = forward.cross(up).normalized()
	var desired := Vector3.ZERO
	_running = (
		(Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT))
		and input.length_squared() > 0.01
	)
	var target_speed: float = walk_speed * (run_multiplier if _running else 1.0)
	if input.length_squared() > 0.01:
		desired = (right * input.x - forward * input.y).normalized() * target_speed
		_facing = desired.normalized()
	var tangent: Vector3 = velocity - up * velocity.dot(up)
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	tangent = tangent.move_toward(desired, accel * delta)
	var radial: float = velocity.dot(up)
	velocity = tangent + up * radial


func _update_basis(up: Vector3) -> void:
	if _facing.length_squared() < 0.01:
		_facing = Vector3.FORWARD
	_facing = (_facing - up * _facing.dot(up))
	if _facing.length_squared() < 0.0001:
		_facing = up.cross(Vector3.RIGHT).normalized()
	_facing = _facing.normalized()
	var right: Vector3 = _facing.cross(up).normalized()
	global_transform.basis = Basis(right, up, -_facing).orthonormalized()


func _keep_above_surface(up: Vector3) -> void:
	var distance: float = (global_position - planet.get_center()).length()
	var minimum: float = planet.radius - 0.02
	if distance < minimum:
		global_position = planet.get_center() + up * (planet.radius + 0.01)
		if velocity.dot(up) < 0.0:
			velocity -= up * velocity.dot(up)


func _update_footsteps(delta: float, grounded: bool) -> void:
	if not grounded or locked:
		return
	var horizontal: float = (velocity - get_up() * velocity.dot(get_up())).length()
	if horizontal < 0.45:
		return
	_step_distance += horizontal * delta
	if _step_distance < footstep_distance:
		return
	_step_distance = 0.0
	_step_toggle = not _step_toggle
	_play("footstep_2" if _step_toggle else "footstep_1", -9.0, 0.08)


func _update_cold(delta: float) -> void:
	if locked:
		return
	var altitude: float = get_altitude()
	var threshold: float = planet.cold_altitude()
	var previous: float = _cold
	if altitude > threshold:
		_cold = minf(1.0, _cold + delta / cold_seconds)
	elif altitude < threshold * 0.55:
		_cold = maxf(0.0, _cold - delta * 0.85)
	if altitude > PlanetProfile.death_altitude(planet.radius):
		_cold = 1.0
	if not is_equal_approx(previous, _cold):
		_model.set_cold(_cold)
		cold_changed.emit(_cold)
	if _cold >= 1.0:
		freeze()


func _play(key: String, extra_db: float, pitch_jitter: float) -> void:
	if not _streams.has(key):
		return
	_audio.stream = _streams[key]
	_audio.volume_db = extra_db + linear_to_db(clampf(AudioDirector.sfx_volume, 0.001, 1.0))
	_audio.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	_audio.play()
