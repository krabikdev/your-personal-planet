class_name Boy  # gdlint:ignore=max-public-methods
extends CharacterBody3D

## Spherical-gravity character controller. The boy walks on the outside of the
## planet, so "up" is recomputed from the planet centre every physics tick.

signal froze
signal cold_changed(amount: float)
signal jumped
signal landed(strength: float)

const ROPE_BOUNCE: float = 0.55
const ROPE_BRAKE_BOUNCE: float = 0.45
const ROPE_CRAWL_SPEED: float = 4.05

@export var walk_speed: float = 3.3
@export var run_multiplier: float = 1.8
@export var turn_speed: float = 9.0
@export var ground_acceleration: float = 26.0
@export var air_acceleration: float = 8.0
@export var rope_air_speed: float = 6.5
@export var rope_air_acceleration: float = 30.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.14
@export var cold_seconds: float = 4.0
@export var catch_hint_height: float = 1.75

var planet: Planet
var camera_rig: Node3D
var rope: RopeAnchor
var locked: bool = false
var smearing: bool = false
var dead: bool = false

var _facing: Vector3 = Vector3.BACK
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_grounded: bool = true
var _fall_speed: float = 0.0
var _cold: float = 0.0
var _running: bool = false
var _rope_crawl: bool = false
var _rope_brake_latch: bool = false
var _rope_recoil: float = 0.0
var _winch_active: bool = false
var _hint_time: float = 0.0
var _streams: Dictionary[String, AudioStream] = {}

@onready var _model: PrinceModel = %Visual
@onready var _audio: AudioStreamPlayer3D = %Audio
@onready var _winch: AudioStreamPlayer3D = %Winch
@onready var _catch_hint: Node3D = %CatchHint


func _ready() -> void:
	floor_snap_length = 0.55
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(80.0)
	jumped.connect(_model.play_jump)
	_model.footstepped.connect(_on_footstepped)
	for key: String in [
		"footstep_1", "footstep_2", "jump", "land", "whoosh", "stake_plant", "stake_pull"
	]:
		var stream: AudioStream = load("res://assets/audio/%s.wav" % key) as AudioStream
		if stream != null:
			_streams[key] = stream
	_setup_winch()


func _setup_winch() -> void:
	if _winch == null:
		return
	var stream: AudioStreamWAV = load("res://assets/audio/winch.wav") as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_winch.stream = stream


func is_winching() -> bool:
	return _winch_active


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


func set_rope(value: RopeAnchor) -> void:
	rope = value


func plant_stake() -> void:
	if dead or locked or planet == null or rope == null:
		return
	if get_altitude() > 0.6:
		return
	_model.play_hammer_swing()
	# Match the sound to the moment the mallet actually bites the soil.
	var impact := create_tween()
	impact.tween_interval(0.16)
	impact.tween_callback(_play_stake_plant)
	var up: Vector3 = get_up()
	var right: Vector3 = _facing.cross(up).normalized()
	var spot: Vector3 = _facing * 0.75 + right * 0.55
	rope.plant(global_position + spot.normalized() * 0.95)


func remove_stake() -> void:
	if dead or locked or rope == null or not rope.is_planted():
		return
	_rope_crawl = false
	_rope_recoil = 0.0
	_rope_brake_latch = false
	_set_winch_playing(false)
	rope.clear()
	_play("stake_pull", -3.0, 0.08)


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
	_set_winch_playing(false)
	_model.set_smearing(true)


func finish_smearing() -> void:
	smearing = false
	locked = false
	_model.set_smearing(false)


func end_smearing_pose() -> void:
	smearing = false
	_model.set_smearing(false)


func release_control() -> void:
	locked = false


func freeze() -> void:
	if dead:
		return
	dead = true
	locked = true
	set_catch_hint(false)
	_set_winch_playing(false)
	_model.set_sitting(false)
	_model.set_smearing(false)
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


func burst_dust() -> void:
	_model.play_land_dust()


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
		_set_winch_playing(false)
		return

	var grounded_before: bool = is_on_floor()
	if not locked:
		if _rope_air_active():
			_handle_rope_air(up, delta)
		else:
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
	_apply_rope_limit()

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

	_update_cold(delta)
	_model.set_motion(get_speed_ratio(), grounded_now, _running, velocity.length(), velocity)
	_update_winch()


func _update_winch() -> void:
	var reeling: bool = (
		_rope_crawl
		and not locked
		and not dead
		and _rope_recoil <= 0.0
		and not is_on_floor()
		and rope != null
		and rope.is_planted()
	)
	_set_winch_playing(reeling)


func _set_winch_playing(value: bool) -> void:
	if value == _winch_active:
		return
	_winch_active = value
	if _winch == null:
		return
	if value:
		_winch.volume_db = -9.0 + linear_to_db(clampf(AudioDirector.sfx_volume, 0.001, 1.0))
		_winch.play()
	else:
		_winch.stop()


func _rope_air_active() -> bool:
	if rope == null or not rope.is_planted():
		return false
	if is_on_floor():
		_rope_crawl = false
		return false
	if not Input.is_action_pressed("jump"):
		_rope_crawl = false
		_rope_brake_latch = false
		return false
	if _rope_crawl:
		return true
	if _rope_brake_latch:
		return false
	# A fresh press in the air: stop dead and recoil, then start reeling in.
	_rope_crawl = true
	var speed: float = velocity.length()
	velocity = -velocity * ROPE_BRAKE_BOUNCE
	_rope_recoil = clampf(0.14 + speed * 0.02, 0.14, 0.4)
	if speed > 0.6:
		rope.notify_snap(speed)
	return true


func _handle_rope_air(up: Vector3, delta: float) -> void:
	if _rope_recoil > 0.0:
		_rope_recoil -= delta
		_apply_gravity(up, delta)
		return
	if rope == null:
		return
	var to_stake: Vector3 = rope.get_anchor_position() - global_position
	if to_stake.length_squared() > 0.0001:
		velocity = to_stake.normalized() * ROPE_CRAWL_SPEED


func _apply_rope_limit() -> void:
	if rope == null or not rope.is_planted():
		return
	var anchor: Vector3 = rope.get_anchor_position()
	var offset: Vector3 = global_position - anchor
	var distance: float = offset.length()
	var limit: float = rope.get_max_length()
	if limit <= 0.1 or distance <= limit or distance < 0.001:
		return
	var direction: Vector3 = offset / distance
	global_position = anchor + direction * limit
	var outward_speed: float = velocity.dot(direction)
	if outward_speed > 0.0:
		velocity -= direction * outward_speed * (1.0 + ROPE_BOUNCE)
		if outward_speed > 0.8:
			rope.notify_snap(outward_speed)


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
		if rope != null and rope.is_planted():
			# Keep the launching press from instantly reeling the rope in.
			_rope_brake_latch = true
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
	# Hanging from a planted stake turns the air into a fast, responsive glide.
	var tethered_air: bool = rope != null and rope.is_planted() and not is_on_floor()
	var target_speed: float = walk_speed * (run_multiplier if _running else 1.0)
	if tethered_air:
		target_speed = rope_air_speed * (run_multiplier if _running else 1.0)
	if input.length_squared() > 0.01:
		desired = (right * input.x - forward * input.y).normalized() * target_speed
		_turn_toward(desired.normalized(), up, delta)
	var tangent: Vector3 = velocity - up * velocity.dot(up)
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	if tethered_air:
		accel = rope_air_acceleration
	tangent = tangent.move_toward(desired, accel * delta)
	var radial: float = velocity.dot(up)
	velocity = tangent + up * radial


func _turn_toward(wanted: Vector3, up: Vector3, delta: float) -> void:
	var target: Vector3 = wanted - up * wanted.dot(up)
	if target.length_squared() < 0.0001:
		return
	target = target.normalized()
	var current: Vector3 = _facing - up * _facing.dot(up)
	if current.length_squared() < 0.0001:
		_facing = target
		return
	var angle: float = current.normalized().signed_angle_to(target, up)
	var step: float = turn_speed * delta
	if absf(angle) <= step:
		_facing = target
		return
	_facing = current.normalized().rotated(up, signf(angle) * step).normalized()


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


func _on_footstepped(side: int) -> void:
	if dead or locked:
		return
	_play("footstep_2" if side == 1 else "footstep_1", -9.0, 0.08)


func _update_cold(delta: float) -> void:
	if locked:
		return
	var previous: float = _cold
	if _rope_crawl:
		# Reeling himself along the rope keeps him warm enough to make it home.
		_cold = maxf(0.0, _cold - delta * 0.35)
	else:
		var altitude: float = get_altitude()
		var threshold: float = planet.cold_altitude()
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


func _play_stake_plant() -> void:
	if dead:
		return
	_play("stake_plant", -3.0, 0.06)


func _play(key: String, extra_db: float, pitch_jitter: float) -> void:
	if not _streams.has(key):
		return
	_audio.stream = _streams[key]
	_audio.volume_db = extra_db + linear_to_db(clampf(AudioDirector.sfx_volume, 0.001, 1.0))
	_audio.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	_audio.play()
