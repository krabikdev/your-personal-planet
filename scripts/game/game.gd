class_name Game
extends Node3D

## Sandbox orchestrator: wires the planet, boy, camera, debris and UI together,
## owns the inventory model and the cold/growth/death sequence.

enum State { PLAYING, INVENTORY, APPLYING, PAUSED, DEAD }

const SUN_DIRECTION := Vector3(-0.42, 0.58, 0.36)

var _model: InventoryModel = InventoryModel.new()
var _state: State = State.PLAYING
var _stones_used: int = 0
var _rope: RopeAnchor
var _frost_material: ShaderMaterial
var _was_safe_before_growth: bool = false
var _fade_tween: Tween
var _frost_tween: Tween

@onready var _planet: Planet = $Planet
@onready var _player: Boy = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _debris: DebrisManager = $DebrisManager
@onready var _skeleton: SkeletonProp = $Skeleton
@onready var _far_side: FarSideSpawner = $FarSideSpawner
@onready var _hud: GameHUD = $GameHud
@onready var _inventory_ui: InventoryUI = $Inventory
@onready var _game_over: GameOverUI = $GameOver
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _fill: DirectionalLight3D = $Fill
@onready var _headlight: DirectionalLight3D = $Headlight
@onready var _frost_rect: ColorRect = %FrostRect
@onready var _fade_rect: ColorRect = %FadeRect


func _ready() -> void:
	_setup_environment()
	_frost_material = _frost_rect.material as ShaderMaterial
	_set_frost_progress(0.0)
	_fade_rect.visible = true
	_fade_rect.color = Color(0.015, 0.015, 0.03, 1.0)

	_player.global_position = _planet.get_center() + Vector3.UP * (_planet.radius + 0.05)
	_player.set_planet(_planet)
	_player.set_camera_rig(_camera_rig)
	_player.snap_to_surface()
	_camera_rig.setup(_player, _planet)
	_camera_rig.play_intro()
	_debris.setup(_planet, _player)
	_rope = RopeAnchor.new()
	_rope.name = "RopeAnchor"
	add_child(_rope)
	_rope.setup(_planet, _player)
	_rope.planted.connect(_on_rope_planted)
	_rope.removed.connect(_on_rope_removed)
	_rope.snapped.connect(_on_rope_snapped)
	_player.set_rope(_rope)
	_skeleton.setup(_planet, _player)
	_skeleton.item_picked.connect(_on_skeleton_item_picked)
	_far_side.setup(_planet, _player)

	_player.cold_changed.connect(_on_cold_changed)
	_player.froze.connect(_on_froze)
	_player.landed.connect(_on_player_landed)
	_planet.growth_finished.connect(_on_growth_finished)
	_debris.caught.connect(_on_debris_caught)
	_hud.inventory_requested.connect(_toggle_inventory)
	_inventory_ui.use_requested.connect(_on_inventory_use)
	_inventory_ui.closed.connect(_on_inventory_closed)
	_game_over.restart_requested.connect(_on_restart)
	_game_over.menu_requested.connect(_on_main_menu)
	_pause_menu.resume_requested.connect(_on_pause_resume)
	_pause_menu.menu_requested.connect(_on_main_menu)

	_update_stats()
	_hud.set_inventory_count(0)
	_hud.fade_controls()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, 1.3)
	_fade_tween.tween_callback(func() -> void: _fade_rect.visible = false)


func _process(_delta: float) -> void:
	if _camera_rig.get_camera() == null:
		return
	_headlight.global_transform.basis = _camera_rig.get_camera().global_transform.basis
	_camera_rig.set_sky_view(_state == State.PLAYING and Input.is_action_pressed("sky_view"))


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.DEAD:
		return
	if event.is_action_pressed("interact") and _state == State.PLAYING:
		_player.swing_net()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("stake") and _state == State.PLAYING:
		if _rope.is_planted():
			_player.remove_stake()
		else:
			_player.plant_stake()
		get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("inventory")
		and (_state == State.PLAYING or _state == State.INVENTORY)
	):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and _state == State.PLAYING:
		_open_pause()
		get_viewport().set_input_as_handled()


func _setup_environment() -> void:
	var sun_dir: Vector3 = SUN_DIRECTION.normalized()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/space_sky.gdshader") as Shader
	sky_material.set_shader_parameter("sun_dir", sun_dir)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8c7384")
	environment.ambient_light_energy = 1.05
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.90
	environment.adjustment_contrast = 1.04
	environment.adjustment_brightness = 1.0
	_world_environment.environment = environment

	_sun.light_color = Color("ffd9b0")
	_sun.light_energy = 1.55
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 110.0
	_sun.global_position = sun_dir * 100.0
	_sun.look_at(Vector3.ZERO, Vector3.UP)

	var fill_dir: Vector3 = Vector3(0.55, -0.25, -0.72).normalized()
	_fill.light_color = Color("9db4d8")
	_fill.light_energy = 0.55
	_fill.shadow_enabled = false
	_fill.global_position = fill_dir * 100.0
	_fill.look_at(Vector3.ZERO, Vector3.UP)

	_headlight.light_color = Color("e6c9ae")
	_headlight.light_energy = 0.62
	_headlight.shadow_enabled = false


func _toggle_inventory() -> void:
	if _state == State.INVENTORY:
		_inventory_ui.close()
		return
	if _state != State.PLAYING:
		return
	_state = State.INVENTORY
	_inventory_ui.open(_model.items, _planet.radius)
	_hud.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_closed() -> void:
	if _state != State.INVENTORY:
		return
	get_tree().paused = false
	_state = State.PLAYING
	_hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_inventory_use(index: int) -> void:
	if _state != State.INVENTORY:
		return
	if index < 0 or index >= _model.items.size():
		return
	var stone: StoneItem = _model.items[index]
	if stone == null or not stone.is_stone():
		return
	_model.remove_at(index)
	_inventory_ui.close()
	_start_apply(stone)


func _on_skeleton_item_picked(kind: int) -> void:
	var item: StoneItem = StoneItem.new(kind, 1.0, 0)
	_model.add(item)
	_hud.set_inventory_count(_model.size())
	_hud.show_toast("У сумці: %s" % item.display_name(), Color("d9cbb8"), 2.6)


func _start_apply(stone: StoneItem) -> void:
	_state = State.APPLYING
	_stones_used += 1
	_was_safe_before_growth = _planet.is_jump_safe()
	_hud.set_inventory_count(_model.size())
	_player.start_smearing()
	_camera_rig.set_focus(1.55)
	AudioDirector.play_sfx("smear", 0.0, 0.5)
	var material_name: String = "кригу" if stone.is_ice() else "камінь"
	_hud.show_toast("Ти вмазуєш %s у землю..." % material_name, Color("d9cbb8"), 2.6)
	await get_tree().create_timer(3.0).timeout
	if _state != State.APPLYING:
		return
	_player.end_smearing_pose()
	_camera_rig.set_focus(1.0)
	_camera_rig.add_shake(0.22)
	_player.burst_dust()
	AudioDirector.play_sfx("grow", 0.0, 1.0)
	_planet.grow(stone.size_factor)


func _on_growth_finished(added_radius: float) -> void:
	_player.release_control()
	_state = State.PLAYING
	_update_stats()
	_hud.show_toast("Планета стала більшою на %.1f м" % added_radius, Color("8fb3ad"), 3.6)
	if not _was_safe_before_growth and _planet.is_jump_safe():
		await get_tree().create_timer(1.4).timeout
		if _state == State.PLAYING:
			_hud.show_toast("Гравітація втримає тебе. Тепер можна стрибати.", Color("e8ae86"), 5.0)


func _update_stats() -> void:
	_hud.set_planet_stats(
		_planet.radius,
		_planet.surface_gravity(),
		PlanetProfile.jump_height(_planet.radius),
		_planet.is_jump_safe()
	)


func _on_cold_changed(amount: float) -> void:
	if _state == State.DEAD:
		return
	# The icy screen is a death effect, not a warning: it stays off while alive.
	_hud.set_cold(amount)


func _on_player_landed(strength: float) -> void:
	if strength > 0.7:
		_camera_rig.add_shake(strength * 0.04)


func _on_rope_planted() -> void:
	_hud.show_toast("Кілок забито. Канат тримає тебе.", Color("cdb38d"), 3.0)


func _on_rope_removed() -> void:
	_hud.show_toast("Кілок і канат прибрано.", Color("cdb38d"), 2.0)


func _on_rope_snapped(force: float) -> void:
	if _state != State.PLAYING:
		return
	# The rope only shakes the camera: no airy whoosh, so a tethered jump stays
	# quiet instead of sounding like a flyby.
	_camera_rig.add_shake(clampf(force * 0.02, 0.04, 0.26))


func _on_froze() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_hud.set_dead()
	_hud.visible = false
	AudioDirector.play_sfx("freeze", 0.0, 1.5)
	_play_freeze_effect()
	await get_tree().create_timer(2.1).timeout
	_game_over.open(_planet.radius, _stones_used)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _play_freeze_effect() -> void:
	_set_frost_progress(0.0)
	if _frost_tween != null and _frost_tween.is_valid():
		_frost_tween.kill()
	_frost_tween = create_tween()
	_frost_tween.tween_method(_set_frost_progress, 0.0, 1.0, 1.8)


func _set_frost_progress(value: float) -> void:
	if _frost_material != null:
		_frost_material.set_shader_parameter("progress", clampf(value, 0.0, 1.0))


func _on_debris_caught(kind: int, size_factor: float, shape_seed: int) -> void:
	var stone := StoneItem.new(kind, size_factor, shape_seed)
	_model.add(stone)
	_hud.set_inventory_count(_model.size())
	_hud.show_toast(
		"%s у сумці · %.1f ×  (I — відкрити)" % [stone.display_name(), size_factor],
		stone.accent_color(),
		3.4
	)


func _open_pause() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu.open()


func _on_pause_resume() -> void:
	_pause_menu.close()
	get_tree().paused = false
	_state = State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func debug_grant_stone(kind: int = StoneItem.Kind.ROCK, size_factor: float = 1.0) -> void:
	var stone := StoneItem.new(kind, size_factor, randi())
	_model.add(stone)
	_hud.set_inventory_count(_model.size())


func debug_open_inventory() -> void:
	if _state == State.PLAYING:
		_toggle_inventory()


func debug_close_inventory() -> void:
	if _state == State.INVENTORY:
		_inventory_ui.close()


func debug_apply_first_stone() -> void:
	if _model.is_empty():
		return
	if _state == State.INVENTORY:
		_inventory_ui.close()
	var stone: StoneItem = _model.remove_at(0)
	if stone != null:
		_start_apply(stone)


func debug_freeze() -> void:
	_player.freeze()


func debug_open_pause() -> void:
	if _state == State.PLAYING:
		_open_pause()


func get_inventory_model() -> InventoryModel:
	return _model
