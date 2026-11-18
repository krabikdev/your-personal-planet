class_name DebrisManager
extends Node3D

## Schedules the slow parade of space junk. Every flyby happens over a random
## side of the planet, not over the boy. The catch is automatic: when the boy's
## net reaches the junk, it is scooped up without pressing anything. The first
## warning is a one-time tutorial: after that the player has to watch the sky
## without HUD hints.

signal warning_started(kind: int, size_factor: float)
signal warning_cleared
signal catch_window_changed(available: bool)
signal caught(kind: int, size_factor: float, shape_seed: int)
signal missed

enum Phase { IDLE, WARNING, FLYING, CAUGHT }

const WARNING_TIME: float = 10.0
const PREVIEW_GROW_TIME: float = 14.0
const PREVIEW_SCALE: float = 0.08
const PREVIEW_ALPHA: float = 0.75
const HALF_LENGTH: float = 24.0
const FLIGHT_ALTITUDE: float = 1.85
const APPROACH_LIFT: float = 7.0
const SPAWN_FADE_TIME: float = 1.8
const MIN_SIZE: float = 0.5
const MAX_SIZE: float = 1.5
const FAR_ALTITUDE_FRACTION: float = 0.9
const CATCH_PROMPT_DISTANCE: float = 3.0
const NET_CATCH_RADIUS: float = 1.1

var planet: Planet
var player: Boy

var _phase: Phase = Phase.IDLE
var _countdown: float = 40.0
var _warning_timer: float = 0.0
var _along: float = 0.0
var _speed: float = 9.0
var _kind: int = StoneItem.Kind.ROCK
var _size: float = 1.0
var _shape_seed: int = 0
var _target_dir: Vector3 = Vector3.UP
var _tangent: Vector3 = Vector3.FORWARD
var _axis: Vector3 = Vector3.RIGHT
var _debris: Node3D
var _trail: GPUParticles3D
var _spin_axis: Vector3 = Vector3.UP
var _spin_speed: float = 1.0
var _can_catch: bool = false
var _hint_shown: bool = false
var _glow_texture: GradientTexture2D
var _flight_altitude: float = FLIGHT_ALTITUDE
var _appear: float = 0.0
var _growth: float = 0.0
var _forced_size: float = 0.0
var _mesh_material: StandardMaterial3D
var _base_alpha: float = 1.0
var _glow: Sprite3D
var _glow_alpha: float = 0.42
var _light: OmniLight3D
var _light_energy: float = 0.0


func _ready() -> void:
	_countdown = randf_range(5.0, 10.0)
	_glow_texture = _make_glow_texture()


func setup(p_planet: Planet, p_player: Boy) -> void:
	planet = p_planet
	player = p_player


func _process(delta: float) -> void:
	if planet == null or player == null:
		return
	match _phase:
		Phase.IDLE:
			_countdown -= delta
			if _countdown <= 0.0:
				_begin_event()
		Phase.WARNING:
			_warning_timer -= delta
			_update_preview(delta)
			if _warning_timer <= 0.0:
				_launch_debris()
		Phase.FLYING:
			_update_flight(delta)
		Phase.CAUGHT:
			pass


func force_spawn(size_override: float = 0.0) -> void:
	if _phase == Phase.IDLE:
		_forced_size = size_override
		_begin_event()


func get_countdown() -> float:
	return _countdown


func is_active() -> bool:
	return _phase != Phase.IDLE


func get_catch_available() -> bool:
	return _can_catch


func debug_closest_point() -> Vector3:
	return _surface_point(0.0)


func _catch_with_net() -> void:
	if _phase != Phase.FLYING:
		return
	_phase = Phase.CAUGHT
	_set_catch_available(false)
	caught.emit(_kind, _size, _shape_seed)
	AudioDirector.play_sfx("catch", 0.03, 1.0)
	if _debris != null:
		var tween := create_tween()
		tween.tween_property(_debris, "scale", Vector3.ONE * 0.05, 0.18)
		tween.tween_callback(_finish_caught)
	else:
		_finish_caught()


func _begin_event() -> void:
	_kind = StoneItem.Kind.ICE if randf() < 0.2 else StoneItem.Kind.ROCK
	_size = _forced_size if _forced_size > 0.0 else randf_range(0.5, 1.5)
	_forced_size = 0.0
	_shape_seed = randi()
	_target_dir = _random_flyby_direction()
	var random_tangent := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	)
	random_tangent -= _target_dir * random_tangent.dot(_target_dir)
	if random_tangent.length_squared() < 0.01:
		random_tangent = _target_dir.cross(Vector3.RIGHT)
	_tangent = random_tangent.normalized()
	_axis = _target_dir.cross(_tangent).normalized()
	_tangent = _axis.cross(_target_dir).normalized()
	_along = -HALF_LENGTH
	# Slow drift: the catch has to be read from the debris itself, since there
	# is no marker on the ground any more.
	_speed = randf_range(2.8, 4.2)
	_flight_altitude = _altitude_for_size(_size)
	_appear = 0.0
	_growth = 0.0
	_phase = Phase.WARNING
	_warning_timer = WARNING_TIME
	_build_debris()
	if _trail != null:
		_trail.emitting = false
	_apply_visuals()
	if not _hint_shown:
		_hint_shown = true
		warning_started.emit(_kind, _size)
		AudioDirector.play_sfx("ping", 0.0, -4.0)


func _random_flyby_direction() -> Vector3:
	# A random side of the planet, never right above the boy.
	var player_up: Vector3 = player.get_up()
	var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if direction.length_squared() < 0.01:
		direction = Vector3.UP
	direction = direction.normalized()
	if direction.angle_to(player_up) < 0.7:
		var away_axis: Vector3 = player_up.cross(direction)
		if away_axis.length_squared() < 0.01:
			away_axis = player_up.cross(Vector3.RIGHT)
		away_axis = away_axis.normalized()
		direction = player_up.rotated(away_axis, 0.7 + randf_range(0.0, 1.2))
	return direction.normalized()


func _launch_debris() -> void:
	# The dot has been growing in the sky for ten seconds; now it starts moving.
	_phase = Phase.FLYING


func _update_preview(delta: float) -> void:
	_growth = minf(1.0, _growth + delta / PREVIEW_GROW_TIME)
	_appear = minf(PREVIEW_ALPHA, _appear + delta / 1.2)
	if _debris != null:
		_debris.global_position = _surface_point(_along)
	if _trail != null:
		_trail.global_position = _surface_point(_along)
		_trail.emitting = false
	_apply_visuals()


func _apply_visuals() -> void:
	if _debris != null:
		_debris.scale = Vector3.ONE * lerpf(PREVIEW_SCALE, 1.0, _growth)
	if _mesh_material != null:
		var color: Color = _mesh_material.albedo_color
		color.a = _base_alpha * _appear
		_mesh_material.albedo_color = color
	if _glow != null:
		_glow.modulate.a = _glow_alpha * _appear
	if _light != null:
		_light.light_energy = _light_energy * _appear


func _altitude_for_size(size_factor: float) -> float:
	# Small junk skims the ground; big junk drifts high, just inside the cold.
	var t: float = clampf((size_factor - MIN_SIZE) / (MAX_SIZE - MIN_SIZE), 0.0, 1.0)
	var far_altitude: float = PlanetProfile.death_altitude(planet.radius) * FAR_ALTITUDE_FRACTION
	return lerpf(FLIGHT_ALTITUDE, far_altitude, t)


func _update_flight(delta: float) -> void:
	_along += _speed * delta
	_appear = minf(1.0, _appear + delta / SPAWN_FADE_TIME)
	_growth = minf(1.0, _growth + delta / PREVIEW_GROW_TIME)
	if _debris != null:
		_debris.global_position = _surface_point(_along)
		_debris.rotate_object_local(_spin_axis, _spin_speed * delta)
	_apply_visuals()
	if _trail != null:
		_trail.global_position = _surface_point(_along)
		_trail.emitting = _appear > 0.3

	var near_boy: bool = _player_debris_distance() < CATCH_PROMPT_DISTANCE
	_set_catch_available(near_boy)

	if _try_catch():
		return

	if _along > HALF_LENGTH:
		_finish_missed()


func _try_catch() -> bool:
	if _phase != Phase.FLYING or _debris == null or player == null:
		return false
	var net_point: Vector3 = player.get_net_catch_point()
	if _debris.global_position.distance_to(net_point) > NET_CATCH_RADIUS:
		return false
	# The catch is automatic: the net only has to reach the junk.
	player.swing_net()
	_catch_with_net()
	return true


func _surface_point(along: float) -> Vector3:
	var base_radius: float = planet.radius + _flight_altitude
	# The junk drifts in from deeper space and only settles into its arc near
	# the planet, so it never pops into existence right next to the boy.
	var approach: float = smoothstep(HALF_LENGTH * 0.3, HALF_LENGTH, absf(along))
	var radius: float = base_radius + APPROACH_LIFT * approach
	var angle: float = along / maxf(base_radius, 1.0)
	return planet.get_center() + _target_dir.rotated(_axis, angle) * radius


func _player_debris_distance() -> float:
	if _debris != null:
		return player.global_position.distance_to(_debris.global_position)
	return player.global_position.distance_to(_surface_point(_along))


func _set_catch_available(value: bool) -> void:
	if value == _can_catch:
		return
	_can_catch = value
	catch_window_changed.emit(value)


func _build_debris() -> void:
	_mesh_material = null
	_glow = null
	_light = null
	_debris = Node3D.new()
	_debris.name = "Debris"
	add_child(_debris)
	_debris.global_position = _surface_point(_along)

	var mesh := MeshInstance3D.new()
	if _kind == StoneItem.Kind.ICE:
		mesh.mesh = RockMeshBuilder.create_crystal(_shape_seed)
		var ice := StandardMaterial3D.new()
		ice.albedo_color = Color(0.72, 0.91, 0.94, 0.88)
		ice.roughness = 0.12
		ice.metallic = 0.15
		ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice.emission_enabled = true
		ice.emission = Color(0.42, 0.78, 0.88)
		ice.emission_energy_multiplier = 0.55
		ice.vertex_color_use_as_albedo = true
		mesh.material_override = ice
		_mesh_material = ice
		_base_alpha = 0.88
		_glow_alpha = 0.50
		_light_energy = 0.9
	else:
		mesh.mesh = RockMeshBuilder.create_rock(_shape_seed, 1, 0.42)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color("8f7a73").lerp(Color("c09a83"), randf_range(0.0, 0.7))
		stone.roughness = 0.95
		stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stone.vertex_color_use_as_albedo = true
		mesh.material_override = stone
		_mesh_material = stone
		_base_alpha = 1.0
		_glow_alpha = 0.42
		_light_energy = 0.0
	var fading: Color = _mesh_material.albedo_color
	fading.a = 0.0
	_mesh_material.albedo_color = fading
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var visual_scale: float = _size * 0.5
	if _kind == StoneItem.Kind.ICE:
		mesh.scale = Vector3(visual_scale * 0.75, visual_scale, visual_scale * 0.75)
	else:
		mesh.scale = Vector3(
			visual_scale * randf_range(0.8, 1.2),
			visual_scale * randf_range(0.65, 1.0),
			visual_scale * randf_range(0.8, 1.2)
		)
	_debris.add_child(mesh)

	var glow := Sprite3D.new()
	glow.texture = _glow_texture
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.transparent = true
	glow.pixel_size = 0.01
	glow.render_priority = -1
	glow.modulate = Color(0.95, 0.66, 0.55, 0.0)
	if _kind == StoneItem.Kind.ICE:
		glow.modulate = Color(0.55, 0.90, 0.92, 0.0)
	glow.scale = Vector3(2.4 * _size, 2.4 * _size, 1.0)
	glow.position = Vector3.ZERO
	_debris.add_child(glow)
	_glow = glow

	if _kind == StoneItem.Kind.ICE:
		var light := OmniLight3D.new()
		light.light_color = Color(0.55, 0.86, 0.92)
		light.light_energy = 0.0
		light.omni_range = 4.5
		light.shadow_enabled = false
		_debris.add_child(light)
		_light = light

	_spin_axis = (
		Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	)
	_spin_speed = randf_range(0.7, 1.8)
	_trail = _build_trail()


func _build_trail() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 1.25
	particles.local_coords = false
	particles.emitting = true
	particles.position = _surface_point(_along)
	particles.draw_pass_1 = _make_trail_quad()
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = -_tangent
	pmat.spread = 32.0
	pmat.initial_velocity_min = 0.15
	pmat.initial_velocity_max = 0.75
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.25
	pmat.scale_max = 0.85
	var tint: Color = (
		Color(0.55, 0.85, 0.90, 0.55)
		if _kind == StoneItem.Kind.ICE
		else Color(0.85, 0.65, 0.52, 0.45)
	)
	pmat.color = tint
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.add_point(0.2, tint)
	ramp.add_point(0.6, Color(tint.r, tint.g, tint.b, tint.a * 0.35))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	pmat.color_ramp = ramp_texture
	particles.process_material = pmat
	add_child(particles)
	return particles


func _make_trail_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _glow_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = material
	return quad


func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _finish_missed() -> void:
	missed.emit()
	_clear_event()


func _finish_caught() -> void:
	_clear_event()


func _clear_event() -> void:
	_set_catch_available(false)
	if _debris != null:
		_debris.queue_free()
		_debris = null
	_mesh_material = null
	_glow = null
	_light = null
	_appear = 0.0
	_growth = 0.0
	if _trail != null:
		_trail.emitting = false
		_trail.queue_free()
		_trail = null
	warning_cleared.emit()
	_phase = Phase.IDLE
	_countdown = randf_range(5.0, 10.0)
