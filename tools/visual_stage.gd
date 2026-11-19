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
			sink_planet.apply_radius(PlanetProfile.BASE_RADIUS + 0.8)
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
		"ground_check":
			var gc_planet: Planet = game.get_node("Planet") as Planet
			var gc_player: Boy = game.get_node("Player") as Boy
			var gc_spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var gc_garden: Garden = game.get_garden()
			var gc_monster: DecorProp = gc_spawner.debug_spawn_monster(Vector3.UP, 1)
			gc_monster.debug_place_near(gc_player.global_position, 1.6)
			gc_planet.apply_radius(60.0)
			await get_tree().create_timer(0.6).timeout
			var gc_up: Vector3 = (gc_player.global_position - gc_planet.get_center()).normalized()
			var gc_forward: Vector3 = -gc_player.global_transform.basis.z
			var gc_side: Vector3 = gc_forward.cross(gc_up).normalized()
			var gc_spot: Vector3 = (
				gc_planet.get_center() + (gc_up + gc_forward * 0.35).normalized() * gc_planet.radius
			)
			gc_garden.pour(gc_spot, 0.2)
			await get_tree().create_timer(0.4).timeout
			var gc_camera := Camera3D.new()
			gc_camera.name = "GroundCheckCamera"
			game.add_child(gc_camera)
			gc_camera.fov = 60.0
			gc_camera.make_current()
			gc_camera.global_position = gc_player.global_position + gc_side * 4.2 + gc_up * 0.4
			gc_camera.look_at(gc_player.global_position + gc_up * 0.4 + gc_forward * 0.9, gc_up)
			await get_tree().create_timer(0.6).timeout
			print(
				(
					"GC alt=%.3f monster=%.3f plant=%.3f radius=%.3f"
					% [
						gc_player.get_altitude(),
						(
							(gc_monster.global_position - gc_planet.get_center()).length()
							- gc_planet.radius
						),
						(
							(
								(
									(gc_garden.get_plants()[0] as PumpkinPlant).global_position
									- gc_planet.get_center()
								)
								. length()
							)
							- gc_planet.radius
						),
						gc_planet.radius,
					]
				)
			)
		"flora":
			var flora: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var flora_planet: Planet = game.get_node("Planet") as Planet
			var flora_player: Boy = game.get_node("Player") as Boy
			flora_planet.apply_radius(30.0)
			flora_player.snap_to_surface()
			await get_tree().process_frame
			flora.debug_spawn_all()
			await get_tree().process_frame
			var flora_props: Array[DecorProp] = flora.get_props()
			var flora_centre: Vector3 = flora_props[2].global_position
			var flora_up: Vector3 = (flora_centre - flora_planet.get_center()).normalized()
			var flora_reference: Vector3 = Vector3.FORWARD
			if absf(flora_reference.dot(flora_up)) > 0.9:
				flora_reference = Vector3.RIGHT
			var flora_line: Vector3 = (
				(flora_reference - flora_up * flora_reference.dot(flora_up)).normalized()
			)
			var flora_side: Vector3 = flora_line.cross(flora_up).normalized()
			var flora_camera := Camera3D.new()
			flora_camera.name = "FloraCamera"
			game.add_child(flora_camera)
			flora_camera.fov = 50.0
			flora_camera.make_current()
			flora_camera.global_position = flora_centre + flora_side * 6.5 + flora_up * 2.2
			flora_camera.look_at(flora_centre + flora_up * 1.1, flora_up)
			var flora_sun: DirectionalLight3D = game.get_node("Sun") as DirectionalLight3D
			flora_sun.global_position = (
				flora_centre + (flora_up + flora_side * 0.6).normalized() * 90.0
			)
			flora_sun.look_at(flora_centre, flora_up)
			await get_tree().create_timer(1.4).timeout
		"monsters":
			var mon: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var mon_planet: Planet = game.get_node("Planet") as Planet
			var mon_player: Boy = game.get_node("Player") as Boy
			mon_planet.apply_radius(30.0)
			mon_player.snap_to_surface()
			await get_tree().process_frame
			var mon_base: Vector3 = -mon_player.get_up()
			var mon_reference: Vector3 = Vector3.FORWARD
			if absf(mon_reference.dot(mon_base)) > 0.9:
				mon_reference = Vector3.RIGHT
			var mon_line: Vector3 = (
				(mon_reference - mon_base * mon_reference.dot(mon_base)).normalized()
			)
			for level: int in 4:
				var angle: float = (float(level) - 1.5) * 3.6 / 30.0
				var direction: Vector3 = (
					(mon_base * cos(angle) + mon_line * sin(angle)).normalized()
				)
				mon._place(DecorProp.Kind.MONSTER, direction, level + 1, 0.0)
			await get_tree().process_frame
			var mon_props: Array[DecorProp] = mon.get_props()
			var mon_centre: Vector3 = (
				(mon_props[0].global_position + mon_props[3].global_position) * 0.5
			)
			var mon_up: Vector3 = (mon_centre - mon_planet.get_center()).normalized()
			var mon_side: Vector3 = mon_line.cross(mon_up).normalized()
			var mon_front: Vector3 = -mon_props[1].global_transform.basis.z
			var mon_camera := Camera3D.new()
			mon_camera.name = "MonsterCamera"
			game.add_child(mon_camera)
			mon_camera.fov = 50.0
			mon_camera.make_current()
			mon_camera.global_position = mon_centre + mon_front * 18.0 + mon_up * 4.6
			mon_camera.look_at(mon_centre + mon_up * 2.0, mon_up)
			var mon_sun: DirectionalLight3D = game.get_node("Sun") as DirectionalLight3D
			mon_sun.global_position = mon_centre + (mon_up + mon_side * 0.6).normalized() * 90.0
			mon_sun.look_at(mon_centre, mon_up)
			await get_tree().create_timer(1.4).timeout
		"decor":
			var decor: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var decor_planet: Planet = game.get_node("Planet") as Planet
			var decor_player: Boy = game.get_node("Player") as Boy
			decor_planet.apply_radius(30.0)
			decor_player.snap_to_surface()
			await get_tree().process_frame
			decor.debug_spawn_all()
			await get_tree().process_frame
			var decor_props: Array[DecorProp] = decor.get_props()
			var decor_centre: Vector3 = decor_props[4].global_position
			var decor_up: Vector3 = (decor_centre - decor_planet.get_center()).normalized()
			var decor_reference: Vector3 = Vector3.FORWARD
			if absf(decor_reference.dot(decor_up)) > 0.9:
				decor_reference = Vector3.RIGHT
			var decor_line: Vector3 = (
				(decor_reference - decor_up * decor_reference.dot(decor_up)).normalized()
			)
			var decor_side: Vector3 = decor_line.cross(decor_up).normalized()
			var decor_camera := Camera3D.new()
			decor_camera.name = "DecorCamera"
			game.add_child(decor_camera)
			decor_camera.fov = 55.0
			decor_camera.make_current()
			decor_camera.global_position = decor_centre + decor_side * 15.0 + decor_up * 4.2
			decor_camera.look_at(decor_centre + decor_up * 1.9, decor_up)
			var decor_sun: DirectionalLight3D = game.get_node("Sun") as DirectionalLight3D
			decor_sun.global_position = (
				decor_centre + (decor_up + decor_side * 0.6).normalized() * 90.0
			)
			decor_sun.look_at(decor_centre, decor_up)
			await get_tree().create_timer(1.4).timeout
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
		"growth":
			var growth_planet: Planet = game.get_node("Planet") as Planet
			var growth_player: Boy = game.get_node("Player") as Boy
			var growth_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			var growth_spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var growth_monster: DecorProp = growth_spawner.debug_spawn_monster(Vector3.UP, 1)
			growth_monster.debug_place_near(growth_player.global_position, 2.2)
			growth_rig.base_lift = 1.0
			growth_rig.base_distance = 3.2
			game.debug_grant_stone(StoneItem.Kind.ROCK, 1.5)
			await get_tree().create_timer(0.2).timeout
			game.debug_apply_first_stone()
			for _i: int in 18:
				await get_tree().create_timer(0.3).timeout
			print(
				(
					"GROWTH alt=%.3f radius=%.3f monster=%.3f surface=%.3f"
					% [
						growth_player.get_altitude(),
						growth_planet.radius,
						(
							(growth_monster.global_position - growth_planet.get_center()).length()
							- growth_planet.radius
						),
						growth_planet.get_surface_error(),
					]
				)
			)
		"closeup":
			var rig: CameraRig = game.get_node("CameraRig") as CameraRig
			rig.base_lift = 1.1
			rig.base_distance = 1.3
			Input.action_press("move_back")
			await get_tree().create_timer(0.35).timeout
			Input.action_release("move_back")
		"pause":
			game.debug_open_pause()
		"charge":
			var charge_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			var charge_player: Boy = game.get_node("Player") as Boy
			charge_rig.base_lift = 1.6
			charge_rig.base_distance = 4.2
			await get_tree().create_timer(0.5).timeout
			Input.action_press("jump")
			await get_tree().create_timer(2.1).timeout
			Input.action_release("jump")
			await get_tree().create_timer(0.6).timeout
			print(
				(
					"CHARGE speed=%.1f height=%.1f"
					% [
						charge_player.velocity.dot(charge_player.get_up()),
						charge_player.get_altitude(),
					]
				)
			)
		"garden":
			var g_planet: Planet = game.get_node("Planet") as Planet
			var g_player: Boy = game.get_node("Player") as Boy
			var g_spawner: FarSideSpawner = game.get_node("FarSideSpawner") as FarSideSpawner
			var g_rig: CameraRig = game.get_node("CameraRig") as CameraRig
			g_rig.base_lift = 1.7
			g_rig.base_distance = 4.4
			await get_tree().create_timer(0.4).timeout
			var g_up: Vector3 = g_player.get_up()
			var g_forward: Vector3 = -g_player.global_transform.basis.z
			var g_spot: Vector3 = (
				g_planet.get_center() + (g_up + g_forward * 0.35).normalized() * g_planet.radius
			)
			var g_plant: PumpkinPlant = game.get_garden().pour(g_spot, 2.5)
			var g_monster: DecorProp = g_spawner.debug_spawn_monster(Vector3.UP, 1)
			g_monster.global_position = g_plant.get_head_position() + g_forward * 11.0
			await get_tree().create_timer(0.8).timeout
			print(
				(
					"GARDEN grounded=%s crushed=%s level=%d"
					% [
						g_plant.is_head_on_the_ground(),
						g_plant.is_stalk_crushed(),
						g_plant.get_level(),
					]
				)
			)
			g_plant.water(PumpkinPlant.LEVEL_WATER)
			await get_tree().create_timer(1.6).timeout
			print(
				(
					"GARDEN level=%d radius=%.1f interval=%.1f dead=%s"
					% [
						g_plant.get_level(),
						g_plant.get_attack_radius(),
						g_plant.get_attack_interval(),
						g_monster.is_queued_for_deletion(),
					]
				)
			)
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
