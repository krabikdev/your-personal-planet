extends Node

## Development staging for `--write-movie` screenshots. The stage instances the
## real game and puts it into a specific moment; the movie writer records it.
## Run:
##   godot --path . --write-movie shot.avi --quit-after 180 --fixed-fps 30 \
##       res://tools/visual_stage.tscn -- --stage=clean

@onready var game: Game = $Game

var _mode: String = "clean"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for arg: String in args:
		if arg.begins_with("--stage="):
			_mode = arg.trim_prefix("--stage=")
	print("VISUAL STAGE MODE: ", _mode)
	_setup()


func _setup() -> void:
	await get_tree().create_timer(1.0).timeout
	if _mode != "intro":
		(game.get_node("GameHud") as GameHUD).hide_intro()
	match _mode:
		"clean":
			await _walk()
		"inventory":
			game.debug_grant_stone(StoneItem.Kind.ROCK, 1.5)
			game.debug_grant_stone(StoneItem.Kind.ICE, 1.0)
			game.debug_grant_stone(StoneItem.Kind.ROCK, 0.6)
			game.debug_open_inventory()
		"empty":
			game.debug_open_inventory()
		"inventory_finds":
			game.debug_grant_stone(StoneItem.Kind.WATERING_CAN, 1.0)
			game.debug_grant_stone(StoneItem.Kind.POUCH, 1.0)
			game.debug_open_inventory()
		"smear":
			game.debug_grant_stone(StoneItem.Kind.ROCK, 1.5)
			await get_tree().create_timer(0.2).timeout
			game.debug_apply_first_stone()
		"skeleton":
			var skel_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			var skel_prop: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
			var skel_player: Boy = game.get_node("Player") as Boy
			var skel_planet: Planet = game.get_node("Planet") as Planet
			skel_prop.set_process(false)
			var skel_up: Vector3 = (
				(skel_prop.global_position - skel_planet.get_center()).normalized()
			)
			var skel_side: Vector3 = skel_prop.global_transform.basis.z
			skel_player.global_position = (
				skel_prop.global_position - skel_side * 1.7 + skel_up * 0.2
			)
			skel_player.snap_to_surface()
			skel_rig.setup(skel_prop, skel_planet)
			skel_rig.base_lift = 1.7
			skel_rig.base_distance = 3.6
			await get_tree().create_timer(0.6).timeout
		"skeleton_close":
			var close_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			var close_prop: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
			var close_player: Boy = game.get_node("Player") as Boy
			var close_planet: Planet = game.get_node("Planet") as Planet
			close_prop.set_process(false)
			close_player.global_position = (
				close_prop.global_position
				- close_prop.global_transform.basis.z * 1.4
				+ close_prop.global_transform.basis.y * 0.2
			)
			close_player.snap_to_surface()
			close_rig.setup(close_prop, close_planet)
			close_rig.base_lift = 1.0
			close_rig.base_distance = 1.7
			await get_tree().create_timer(0.6).timeout
		"skeleton_sink":
			var sink_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			var sink_prop: SkeletonProp = game.get_node("Skeleton") as SkeletonProp
			var sink_player: Boy = game.get_node("Player") as Boy
			var sink_planet: Planet = game.get_node("Planet") as Planet
			sink_prop.set_process(false)
			var sink_up: Vector3 = (
				(sink_prop.global_position - sink_planet.get_center()).normalized()
			)
			var sink_side: Vector3 = sink_prop.global_transform.basis.z
			sink_player.global_position = (
				sink_prop.global_position - sink_side * 1.7 + sink_up * 0.2
			)
			sink_player.snap_to_surface()
			sink_planet.apply_radius(PlanetProfile.BASE_RADIUS + 0.24)
			sink_rig.setup(sink_prop, sink_planet)
			sink_rig.base_lift = 1.7
			sink_rig.base_distance = 3.6
			await get_tree().create_timer(0.6).timeout
		"debris":
			var debris: DebrisManager = game.get_node("DebrisManager") as DebrisManager
			debris.force_spawn()
		"catch":
			var catcher: DebrisManager = game.get_node("DebrisManager") as DebrisManager
			catcher.force_spawn(0.5)
			await get_tree().create_timer(DebrisManager.WARNING_TIME + 0.4).timeout
			catcher.debug_place_at(-2.0)
			var planet: Planet = game.get_node("Planet") as Planet
			var player: Boy = game.get_node("Player") as Boy
			var point: Vector3 = catcher.debug_closest_point()
			var up: Vector3 = (point - planet.get_center()).normalized()
			player.global_position = point + up * 0.06
			player.snap_to_surface()
			await get_tree().create_timer(0.8).timeout
			print("CATCH RESULT (bag size): ", game.get_inventory_model().size())
		"look":
			var look_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			look_rig.orbit_by(500.0)
			await get_tree().create_timer(0.6).timeout
		"swing":
			var swing_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			swing_rig.base_lift = 1.3
			swing_rig.base_distance = 1.6
			await get_tree().create_timer(0.3).timeout
			var swinger: Boy = game.get_node("Player") as Boy
			swinger.swing_net()
			await get_tree().create_timer(0.34).timeout
		"stake":
			var stake_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			stake_rig.base_lift = 1.0
			stake_rig.base_distance = 3.6
			await get_tree().create_timer(0.4).timeout
			var stabber: Boy = game.get_node("Player") as Boy
			stabber.plant_stake()
			await get_tree().create_timer(0.35).timeout
		"rope":
			var rope_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			rope_rig.base_lift = 1.4
			rope_rig.base_distance = 7.2
			await get_tree().create_timer(0.4).timeout
			var anchored: Boy = game.get_node("Player") as Boy
			anchored.plant_stake()
			await get_tree().create_timer(0.3).timeout
			anchored.global_position += anchored.get_up() * 4.0
			await get_tree().create_timer(0.3).timeout
		"rope_walk":
			var walk_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			walk_rig.base_lift = 1.6
			walk_rig.base_distance = 5.5
			await get_tree().create_timer(0.4).timeout
			var walker: Boy = game.get_node("Player") as Boy
			walker.plant_stake()
			await get_tree().create_timer(0.3).timeout
			Input.action_press("move_right")
			await get_tree().create_timer(1.2).timeout
			Input.action_release("move_right")
			await get_tree().create_timer(0.4).timeout
		"rope_side":
			var side_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			side_rig.base_lift = 2.2
			side_rig.base_distance = 8.0
			await get_tree().create_timer(0.4).timeout
			var sider: Boy = game.get_node("Player") as Boy
			sider.plant_stake()
			await get_tree().create_timer(0.3).timeout
			var side: Vector3 = side_rig.get_tangent_right(sider.get_up())
			sider.global_position += side * 2.6 + sider.get_up() * 1.4
			await get_tree().create_timer(0.35).timeout
		"debris_approach":
			var approach: DebrisManager = game.get_node("DebrisManager") as DebrisManager
			approach.force_spawn()
			await get_tree().create_timer(7.0).timeout
		"far_side":
			var far: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			far.debug_spawn_all()
			await get_tree().process_frame
			var far_props: Array[DecorProp] = far.get_props()
			var far_marker := Node3D.new()
			far.add_child(far_marker)
			far_marker.global_position = far_props[4].global_position
			var far_planet: Planet = game.get_node("Planet") as Planet
			var far_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			far_rig.setup(far_marker, far_planet)
			far_rig.base_lift = 2.4
			far_rig.base_distance = 8.5
			await get_tree().create_timer(0.9).timeout
		"sky":
			Input.action_press("sky_view")
			await get_tree().create_timer(1.0).timeout
		"closeup":
			var rig: CameraRig = game.get_node("CameraRig") as CameraRig
			rig.base_lift = 1.1
			rig.base_distance = 1.3
			Input.action_press("move_back")
			await get_tree().create_timer(0.35).timeout
			Input.action_release("move_back")
		"pause":
			game.debug_open_pause()
		"keyjump":
			await get_tree().create_timer(0.5).timeout
			var press := InputEventKey.new()
			press.physical_keycode = KEY_SPACE
			press.pressed = true
			Input.parse_input_event(press)
			await get_tree().create_timer(0.12).timeout
			var release := InputEventKey.new()
			release.physical_keycode = KEY_SPACE
			release.pressed = false
			Input.parse_input_event(release)
		"death":
			await get_tree().create_timer(0.8).timeout
			var jumper: Boy = game.get_node("Player") as Boy
			jumper.debug_jump()
		"intro":
			pass


func _walk() -> void:
	await get_tree().create_timer(0.4).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(1.1).timeout
	Input.action_release("move_forward")
