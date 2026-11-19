class_name Boy  # gdlint:ignore=max-public-methods
extends CharacterBody3D

## Spherical-gravity character controller. The boy walks on the outside of the
## planet, so "up" is recomputed from the planet centre every physics tick.

signal froze
signal cold_changed(amount: float)
signal jumped
signal landed(strength: float)
signal health_changed(current: float, maximum: float)

const ROPE_BOUNCE: float = 0.1
const ROPE_RECOIL_MAX: float = 1.2
const ROPE_CRAWL_SPEED: float = 4.05
const ROPE_REEL_ACCEL: float = 9.0
const ROPE_MAX_COLD: float = 0.9
const MAX_FALL_SPEED: float = 26.0
const FOOTSTEP_DB: float = -9.0
## The watering loop is meant to sit under everything else: it is a trickle, not
## an event.
const POUR_DB: float = -13.0
const FOOTSTEP_PITCH_MIN: float = 0.05
const FOOTSTEP_PITCH_MAX: float = 0.10
const GROUND_STICK: float = 0.12
## Jumping stays possible this close above the ground even when the feet are
## not planted: stepping off a pebble should not eat the jump.
const JUMP_GROUND_ALLOWANCE: float = 0.18
const ROPE_STEER_PULL: float = 0.45
const ROPE_ARRIVE: float = 1.2
const ROPE_HANG_FADE: float = 2.0
const ROPE_HANG_FLOOR: float = 0.4
## Jumping is a charge: hold Space on the ground and the jump grows for two
## seconds, then fires by itself at the full height.
const JUMP_CHARGE_TIME: float = 2.0
## A tap still leaves the ground, with this share of the full jump height.
const JUMP_MIN_HEIGHT_FRACTION: float = 0.15
## How far in front of his feet the watering can reaches.
const WATER_REACH: float = 1.05
const MAX_HEALTH: float = 100.0
## One point of health comes back every ten seconds of ordinary time.
const HEALTH_REGEN_INTERVAL: float = 10.0
const HEALTH_REGEN_AMOUNT: float = 1.0

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

var planet: Planet
var camera_rig: Node3D
var rope: RopeAnchor
var locked: bool = false
var smearing: bool = false
var dead: bool = false
var watering: bool = false
var health: float = MAX_HEALTH

var _facing: Vector3 = Vector3.BACK
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_grounded: bool = true
var _fall_speed: float = 0.0
var _cold: float = 0.0
var _running: bool = false
var _rope_crawl: bool = false
var _rope_brake_latch: bool = false
var _rope_done: bool = false
var _winch_active: bool = false
var _regen_clock: float = 0.0
var _charging: bool = false
var _jump_charge: float = 0.0
var _streams: Dictionary[String, AudioStream] = {}

@onready var _model: PrinceModel = %Visual
@onready var _audio: AudioStreamPlayer3D = %Audio
@onready var _winch: AudioStreamPlayer3D = %Winch
@onready var _pour: AudioStreamPlayer3D = %Pour


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
	_setup_pour()


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


## The watering can trickles while the button is held. The loop is quiet and
## follows the player, so it reads as water falling next to him.
func _setup_pour() -> void:
	if _pour == null:
		return
	var stream: AudioStreamWAV = load("res://assets/audio/water_pour.wav") as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_pour.stream = stream


func is_winching() -> bool:
	return _winch_active


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


func can_remove_stake() -> bool:
	return rope != null and rope.is_planted() and get_altitude() <= 0.6


func remove_stake() -> void:
	if dead or locked or not can_remove_stake():
		return
	_rope_crawl = false
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


func get_health() -> float:
	return health


func get_max_health() -> float:
	return MAX_HEALTH


## The jump is charged on the ground: 0..2 seconds of holding Space.
func is_charging() -> bool:
	return _charging


func get_jump_charge() -> float:
	return _jump_charge


## Monsters bite; acid does not. Zero health ends the run the same way cold
## does: the boy freezes where he stands.
func take_damage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_regen_clock = 0.0
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		freeze()


func debug_set_health(value: float) -> void:
	health = clampf(value, 0.0, MAX_HEALTH)
	_regen_clock = 0.0
	health_changed.emit(health, MAX_HEALTH)


## Steps the regeneration clock without waiting ten real seconds per point.
func debug_tick_health(seconds: float) -> void:
	var steps: int = maxi(1, ceili(seconds / 0.5))
	var step: float = seconds / float(steps)
	for _i: int in steps:
		_update_health(step)


func get_speed_ratio() -> float:
	return velocity.length() / maxf(walk_speed, 0.01)


func start_smearing() -> void:
	set_watering(false)
	_cancel_charge()
	locked = true
	smearing = true
	velocity = Vector3.ZERO
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
	set_watering(false)
	_cancel_charge()
	dead = true
	locked = true
	_set_winch_playing(false)
	_model.set_sitting(false)
	_model.set_smearing(false)
	velocity = Vector3.ZERO
	froze.emit()


func debug_set_cold(amount: float) -> void:
	var value: float = clampf(amount, 0.0, 1.0)
	if is_equal_approx(value, _cold):
		return
	_cold = value
	cold_changed.emit(_cold)
	if _cold >= 1.0:
		freeze()


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


## True while the can is out and pouring. The model shows the can in his hand.
func set_watering(active: bool) -> void:
	var wanted: bool = active and not dead and not locked
	if wanted == watering:
		return
	watering = wanted
	_model.set_watering(wanted)
	_update_pour_loop()


func is_watering() -> bool:
	return watering


func is_pour_loop_playing() -> bool:
	return _pour != null and _pour.playing


func _update_pour_loop() -> void:
	if _pour == null or _pour.stream == null:
		return
	if watering and not dead and not locked:
		_pour.volume_db = POUR_DB + linear_to_db(clampf(AudioDirector.sfx_volume, 0.001, 1.0))
		if not _pour.playing:
			_pour.play()
	elif _pour.playing:
		_pour.stop()


## The patch of ground directly in front of his feet that the can waters.
func get_water_target() -> Vector3:
	var forward: Vector3 = _facing
	if forward.length_squared() < 0.01:
		forward = -global_transform.basis.z
	var spot: Vector3 = global_position + forward.normalized() * WATER_REACH
	if planet == null:
		return spot
	var up: Vector3 = (spot - planet.get_center()).normalized()
	return planet.get_center() + up * (planet.radius + 0.02)


func burst_dust() -> void:
	_model.play_land_dust()


func swing_net(with_sound: bool = true) -> void:
	if dead or locked:
		return
	_model.play_net_swing()
	if with_sound:
		_play("whoosh", -13.0, 0.12)


func is_net_active() -> bool:
	return _model.is_net_active()


func get_hand_position() -> Vector3:
	return _model.get_hand_position()


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
			_handle_rope_air(delta)
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
	_apply_rope_limit()
	move_and_slide()

	var after_up: Vector3 = get_up()
	_update_basis(after_up)
	_keep_above_surface(after_up)
	_apply_rope_limit()

	var grounded_now: bool = is_on_floor()
	if not grounded_now and _was_grounded and velocity.dot(after_up) < 1.0:
		# Walking over a sphere loses the floor for a frame now and then. Treat
		# that as standing still, or the gait would snap on and off every step.
		grounded_now = get_altitude() < GROUND_STICK
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
	_update_health(delta)
	_model.set_motion(get_speed_ratio(), grounded_now, _running, velocity.length(), velocity)
	_model.set_charging(_jump_charge / JUMP_CHARGE_TIME if _charging else 0.0)
	var hanging: bool = rope != null and rope.is_planted() and not grounded_now and _rope_crawl
	if hanging:
		var hang: float = clampf((get_altitude() - ROPE_HANG_FLOOR) / ROPE_HANG_FADE, 0.0, 1.0)
		_model.set_pull(rope.peek_reel_direction(), hang)
	else:
		_model.set_pull(Vector3.ZERO, 0.0)
	_update_winch()


func _update_winch() -> void:
	var reeling: bool = (
		_rope_crawl and not locked and not dead and rope != null and rope.is_planted()
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
	if not Input.is_action_pressed("jump"):
		_rope_crawl = false
		_rope_brake_latch = false
		_rope_done = false
		return false
	if _rope_done or (_rope_brake_latch and not _rope_crawl):
		if is_on_floor():
			_rope_brake_latch = false
			_rope_done = false
		return false
	if is_on_floor() and not _rope_crawl:
		# Standing on the ground with a fresh press is a jump, not a winch.
		# A crawl that is already going survives a graze of the floor instead
		# of resetting and braking the glide on every bump.
		_rope_brake_latch = false
		_rope_done = false
		return false
	# A fresh press in the air: the winch takes over from the next frame on.
	_rope_crawl = true
	return true


func _handle_rope_air(delta: float) -> void:
	if rope == null:
		return
	# The winch stops pulling once the boy is back at the stake: from there the
	# ground takes him, even with the key still held. Low altitude alone is not
	# an arrival: on a draped rope home can still be metres away along the ground.
	if global_position.distance_to(rope.get_anchor_position()) <= ROPE_ARRIVE:
		_rope_done = true
		_rope_crawl = false
		_apply_gravity(get_up(), delta)
		return
	var home: Vector3 = rope.get_reel_direction()
	if home.length_squared() < 0.0001:
		return
	var steer: Vector3 = _rope_steer(delta)
	if steer.length_squared() < 0.0001:
		_running = false
		# Space alone: no snap and no bounce, the winch eats the outward speed
		# bit by bit and then keeps winding the boy along the cord.
		var desired: Vector3 = home * ROPE_CRAWL_SPEED
		velocity = velocity.move_toward(desired, ROPE_REEL_ACCEL * delta)
		return
	# Space plus WASD: the winch keeps a weaker grip and the stick does the
	# steering, so the boy can swing around the stake on the way home.
	var pull: Vector3 = home * ROPE_CRAWL_SPEED * ROPE_STEER_PULL
	velocity = velocity.move_toward(pull + steer, rope_air_acceleration * delta)


func _rope_steer(delta: float) -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.01:
		return Vector3.ZERO
	var up: Vector3 = get_up()
	var forward: Vector3 = _facing
	if camera_rig != null and camera_rig.has_method("get_tangent_forward"):
		forward = camera_rig.get_tangent_forward(up)
	var right: Vector3 = forward.cross(up).normalized()
	var wanted: Vector3 = (right * input.x - forward * input.y).normalized()
	_turn_toward(wanted, up, delta)
	_running = Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT)
	return wanted * rope_air_speed * (run_multiplier if _running else 1.0)


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
		var recoil: float = minf(outward_speed * ROPE_BOUNCE, ROPE_RECOIL_MAX)
		velocity -= direction * (outward_speed + recoil)
		if outward_speed > 0.8:
			rope.notify_snap(outward_speed)


func _apply_gravity(up: Vector3, delta: float) -> void:
	var gravity: float = planet.gravity_at(global_position)
	velocity -= up * gravity * delta
	var falling: float = -velocity.dot(up)
	if falling > MAX_FALL_SPEED:
		velocity += up * (falling - MAX_FALL_SPEED)
	if is_on_floor():
		var radial: float = velocity.dot(up)
		if radial < 0.0:
			velocity -= up * radial


func _handle_jump(up: Vector3, grounded: bool) -> void:
	var delta: float = get_physics_process_delta_time()
	var near_ground: bool = grounded or get_altitude() < JUMP_GROUND_ALLOWANCE
	if near_ground:
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	var can_start: bool = near_ground or _coyote > 0.0

	if Input.is_action_just_pressed("jump"):
		if can_start:
			_charging = true
			_jump_charge = 0.0
		else:
			_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	if _charging:
		# Walking off a ledge mid-charge drops the charge instead of firing a
		# jump from mid air.
		if not near_ground and get_altitude() > JUMP_GROUND_ALLOWANCE * 6.0:
			_cancel_charge()
			return
		_jump_charge = minf(_jump_charge + delta, JUMP_CHARGE_TIME)
		if _jump_charge >= JUMP_CHARGE_TIME or Input.is_action_just_released("jump"):
			_launch_jump(up)
		return

	# A press a moment before touchdown: hop on landing, or keep charging if the
	# key is still held.
	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump_buffer = 0.0
		if Input.is_action_pressed("jump"):
			_charging = true
			_jump_charge = 0.0
		else:
			_launch_jump(up)


## Fires the jump with however much of the two-second charge was built up.
## A full charge reaches the jump height the planet profile advertises.
func _launch_jump(up: Vector3) -> void:
	var ratio: float = clampf(_jump_charge / JUMP_CHARGE_TIME, 0.0, 1.0)
	# Height, not speed, grows linearly with the hold: a tap is a small hop and
	# a full two-second charge reaches the height the HUD advertises.
	var height_ratio: float = lerpf(JUMP_MIN_HEIGHT_FRACTION, 1.0, ratio)
	var speed: float = planet.get_jump_speed() * sqrt(height_ratio)
	var tangent: Vector3 = velocity - up * velocity.dot(up)
	velocity = tangent + up * speed
	_charging = false
	_jump_charge = 0.0
	_jump_buffer = 0.0
	_coyote = 0.0
	_fall_speed = 0.0
	if rope != null and rope.is_planted():
		# Keep the launching press from instantly reeling the rope in.
		_rope_brake_latch = true
	_play("jump", -4.0, 0.08)
	jumped.emit()


func _cancel_charge() -> void:
	_charging = false
	_jump_charge = 0.0


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
	var key: String = "footstep_2" if side == 1 else "footstep_1"
	if not _streams.has(key):
		return
	_audio.stream = _streams[key]
	_audio.volume_db = FOOTSTEP_DB + linear_to_db(clampf(AudioDirector.sfx_volume, 0.001, 1.0))
	var wobble: float = randf_range(FOOTSTEP_PITCH_MIN, FOOTSTEP_PITCH_MAX)
	_audio.pitch_scale = 1.0 + wobble * (1.0 if randf() < 0.5 else -1.0)
	_audio.play()


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
	# A planted stake is a lifeline: while it holds, the cold can never finish him.
	if rope != null and rope.is_planted():
		_cold = minf(_cold, ROPE_MAX_COLD)
	if not is_equal_approx(previous, _cold):
		cold_changed.emit(_cold)
	if _cold >= 1.0:
		freeze()


## One point of health back every ten seconds, but only while still alive.
func _update_health(delta: float) -> void:
	if dead or health >= MAX_HEALTH:
		_regen_clock = 0.0
		return
	_regen_clock += delta
	while _regen_clock >= HEALTH_REGEN_INTERVAL:
		_regen_clock -= HEALTH_REGEN_INTERVAL
		health = minf(health + HEALTH_REGEN_AMOUNT, MAX_HEALTH)
		health_changed.emit(health, MAX_HEALTH)


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
