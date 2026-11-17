class_name BoyModel
extends Node3D

## Hand-built low-poly boy. He is composed of primitives so the walk cycle,
## sitting-and-smearing animation and frost tint are all procedural.

const SKIN := Color("e2bfa2")
const SKIN_SHADE := Color("d3ac8f")
const HAIR := Color("3d2f3c")
const COAT := Color("a96e5c")
const COAT_DARK := Color("895247")
const COAT_LIGHT := Color("c2876f")
const PANTS := Color("4a5567")
const PANTS_LIGHT := Color("5d6a82")
const BOOTS := Color("38303a")
const BOOT_SOLE := Color("28222c")
const BOOT_TRIM := Color("6e5b4d")
const SCARF := Color("739b92")
const SCARF_DARK := Color("5c817a")
const CREAM := Color("e9dcc4")
const MITTEN := Color("e6d7be")
const GOLD := Color("d7b06b")
const EYE := Color("2a2531")
const BLUSH := Color("c98a83")
const PACK := Color("7d6a56")
const STRAP := Color("5d4e43")
const LANTERN_GLOW := Color("ffcf8a")
const NET_SWING_DURATION: float = 0.72
const NET_ACTIVE_START: float = 0.24
const NET_ACTIVE_END: float = 0.52

var _root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D

var _scarf_a: Node3D
var _scarf_b: Node3D
var _scarf_r: Node3D
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _net_pivot: Node3D
var _net_tip: Node3D
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _walk_blend: float = 0.0
var _air_blend: float = 0.0
var _sit_blend: float = 0.0
var _run_blend: float = 0.0
var _speed_ratio: float = 0.0
var _grounded: bool = true
var _running: bool = false
var _sitting: bool = false
var _net_swinging: bool = false
var _net_swing_time: float = 0.0
var _net_active: bool = false
var _smear_time: float = 0.0
var _phase: float = 0.0
var _idle_time: float = 0.0
var _cold: float = 0.0
var _squash_tween: Tween
var _smear_dust: GPUParticles3D
var _land_dust: GPUParticles3D


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	_build_body()
	_build_dust()
	set_process(true)


func _process(delta: float) -> void:
	_idle_time += delta
	_smear_time += delta if _sitting else 0.0
	_walk_blend = move_toward(_walk_blend, _speed_ratio if _grounded else 0.0, delta * 6.0)
	_air_blend = move_toward(_air_blend, 0.0 if _grounded else 1.0, delta * 4.0)
	_sit_blend = move_toward(_sit_blend, 1.0 if _sitting else 0.0, delta * 4.5)
	_run_blend = move_toward(_run_blend, 1.0 if _running and _grounded else 0.0, delta * 5.0)
	if _grounded:
		_phase += delta * (4.5 + 6.0 * _speed_ratio + 5.5 * _run_blend)
	if _net_swinging:
		_net_swing_time += delta
		_net_active = (_net_swing_time >= NET_ACTIVE_START and _net_swing_time <= NET_ACTIVE_END)
		if _net_swing_time >= NET_SWING_DURATION:
			_net_swinging = false
			_net_swing_time = 0.0
			_net_active = false
	_animate()
	if _smear_dust != null:
		_smear_dust.emitting = _sit_blend > 0.55


func set_motion(speed_ratio: float, grounded: bool, running: bool = false) -> void:
	_speed_ratio = clampf(speed_ratio, 0.0, 1.0)
	_grounded = grounded
	_running = running


func play_net_swing() -> void:
	if _net_swinging:
		return
	_net_swinging = true
	_net_swing_time = 0.0
	_net_active = false


func is_net_active() -> bool:
	return _net_active


func get_net_catch_point() -> Vector3:
	if _net_tip == null:
		return global_position
	return _net_tip.global_position


func set_sitting(active: bool) -> void:
	if active and not _sitting:
		_smear_time = 0.0
	_sitting = active


func is_sitting() -> bool:
	return _sitting


func set_cold(amount: float) -> void:
	var value: float = clampf(amount, 0.0, 1.0)
	if is_equal_approx(value, _cold):
		return
	_cold = value
	var frost := Color(0.56, 0.73, 0.82)
	for i: int in _materials.size():
		var material: StandardMaterial3D = _materials[i]
		var base: Color = _base_colors[i]
		var tinted: Color = base.lerp(frost, value * 0.72)
		tinted.a = base.a
		material.albedo_color = tinted
		material.emission_energy_multiplier = value * 0.85


func play_land_squash(strength: float = 1.0) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	var amount: float = clampf(strength, 0.35, 1.4)
	_root.scale = Vector3.ONE
	_squash_tween = create_tween()
	_squash_tween.tween_property(
		_root, "scale", Vector3(1.0 + 0.10 * amount, 1.0 - 0.13 * amount, 1.0 + 0.10 * amount), 0.07
	)
	_squash_tween.set_trans(Tween.TRANS_QUAD)
	_squash_tween.tween_property(_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	play_land_dust()


func play_land_dust() -> void:
	if _land_dust == null:
		return
	_land_dust.restart()
	_land_dust.emitting = true


func play_catch_pose() -> void:
	var tween := create_tween()
	tween.tween_property(_arm_l, "rotation", Vector3(-2.3, 0.0, 0.5), 0.18)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-2.3, 0.0, -0.5), 0.18)
	tween.tween_property(_arm_l, "rotation", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3.ZERO, 0.5)


func _animate() -> void:
	var swing: float = sin(_phase) * 0.72 * _walk_blend
	var arm_swing: float = -sin(_phase) * 0.58 * _walk_blend
	var bob: float = absf(sin(_phase * 2.0)) * 0.022 * _walk_blend
	var breathe: float = sin(_idle_time * 1.45) * 0.008

	var leg_l: float = lerpf(swing, -0.38, _air_blend)
	var leg_r: float = lerpf(-swing, 0.46, _air_blend)
	var arm_x_l: float = lerpf(arm_swing, -0.55, _air_blend)
	var arm_x_r: float = lerpf(-arm_swing, -0.55, _air_blend)
	var arm_z_l: float = lerpf(-0.06, -0.55, _air_blend)
	var arm_z_r: float = lerpf(0.06, 0.55, _air_blend)
	var net_arm: float = 0.0
	if _net_swinging:
		if _net_swing_time < 0.18:
			net_arm = smoothstep(0.0, 0.18, _net_swing_time) * 0.35
		elif _net_swing_time < 0.30:
			net_arm = 0.35 + smoothstep(0.18, 0.30, _net_swing_time) * 0.65
		elif _net_swing_time < 0.55:
			net_arm = 1.0
		else:
			net_arm = 1.0 - smoothstep(0.55, NET_SWING_DURATION, _net_swing_time)

	if _sit_blend > 0.001:
		var smear: float = _smear_time * 6.4
		var sit_arm_x: float = -0.90 + sin(smear) * 0.36
		var sit_arm_z: float = 0.16 + cos(smear) * 0.12
		leg_l = lerpf(leg_l, -1.30, _sit_blend)
		leg_r = lerpf(leg_r, -1.16, _sit_blend)
		arm_x_l = lerpf(arm_x_l, sit_arm_x, _sit_blend)
		arm_x_r = lerpf(arm_x_r, sit_arm_x + 0.16, _sit_blend)
		arm_z_l = lerpf(arm_z_l, -sit_arm_z, _sit_blend)
		arm_z_r = lerpf(arm_z_r, sit_arm_z, _sit_blend)

	_leg_l.rotation.x = leg_l
	_leg_r.rotation.x = leg_r
	_arm_l.rotation.x = arm_x_l
	_arm_r.rotation.x = arm_x_r
	_arm_l.rotation.z = arm_z_l
	_arm_r.rotation.z = arm_z_r
	if net_arm > 0.001:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.42, net_arm)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.30, net_arm)
	if _net_pivot != null:
		_net_pivot.rotation.x = -_arm_r.rotation.x - 0.12 * net_arm
		_net_pivot.rotation.z = -_arm_r.rotation.z + 0.08 * net_arm

	_hips.position.y = 0.40 - 0.160 * _sit_blend + bob
	_torso.rotation.x = lerpf(-0.075 * _walk_blend, -0.48, _sit_blend) - 0.12 * _run_blend
	_torso.rotation.z = sin(_phase) * 0.025 * _walk_blend
	_torso.scale = Vector3(1.0 + breathe, 1.0 - breathe, 1.0 + breathe)
	_head.rotation.x = lerpf(0.04 * _walk_blend, 0.40, _sit_blend)
	_head.rotation.z = -_torso.rotation.z * 0.6

	var scarf_lift: float = 0.10 + 0.34 * _walk_blend + 0.55 * _air_blend
	_scarf_a.rotation.x = scarf_lift + sin(_phase * 2.0 + 0.6) * 0.10 * _walk_blend
	_scarf_a.rotation.z = sin(_idle_time * 1.1) * 0.035
	_scarf_b.rotation.x = scarf_lift * 0.55 + sin(_phase * 2.0 + 1.4) * 0.12 * _walk_blend
	_scarf_b.rotation.z = -_scarf_a.rotation.z * 0.7
	if _scarf_r != null:
		_scarf_r.rotation.x = scarf_lift * 0.65 + sin(_phase * 2.0 + 2.2) * 0.10 * _walk_blend
		_scarf_r.rotation.z = -sin(_idle_time * 1.25) * 0.045
	if _lantern != null:
		_lantern.rotation.z = sin(_idle_time * 1.7) * 0.10 + sin(_phase * 2.0) * 0.16 * _walk_blend
		_lantern.rotation.x = 0.28 * _air_blend + cos(_idle_time * 1.3) * 0.06
		if _lantern_light != null:
			_lantern_light.light_energy = 0.5 + sin(_idle_time * 7.0) * 0.035


func _build_body() -> void:
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0.0, 0.40, 0.0)
	_root.add_child(_hips)

	_leg_l = _make_pivot(_hips, "LegL", Vector3(-0.085, 0.0, 0.0))
	_build_leg(_leg_l)
	_leg_r = _make_pivot(_hips, "LegR", Vector3(0.085, 0.0, 0.0))
	_build_leg(_leg_r)

	_torso = _make_pivot(_hips, "Torso", Vector3(0.0, 0.02, 0.0))
	_build_torso()
	_build_head()


func _build_leg(parent: Node3D) -> void:
	var pants_material := _material(PANTS, 0.92)
	var pants_light := _material(PANTS_LIGHT, 0.9)
	var boot_material := _material(BOOTS, 0.75)
	var sole_material := _material(BOOT_SOLE, 0.82)
	var trim_material := _material(BOOT_TRIM, 0.86)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.058
	capsule.height = 0.30
	capsule.radial_segments = 10
	capsule.rings = 4
	_add_mesh(parent, capsule, pants_material, Vector3(0.0, -0.15, 0.0))

	var knee := SphereMesh.new()
	knee.radius = 0.038
	knee.height = 0.076
	knee.radial_segments = 10
	knee.rings = 5
	var knee_node := _add_mesh(parent, knee, pants_light, Vector3(0.0, -0.155, -0.052))
	knee_node.scale = Vector3(1.0, 0.82, 0.38)

	var boot := BoxMesh.new()
	boot.size = Vector3(0.125, 0.085, 0.205)
	_add_mesh(parent, boot, boot_material, Vector3(0.0, -0.322, -0.028))
	var sole := BoxMesh.new()
	sole.size = Vector3(0.138, 0.022, 0.218)
	_add_mesh(parent, sole, sole_material, Vector3(0.0, -0.368, -0.028))
	var cuff := BoxMesh.new()
	cuff.size = Vector3(0.135, 0.045, 0.15)
	_add_mesh(parent, cuff, trim_material, Vector3(0.0, -0.278, 0.0))
	var strap := BoxMesh.new()
	strap.size = Vector3(0.128, 0.016, 0.014)
	_add_mesh(parent, strap, trim_material, Vector3(0.0, -0.322, -0.128))
	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.026, 0.018, 0.012)
	_add_mesh(parent, buckle, _material(GOLD, 0.36), Vector3(0.036, -0.322, -0.133))


func _build_torso() -> void:
	var coat_material := _material(COAT, 0.9)
	var dark_material := _material(COAT_DARK, 0.92)
	var cream_material := _material(CREAM, 0.85)
	var scarf_material := _material(SCARF, 0.88)
	var skin_material := _material(SKIN, 0.82)

	var coat := CylinderMesh.new()
	coat.top_radius = 0.155
	coat.bottom_radius = 0.205
	coat.height = 0.36
	coat.radial_segments = 16
	coat.rings = 2
	_add_mesh(_torso, coat, coat_material, Vector3(0.0, 0.20, 0.0))

	var hem := CylinderMesh.new()
	hem.top_radius = 0.205
	hem.bottom_radius = 0.218
	hem.height = 0.075
	hem.radial_segments = 16
	_add_mesh(_torso, hem, dark_material, Vector3(0.0, 0.045, 0.0))

	var belt := TorusMesh.new()
	belt.inner_radius = 0.175
	belt.outer_radius = 0.196
	belt.rings = 24
	belt.ring_segments = 5
	_add_mesh(_torso, belt, dark_material, Vector3(0.0, 0.075, 0.0))

	var collar := TorusMesh.new()
	collar.inner_radius = 0.088
	collar.outer_radius = 0.142
	collar.rings = 24
	collar.ring_segments = 6
	_add_mesh(_torso, collar, cream_material, Vector3(0.0, 0.368, 0.0))

	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.095
	scarf.outer_radius = 0.158
	scarf.rings = 26
	scarf.ring_segments = 7
	_add_mesh(_torso, scarf, scarf_material, Vector3(0.0, 0.34, 0.0))

	var neck := CylinderMesh.new()
	neck.top_radius = 0.06
	neck.bottom_radius = 0.068
	neck.height = 0.09
	neck.radial_segments = 12
	_add_mesh(_torso, neck, skin_material, Vector3(0.0, 0.39, 0.0))

	var coat_light_material := _material(COAT_LIGHT, 0.9)
	var gold_material := _material(GOLD, 0.36)
	var strap_material := _material(STRAP, 0.9)

	var placket := BoxMesh.new()
	placket.size = Vector3(0.03, 0.30, 0.014)
	_add_mesh(_torso, placket, coat_light_material, Vector3(0.0, 0.205, -0.198))

	var button_material := _material(COAT_DARK.darkened(0.35), 0.6)
	for i: int in 2:
		var button := SphereMesh.new()
		button.radius = 0.017
		button.height = 0.034
		button.radial_segments = 8
		button.rings = 4
		_add_mesh(_torso, button, gold_material, Vector3(0.0, 0.26 - i * 0.10, -0.209))

	var badge := SphereMesh.new()
	badge.radius = 0.027
	badge.height = 0.018
	badge.radial_segments = 10
	badge.rings = 4
	_add_mesh(_torso, badge, cream_material, Vector3(0.082, 0.295, -0.178))

	for sign_x: float in [-1.0, 1.0]:
		var pocket := BoxMesh.new()
		pocket.size = Vector3(0.078, 0.064, 0.016)
		_add_mesh(_torso, pocket, dark_material, Vector3(0.088 * sign_x, 0.105, -0.194))
		var pocket_flap := BoxMesh.new()
		pocket_flap.size = Vector3(0.084, 0.02, 0.02)
		_add_mesh(_torso, pocket_flap, coat_light_material, Vector3(0.088 * sign_x, 0.142, -0.196))

	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.062, 0.044, 0.016)
	_add_mesh(_torso, buckle, gold_material, Vector3(0.0, 0.075, -0.205))
	var buckle_inner := BoxMesh.new()
	buckle_inner.size = Vector3(0.04, 0.026, 0.02)
	_add_mesh(_torso, buckle_inner, dark_material, Vector3(0.0, 0.075, -0.209))

	var canteen := CylinderMesh.new()
	canteen.top_radius = 0.034
	canteen.bottom_radius = 0.034
	canteen.height = 0.022
	canteen.radial_segments = 12
	var canteen_node := _add_mesh(_torso, canteen, strap_material, Vector3(-0.19, 0.10, 0.01))
	canteen_node.rotation.z = PI * 0.5
	var canteen_cap := CylinderMesh.new()
	canteen_cap.top_radius = 0.013
	canteen_cap.bottom_radius = 0.013
	canteen_cap.height = 0.024
	canteen_cap.radial_segments = 8
	_add_mesh(_torso, canteen_cap, cream_material, Vector3(-0.19, 0.138, 0.01))

	_build_arm(_torso, true)
	_build_arm(_torso, false)
	_build_scarf_tail()
	_build_backpack()


func _build_arm(parent: Node3D, left: bool) -> void:
	var sign_x: float = -1.0 if left else 1.0
	var inward: float = 1.0 if left else -1.0
	var arm := _make_pivot(parent, "ArmL" if left else "ArmR", Vector3(0.168 * sign_x, 0.30, 0.0))
	var coat_material := _material(COAT, 0.9)
	var patch_material := _material(COAT_DARK, 0.92)
	var mitten_material := _material(MITTEN, 0.9)
	var cuff_material := _material(SCARF_DARK, 0.9)
	var cuff_trim := _material(CREAM, 0.86)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.047
	capsule.height = 0.25
	capsule.radial_segments = 10
	capsule.rings = 3
	_add_mesh(arm, capsule, coat_material, Vector3(0.0, -0.115, 0.0))

	var elbow := SphereMesh.new()
	elbow.radius = 0.04
	elbow.height = 0.08
	elbow.radial_segments = 10
	elbow.rings = 5
	var elbow_node := _add_mesh(arm, elbow, patch_material, Vector3(0.0, -0.14, -0.038))
	elbow_node.scale = Vector3(0.9, 0.9, 0.35)

	var band := CylinderMesh.new()
	band.top_radius = 0.052
	band.bottom_radius = 0.052
	band.height = 0.012
	band.radial_segments = 12
	_add_mesh(arm, band, cuff_trim, Vector3(0.0, -0.244, 0.0))

	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.053
	cuff.bottom_radius = 0.049
	cuff.height = 0.036
	cuff.radial_segments = 12
	_add_mesh(arm, cuff, cuff_material, Vector3(0.0, -0.228, 0.0))

	var hand := SphereMesh.new()
	hand.radius = 0.057
	hand.height = 0.114
	hand.radial_segments = 12
	hand.rings = 6
	var hand_node := _add_mesh(arm, hand, mitten_material, Vector3(0.0, -0.278, 0.0))
	hand_node.scale = Vector3(0.92, 1.05, 1.0)

	var thumb := SphereMesh.new()
	thumb.radius = 0.022
	thumb.height = 0.044
	thumb.radial_segments = 8
	thumb.rings = 4
	_add_mesh(arm, thumb, mitten_material, Vector3(0.042 * inward, -0.292, -0.012))
	if left:
		_arm_l = arm
	else:
		_arm_r = arm
		_build_net(arm)


func _build_net(arm: Node3D) -> void:
	_net_pivot = Node3D.new()
	_net_pivot.name = "Net"
	_net_pivot.position = Vector3(0.0, -0.278, 0.0)
	arm.add_child(_net_pivot)

	var wood := _material(STRAP, 0.88)
	var gold := _material(GOLD, 0.34)
	var rim := _material(CREAM, 0.82)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.014
	handle.bottom_radius = 0.016
	handle.height = 0.88
	handle.radial_segments = 8
	_add_mesh(_net_pivot, handle, wood, Vector3(0.0, 0.44, 0.16))

	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.15
	hoop.outer_radius = 0.18
	hoop.rings = 28
	hoop.ring_segments = 6
	_add_mesh(_net_pivot, hoop, gold, Vector3(0.0, 0.9, 0.0))

	var bag_material := StandardMaterial3D.new()
	bag_material.albedo_color = Color(0.9, 0.85, 0.74, 0.22)
	bag_material.roughness = 0.9
	bag_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bag_material.emission_enabled = true
	bag_material.emission = Color(0.35, 0.31, 0.28)
	bag_material.emission_energy_multiplier = 0.15
	var bag := CylinderMesh.new()
	bag.top_radius = 0.15
	bag.bottom_radius = 0.045
	bag.height = 0.28
	bag.radial_segments = 16
	bag.rings = 2
	_add_mesh(_net_pivot, bag, bag_material, Vector3(0.0, 0.75, 0.0))

	var bottom_rim := TorusMesh.new()
	bottom_rim.inner_radius = 0.038
	bottom_rim.outer_radius = 0.052
	bottom_rim.rings = 14
	bottom_rim.ring_segments = 4
	_add_mesh(_net_pivot, bottom_rim, rim, Vector3(0.0, 0.61, 0.0))

	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		var top_point := Vector3(cos(angle) * 0.15, 0.90, sin(angle) * 0.15)
		var bottom_point := Vector3(cos(angle) * 0.045, 0.61, sin(angle) * 0.045)
		var segment: Vector3 = top_point - bottom_point
		var rod := CylinderMesh.new()
		rod.top_radius = 0.0035
		rod.bottom_radius = 0.0035
		rod.height = segment.length()
		rod.radial_segments = 5
		var rod_node := _add_mesh(_net_pivot, rod, rim, (top_point + bottom_point) * 0.5)
		rod_node.quaternion = Quaternion(Vector3.UP, segment.normalized())

	_net_tip = Node3D.new()
	_net_tip.name = "CatchPoint"
	_net_tip.position = Vector3(0.0, 0.9, 0.0)
	_net_pivot.add_child(_net_tip)


func _build_scarf_tail() -> void:
	var material := _material(SCARF, 0.88)
	var dark := _material(SCARF_DARK, 0.9)
	var knot := SphereMesh.new()
	knot.radius = 0.035
	knot.height = 0.07
	knot.radial_segments = 10
	knot.rings = 5
	_add_mesh(_torso, knot, dark, Vector3(-0.145, 0.333, 0.09))
	var knot_r := SphereMesh.new()
	knot_r.radius = 0.026
	knot_r.height = 0.052
	knot_r.radial_segments = 8
	knot_r.rings = 4
	_add_mesh(_torso, knot_r, dark, Vector3(0.145, 0.335, 0.088))
	_scarf_a = _make_pivot(_torso, "ScarfA", Vector3(-0.145, 0.335, 0.090))
	var a := BoxMesh.new()
	a.size = Vector3(0.095, 0.26, 0.032)
	_add_mesh(_scarf_a, a, material, Vector3(0.0, -0.13, 0.0))
	var fringe := BoxMesh.new()
	fringe.size = Vector3(0.10, 0.018, 0.036)
	_add_mesh(_scarf_a, fringe, dark, Vector3(0.0, -0.268, 0.0))
	_scarf_b = _make_pivot(_scarf_a, "ScarfB", Vector3(0.0, -0.26, 0.0))
	var b := BoxMesh.new()
	b.size = Vector3(0.078, 0.21, 0.028)
	_add_mesh(_scarf_b, b, dark, Vector3(0.0, -0.105, 0.0))
	_scarf_r = _make_pivot(_torso, "ScarfR", Vector3(0.145, 0.335, 0.088))
	var r := BoxMesh.new()
	r.size = Vector3(0.072, 0.17, 0.028)
	_add_mesh(_scarf_r, r, material, Vector3(0.0, -0.085, 0.0))
	var r_fringe := BoxMesh.new()
	r_fringe.size = Vector3(0.078, 0.016, 0.032)
	_add_mesh(_scarf_r, r_fringe, dark, Vector3(0.0, -0.178, 0.0))


func _build_backpack() -> void:
	var pack_material := _material(PACK, 0.94)
	var strap_material := _material(STRAP, 0.9)
	var cream_material := _material(CREAM, 0.85)
	var scarf_material := _material(SCARF, 0.88)
	var scarf_dark := _material(SCARF_DARK, 0.9)
	var pack := BoxMesh.new()
	pack.size = Vector3(0.235, 0.28, 0.115)
	_add_mesh(_torso, pack, pack_material, Vector3(0.0, 0.22, 0.165))
	var flap := BoxMesh.new()
	flap.size = Vector3(0.245, 0.07, 0.128)
	_add_mesh(_torso, flap, strap_material, Vector3(0.0, 0.315, 0.162))
	for sign_x: float in [-1.0, 1.0]:
		var strap := BoxMesh.new()
		strap.size = Vector3(0.032, 0.30, 0.022)
		_add_mesh(_torso, strap, strap_material, Vector3(0.10 * sign_x, 0.235, -0.172))
		var back_pocket := BoxMesh.new()
		back_pocket.size = Vector3(0.072, 0.09, 0.03)
		_add_mesh(_torso, back_pocket, strap_material, Vector3(0.075 * sign_x, 0.16, 0.226))

	var bedroll := CylinderMesh.new()
	bedroll.top_radius = 0.056
	bedroll.bottom_radius = 0.056
	bedroll.height = 0.27
	bedroll.radial_segments = 12
	var bedroll_node := _add_mesh(_torso, bedroll, scarf_material, Vector3(0.0, 0.395, 0.185))
	bedroll_node.rotation.z = PI * 0.5
	for sign_x: float in [-1.0, 1.0]:
		var roll_end := CylinderMesh.new()
		roll_end.top_radius = 0.057
		roll_end.bottom_radius = 0.057
		roll_end.height = 0.016
		roll_end.radial_segments = 12
		var end_node := _add_mesh(
			_torso, roll_end, scarf_dark, Vector3(0.136 * sign_x, 0.395, 0.185)
		)
		end_node.rotation.z = PI * 0.5
	var roll_band := TorusMesh.new()
	roll_band.inner_radius = 0.056
	roll_band.outer_radius = 0.066
	roll_band.rings = 18
	roll_band.ring_segments = 5
	var roll_band_node := _add_mesh(_torso, roll_band, cream_material, Vector3(0.0, 0.395, 0.185))
	roll_band_node.rotation.z = PI * 0.5

	_lantern = _make_pivot(_torso, "Lantern", Vector3(0.205, 0.30, 0.20))
	var chain := CylinderMesh.new()
	chain.top_radius = 0.005
	chain.bottom_radius = 0.005
	chain.height = 0.10
	chain.radial_segments = 6
	_add_mesh(_lantern, chain, strap_material, Vector3(0.0, -0.05, 0.0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.016
	cap.bottom_radius = 0.028
	cap.height = 0.028
	cap.radial_segments = 8
	_add_mesh(_lantern, cap, strap_material, Vector3(0.0, -0.11, 0.0))
	var glass := SphereMesh.new()
	glass.radius = 0.032
	glass.height = 0.064
	glass.radial_segments = 10
	glass.rings = 6
	_add_mesh(_lantern, glass, _glow_material(LANTERN_GLOW), Vector3(0.0, -0.142, 0.0))
	var base := CylinderMesh.new()
	base.top_radius = 0.022
	base.bottom_radius = 0.018
	base.height = 0.014
	base.radial_segments = 8
	_add_mesh(_lantern, base, strap_material, Vector3(0.0, -0.176, 0.0))
	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.light_color = Color("ffb46b")
	_lantern_light.light_energy = 0.5
	_lantern_light.omni_range = 1.5
	_lantern_light.shadow_enabled = false
	_lantern_light.position = Vector3(0.0, -0.142, 0.0)
	_lantern.add_child(_lantern_light)


func _build_head() -> void:
	_head = _make_pivot(_torso, "Head", Vector3(0.0, 0.38, 0.0))
	var skin := _material(SKIN, 0.8)
	var skin_shade := _material(SKIN_SHADE, 0.82)
	var hair := _material(HAIR, 0.92)
	var eye := _material(EYE, 0.28)
	var cream := _material(CREAM, 0.5)
	var blush := _material(BLUSH, 0.9)
	var mouth := _material(HAIR.lightened(0.1), 0.9)

	var skull := SphereMesh.new()
	skull.radius = 0.145
	skull.height = 0.29
	skull.radial_segments = 20
	skull.rings = 12
	_add_mesh(_head, skull, skin, Vector3(0.0, 0.055, 0.0))

	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.150
	hair_cap.height = 0.30
	hair_cap.is_hemisphere = true
	hair_cap.radial_segments = 20
	hair_cap.rings = 8
	var cap := _add_mesh(_head, hair_cap, hair, Vector3(0.0, 0.075, 0.012))
	cap.scale = Vector3(1.01, 0.90, 1.01)

	var back_hair := SphereMesh.new()
	back_hair.radius = 0.105
	back_hair.height = 0.21
	back_hair.radial_segments = 12
	back_hair.rings = 6
	var back_node := _add_mesh(_head, back_hair, hair, Vector3(0.0, 0.020, 0.065))
	back_node.scale = Vector3(1.18, 0.95, 0.62)

	for sign_x: float in [-1.0, 1.0]:
		var ear := SphereMesh.new()
		ear.radius = 0.034
		ear.height = 0.068
		ear.radial_segments = 10
		ear.rings = 5
		var ear_node := _add_mesh(_head, ear, skin_shade, Vector3(0.142 * sign_x, 0.045, 0.005))
		ear_node.scale = Vector3(0.55, 1.0, 0.8)

		var side_hair := SphereMesh.new()
		side_hair.radius = 0.058
		side_hair.height = 0.116
		side_hair.radial_segments = 10
		side_hair.rings = 5
		var side_hair_node := _add_mesh(
			_head, side_hair, hair, Vector3(0.105 * sign_x, 0.032, 0.035)
		)
		side_hair_node.scale = Vector3(0.62, 1.05, 0.90)

		var eye_node := SphereMesh.new()
		eye_node.radius = 0.021
		eye_node.height = 0.042
		eye_node.radial_segments = 10
		eye_node.rings = 6
		_add_mesh(_head, eye_node, eye, Vector3(0.052 * sign_x, 0.030, -0.138))

		var glint := SphereMesh.new()
		glint.radius = 0.0075
		glint.height = 0.015
		glint.radial_segments = 6
		glint.rings = 3
		_add_mesh(_head, glint, cream, Vector3(0.046 * sign_x, 0.039, -0.151))

		var cheek := SphereMesh.new()
		cheek.radius = 0.030
		cheek.height = 0.060
		cheek.radial_segments = 8
		cheek.rings = 4
		var cheek_node := _add_mesh(_head, cheek, blush, Vector3(0.089 * sign_x, -0.004, -0.104))
		cheek_node.scale = Vector3(1.0, 0.55, 0.28)

		var fringe := SphereMesh.new()
		fringe.radius = 0.044
		fringe.height = 0.088
		fringe.radial_segments = 8
		fringe.rings = 4
		var fringe_node := _add_mesh(_head, fringe, hair, Vector3(0.058 * sign_x, 0.118, -0.110))
		fringe_node.scale = Vector3(1.0, 0.72, 0.50)

	var center_fringe := SphereMesh.new()
	center_fringe.radius = 0.045
	center_fringe.height = 0.090
	center_fringe.radial_segments = 8
	center_fringe.rings = 4
	var center_fringe_node := _add_mesh(_head, center_fringe, hair, Vector3(0.0, 0.126, -0.112))
	center_fringe_node.scale = Vector3(0.90, 0.68, 0.50)

	var nose := SphereMesh.new()
	nose.radius = 0.019
	nose.height = 0.038
	nose.radial_segments = 8
	nose.rings = 4
	_add_mesh(_head, nose, skin_shade, Vector3(0.0, 0.012, -0.141))

	var lip := SphereMesh.new()
	lip.radius = 0.021
	lip.height = 0.042
	lip.radial_segments = 8
	lip.rings = 4
	var lip_node := _add_mesh(_head, lip, mouth, Vector3(0.0, -0.034, -0.118))
	lip_node.scale = Vector3(1.35, 0.22, 0.28)

	var tuft := SphereMesh.new()
	tuft.radius = 0.048
	tuft.height = 0.096
	tuft.radial_segments = 8
	tuft.rings = 4
	var tuft_node := _add_mesh(_head, tuft, hair, Vector3(0.012, 0.195, 0.012))
	tuft_node.scale = Vector3(0.9, 1.15, 0.9)
	tuft_node.rotation.z = -0.4

	var scarf_material := _material(SCARF, 0.88)
	var scarf_dark := _material(SCARF_DARK, 0.9)
	var pompom_material := _material(CREAM, 0.95)
	var brow_material := _material(HAIR.darkened(0.12), 0.9)
	var freckle_material := _material(BLUSH.darkened(0.18), 0.9)

	var headband := TorusMesh.new()
	headband.inner_radius = 0.132
	headband.outer_radius = 0.155
	headband.rings = 32
	headband.ring_segments = 6
	var headband_node := _add_mesh(_head, headband, scarf_material, Vector3(0.0, 0.082, 0.0))
	headband_node.scale = Vector3(1.0, 0.82, 1.0)

	var band_knot := SphereMesh.new()
	band_knot.radius = 0.028
	band_knot.height = 0.056
	band_knot.radial_segments = 10
	band_knot.rings = 5
	_add_mesh(_head, band_knot, scarf_dark, Vector3(0.148, 0.072, -0.022))
	for i: int in 2:
		var band_tail := BoxMesh.new()
		band_tail.size = Vector3(0.052, 0.13 - float(i) * 0.035, 0.022)
		var tail_node := _add_mesh(
			_head, band_tail, scarf_dark, Vector3(0.162, 0.005 - float(i) * 0.06, -0.006)
		)
		tail_node.rotation.z = -0.22 + float(i) * 0.10

	var pompom := SphereMesh.new()
	pompom.radius = 0.05
	pompom.height = 0.10
	pompom.radial_segments = 12
	pompom.rings = 6
	var pompom_node := _add_mesh(_head, pompom, pompom_material, Vector3(0.0, 0.225, 0.006))
	pompom_node.scale = Vector3(1.0, 0.9, 1.0)

	for sign_x: float in [-1.0, 1.0]:
		var brow := BoxMesh.new()
		brow.size = Vector3(0.043, 0.009, 0.012)
		var brow_node := _add_mesh(
			_head, brow, brow_material, Vector3(0.052 * sign_x, 0.074, -0.145)
		)
		brow_node.rotation.z = -0.12 * sign_x

		var freckle_a := SphereMesh.new()
		freckle_a.radius = 0.0055
		freckle_a.height = 0.011
		freckle_a.radial_segments = 6
		freckle_a.rings = 3
		_add_mesh(_head, freckle_a, freckle_material, Vector3(0.072 * sign_x, 0.003, -0.119))
		var freckle_b := SphereMesh.new()
		freckle_b.radius = 0.0045
		freckle_b.height = 0.009
		freckle_b.radial_segments = 6
		freckle_b.rings = 3
		_add_mesh(_head, freckle_b, freckle_material, Vector3(0.087 * sign_x, -0.010, -0.103))

		var smile_corner := BoxMesh.new()
		smile_corner.size = Vector3(0.013, 0.006, 0.007)
		var corner_node := _add_mesh(
			_head, smile_corner, mouth, Vector3(0.018 * sign_x, -0.042, -0.111)
		)
		corner_node.rotation.z = 0.38 * sign_x


func _build_dust() -> void:
	var texture := _soft_dot_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = _particle_material(texture)

	_smear_dust = GPUParticles3D.new()
	_smear_dust.name = "SmearDust"
	_smear_dust.amount = 56
	_smear_dust.lifetime = 1.45
	_smear_dust.local_coords = true
	_smear_dust.one_shot = false
	_smear_dust.emitting = false
	_smear_dust.position = Vector3(0.0, 0.12, -0.24)
	_smear_dust.draw_pass_1 = quad
	var pmat := _particle_process(
		Color(0.70, 0.56, 0.45, 0.80), 0.25, 0.85, Vector3(0.0, 0.55, -0.30)
	)
	pmat.spread = 110.0
	pmat.gravity = Vector3(0.0, -0.75, 0.0)
	pmat.scale_min = 0.45
	pmat.scale_max = 1.65
	_smear_dust.process_material = pmat
	add_child(_smear_dust)

	_land_dust = GPUParticles3D.new()
	_land_dust.name = "LandDust"
	_land_dust.amount = 18
	_land_dust.lifetime = 0.65
	_land_dust.local_coords = true
	_land_dust.one_shot = true
	_land_dust.explosiveness = 0.92
	_land_dust.emitting = false
	_land_dust.position = Vector3(0.0, 0.05, 0.0)
	_land_dust.draw_pass_1 = quad
	var lmat := _particle_process(Color(0.58, 0.49, 0.43, 0.7), 0.25, 0.85, Vector3(0.0, 0.5, 0.0))
	lmat.spread = 100.0
	lmat.gravity = Vector3(0.0, -1.2, 0.0)
	lmat.scale_min = 0.4
	lmat.scale_max = 1.4
	_land_dust.process_material = lmat
	add_child(_land_dust)


func _particle_process(
	color: Color, speed_min: float, speed_max: float, direction: Vector3
) -> ParticleProcessMaterial:
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = direction
	pmat.initial_velocity_min = speed_min
	pmat.initial_velocity_max = speed_max
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.08
	pmat.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.18, color)
	ramp.add_point(0.55, Color(color.r, color.g, color.b, color.a * 0.55))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	pmat.color_ramp = ramp_texture
	return pmat


func _particle_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = false
	return material


func _soft_dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


func _make_pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color(0.42, 0.68, 0.88)
	material.emission_energy_multiplier = 0.0
	_materials.append(material)
	_base_colors.append(color)
	return material


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance
