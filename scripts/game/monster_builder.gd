class_name MonsterBuilder
extends RefCounted

## Builds the four monsters out of smooth primitives. Everything is merged by
## the mesher, so a monster can be detailed without costing a draw call per
## tooth. The shared frame is one metre tall with the feet at y = 0 and the
## creature facing -Z, which is how DecorProp orients every model.

const BONE := Color("d6c7a6")
const EYE_AMBER := Color("ffb14a")
const EYE_RED := Color("ff5a3c")

static var _mat_cache: Dictionary[String, StandardMaterial3D] = {}


## The level decides which creature shows up: a furry caterpillar, a hydralisk,
## a hulking ragnos, or Zodd himself.
static func build(level: int, rng: RandomNumberGenerator, mesher: PropMesher) -> void:
	match clampi(level, 1, 4):
		1:
			_caterpillar(rng, mesher)
		2:
			_hydralisk(mesher)
		3:
			_ragnos(mesher)
		_:
			_zodd(mesher)


static func name_for_level(level: int) -> String:
	match clampi(level, 1, 4):
		1:
			return "Волохата гусінь"
		2:
			return "Гідраліск"
		3:
			return "Рагнос"
		_:
			return "Зодд"


## A brown furry caterpillar: a row of fuzzy banded segments, many little legs
## and a round head with antennae. It stays low to the ground.
static func _caterpillar(rng: RandomNumberGenerator, mesher: PropMesher) -> void:
	var fur: StandardMaterial3D = _mat(Color("6b4a2b"), 0.96)
	var fur_dark: StandardMaterial3D = _mat(Color("4a3018"), 0.98)
	var fur_light: StandardMaterial3D = _mat(Color("8f6a3c"), 0.95)
	var belly: StandardMaterial3D = _mat(Color("a98a5c"), 0.92)
	var dark: StandardMaterial3D = _mat(Color("221a12"), 0.85)
	var white: StandardMaterial3D = _mat(Color("efe6cf"), 0.55)
	var pupil: StandardMaterial3D = _mat(Color("17120e"), 0.35)

	var segments: int = 10
	for i: int in segments:
		var t: float = float(i) / float(segments - 1)
		var z: float = 0.42 - 0.84 * t
		var radius: float = 0.105 + 0.05 * sin(t * PI)
		var y: float = radius * 0.95
		var body: StandardMaterial3D = fur if i % 2 == 0 else fur_dark
		_sphere(mesher, body, Vector3(0.0, y, z), radius, Vector3(1.0, 0.95, 1.04))
		_sphere(
			mesher,
			belly,
			Vector3(0.0, y - radius * 0.38, z),
			radius * 0.82,
			Vector3(0.95, 0.6, 0.95),
			14,
			7,
		)
		# A shaggy coat: short cones all around the segment, longer on the back.
		var tufts: int = 9
		for k: int in tufts:
			var around: float = TAU * float(k) / float(tufts) + rng.randf_range(-0.3, 0.3)
			var lift: float = rng.randf_range(0.1, 0.9) if absf(cos(around)) < 0.9 else 0.25
			var dir := Vector3(cos(around), lift, sin(around)).normalized()
			var base: Vector3 = Vector3(0.0, y, z) + dir * (radius * 0.9)
			var length: float = rng.randf_range(0.05, 0.13)
			_cone(
				mesher,
				fur_light if k % 3 == 0 else body,
				base + dir * length * 0.5,
				0.017,
				length,
				dir,
			)
		# Tiny stubby legs under every segment but the head and tail.
		if i > 0 and i < segments - 1:
			for side: float in [-1.0, 1.0]:
				var hip := Vector3(radius * 0.8 * side, radius * 0.45, z)
				var foot := Vector3(radius * 1.4 * side, 0.015, z + 0.03)
				_capsule(
					mesher,
					dark,
					(hip + foot) * 0.5,
					0.02,
					hip.distance_to(foot) + 0.03,
					Vector3.ZERO
				)

	# Head.
	var head := Vector3(0.0, 0.18, -0.46)
	_sphere(mesher, fur, head, 0.16, Vector3(1.0, 1.02, 0.96))
	_sphere(mesher, belly, head + Vector3(0.0, -0.07, -0.07), 0.105, Vector3(0.95, 0.7, 0.8))
	for side: float in [-1.0, 1.0]:
		_sphere(
			mesher, white, head + Vector3(0.075 * side, 0.055, -0.115), 0.052, Vector3.ONE, 14, 7
		)
		_sphere(
			mesher, pupil, head + Vector3(0.086 * side, 0.055, -0.152), 0.027, Vector3.ONE, 12, 6
		)
		# Mandibles and a pair of antennae with little bulbs.
		_cone(
			mesher,
			dark,
			head + Vector3(0.045 * side, -0.09, -0.1),
			0.02,
			0.1,
			Vector3(0.25 * side, -0.7, -0.65),
		)
		var antenna_from: Vector3 = head + Vector3(0.05 * side, 0.13, -0.02)
		var antenna_to: Vector3 = antenna_from + Vector3(0.11 * side, 0.23, -0.11)
		_capsule(mesher, dark, (antenna_from + antenna_to) * 0.5, 0.013, 0.3, Vector3.ZERO)
		_sphere(mesher, fur_light, antenna_to, 0.034, Vector3.ONE, 12, 6)
	# A mane of longer hairs around the head.
	for k: int in 10:
		var around: float = TAU * float(k) / 10.0
		var dir := Vector3(cos(around) * 0.8, 0.75, sin(around) * 0.6 - 0.2).normalized()
		var base: Vector3 = head + dir * 0.13
		_cone(mesher, fur_light, base + dir * 0.06, 0.019, 0.13, dir)


## A hydralisk: a coiled snake lower body holding up a hunched torso, a wide
## bone hood over the skull, glowing eyes and two long scythe blades.
static func _hydralisk(mesher: PropMesher) -> void:
	var shell: StandardMaterial3D = _mat(Color("5c3038"), 0.7)
	var shell_dark: StandardMaterial3D = _mat(Color("3a1e25"), 0.72)
	var hide: StandardMaterial3D = _mat(Color("94705c"), 0.86)
	var bone: StandardMaterial3D = _mat(BONE, 0.5)
	var glow: StandardMaterial3D = _mat(EYE_AMBER, 0.25, EYE_AMBER, 2.4)

	# The snake body: a coil that spirals up from the ground into the waist, so
	# the hydralisk reads as a serpent from every side.
	var coils: int = 15
	var coil_points: Array[Vector3] = []
	for i: int in coils:
		var t: float = float(i) / float(coils - 1)
		var around: float = t * TAU * 1.35 + 0.4
		var ring: float = lerpf(0.4, 0.15, t)
		var point := Vector3(cos(around) * ring, 0.08 + t * 0.58, sin(around) * ring * 0.85 + 0.04)
		coil_points.append(point)
		_sphere(
			mesher,
			shell if i % 2 == 0 else shell_dark,
			point,
			lerpf(0.14, 0.17, t),
			Vector3(1.05, 0.92, 1.05),
		)
		if i > 0:
			var from: Vector3 = coil_points[i - 1]
			_capsule(
				mesher,
				shell_dark,
				(from + point) * 0.5,
				lerpf(0.13, 0.16, t),
				from.distance_to(point) + 0.05,
				Vector3.ZERO,
			)
	# Pale belly plates up the front of the coil.
	for i: int in 5:
		var t: float = float(i) / 4.0
		_sphere(
			mesher,
			hide,
			Vector3(0.0, 0.16 + t * 0.48, -lerpf(0.36, 0.17, t)),
			0.1 - t * 0.014,
			Vector3(1.25, 0.5, 0.5),
			16,
			8,
		)

	# The chest sits on top of the coil.
	_sphere(mesher, shell, Vector3(0.0, 0.86, -0.02), 0.25, Vector3(0.95, 1.05, 0.9))
	_sphere(mesher, shell, Vector3(0.0, 1.02, -0.06), 0.2, Vector3(1.05, 0.8, 0.95))
	for i: int in 3:
		_sphere(
			mesher,
			hide,
			Vector3(0.0, 0.74 + float(i) * 0.11, -0.2 + float(i) * 0.02),
			0.09 - float(i) * 0.008,
			Vector3(1.35, 0.5, 0.5),
			16,
			8,
		)
	# Back ridge spikes.
	for i: int in 5:
		var t: float = float(i) / 4.0
		var base := Vector3(0.0, 0.68 + t * 0.42, 0.19 + t * 0.02)
		_cone(
			mesher,
			bone,
			base + Vector3(0.0, 0.04, 0.06),
			0.034,
			0.19 - t * 0.04,
			Vector3(0.0, 0.5, 0.87),
		)

	# Neck and skull.
	_capsule(mesher, hide, Vector3(0.0, 1.12, -0.12), 0.08, 0.26, Vector3(-26.0, 0.0, 0.0))
	var head := Vector3(0.0, 1.22, -0.24)
	_sphere(mesher, shell, head, 0.17, Vector3(0.86, 0.82, 1.25))
	_sphere(mesher, hide, head + Vector3(0.0, -0.05, -0.21), 0.085, Vector3(0.9, 0.7, 1.1))
	_sphere(mesher, shell_dark, head + Vector3(0.0, 0.09, -0.06), 0.13, Vector3(1.05, 0.4, 0.9))
	# The hood: wide bone plates fanned out on both sides, and a swept crest.
	for side: float in [-1.0, 1.0]:
		_sphere(
			mesher,
			bone,
			head + Vector3(0.15 * side, 0.06, 0.04),
			0.12,
			Vector3(0.3, 1.0, 1.5),
			18,
			9,
		)
		_cone(
			mesher,
			bone,
			head + Vector3(0.17 * side, 0.12, 0.15),
			0.05,
			0.26,
			Vector3(0.3 * side, 0.35, 0.88),
		)
		_sphere(mesher, glow, head + Vector3(0.075 * side, 0.01, -0.19), 0.032, Vector3.ONE, 12, 6)
		# Fangs.
		_cone(
			mesher,
			bone,
			head + Vector3(0.05 * side, -0.1, -0.27),
			0.018,
			0.1,
			Vector3(0.0, -0.85, -0.5),
		)
	_cone(mesher, bone, head + Vector3(0.0, 0.17, 0.13), 0.06, 0.3, Vector3(0.0, 0.8, 0.6))

	# Scythe arms.
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(0.26 * side, 0.98, -0.04)
		var elbow := Vector3(0.4 * side, 0.76, -0.18)
		var wrist := Vector3(0.35 * side, 0.55, -0.32)
		_sphere(mesher, shell_dark, shoulder, 0.11, Vector3(1.0, 0.9, 1.0), 18, 9)
		_capsule(
			mesher,
			shell,
			(shoulder + elbow) * 0.5,
			0.06,
			shoulder.distance_to(elbow) + 0.05,
			Vector3.ZERO,
		)
		_capsule(
			mesher,
			shell_dark,
			(elbow + wrist) * 0.5,
			0.05,
			elbow.distance_to(wrist) + 0.05,
			Vector3.ZERO,
		)
		_sphere(mesher, hide, wrist, 0.055, Vector3.ONE, 14, 7)
		# The blade: two tapering segments curving forward.
		var blade_mid: Vector3 = wrist + Vector3(0.03 * side, -0.07, -0.26)
		var blade_tip: Vector3 = blade_mid + Vector3(-0.01 * side, -0.02, -0.3)
		_cone(
			mesher,
			bone,
			(wrist + blade_mid) * 0.5,
			0.05,
			wrist.distance_to(blade_mid) + 0.06,
			blade_mid - wrist,
		)
		_cone(
			mesher,
			bone,
			(blade_mid + blade_tip) * 0.5,
			0.038,
			blade_mid.distance_to(blade_tip) + 0.06,
			blade_tip - blade_mid,
		)


## Ragnos: a hunched horned brute with a bone-plated back, heavy clawed arms and
## a spiked tail. Broader and taller than the hydralisk.
static func _ragnos(mesher: PropMesher) -> void:
	var hide: StandardMaterial3D = _mat(Color("5a4034"), 0.88)
	var hide_light: StandardMaterial3D = _mat(Color("7a5a48"), 0.86)
	var hide_dark: StandardMaterial3D = _mat(Color("2f2320"), 0.9)
	var bone: StandardMaterial3D = _mat(Color("c0a67c"), 0.55)
	var glow: StandardMaterial3D = _mat(EYE_AMBER, 0.25, EYE_AMBER, 2.6)

	# Legs: planted wide, knees bent under the weight.
	for side: float in [-1.0, 1.0]:
		var ankle := Vector3(0.24 * side, 0.14, -0.02)
		var knee := Vector3(0.3 * side, 0.55, 0.12)
		var hip := Vector3(0.26 * side, 0.95, 0.02)
		_sphere(
			mesher,
			hide_dark,
			Vector3(0.24 * side, 0.09, -0.1),
			0.12,
			Vector3(1.15, 0.62, 1.7),
			16,
			8
		)
		_capsule(
			mesher, hide, (ankle + knee) * 0.5, 0.1, ankle.distance_to(knee) + 0.08, Vector3.ZERO
		)
		_capsule(mesher, hide, (knee + hip) * 0.5, 0.15, knee.distance_to(hip) + 0.1, Vector3.ZERO)
		_sphere(mesher, hide_light, knee, 0.12, Vector3.ONE, 16, 8)
		for k: int in 3:
			var offset: float = (float(k) - 1.0) * 0.06
			_cone(
				mesher,
				bone,
				Vector3(0.24 * side + offset, 0.04, -0.26),
				0.025,
				0.13,
				Vector3(offset, -0.25, -0.94),
			)

	# Pelvis and a chest that leans forward over it.
	_sphere(mesher, hide_dark, Vector3(0.0, 0.98, 0.02), 0.26, Vector3(1.1, 0.78, 0.92))
	_sphere(mesher, hide, Vector3(0.0, 1.3, -0.08), 0.34, Vector3(1.02, 0.94, 0.86))
	_sphere(mesher, hide_light, Vector3(0.0, 1.3, -0.3), 0.22, Vector3(1.0, 0.78, 0.6))
	# Ribbed belly plates.
	for i: int in 3:
		_sphere(
			mesher,
			hide_light,
			Vector3(0.0, 1.08 + float(i) * 0.1, -0.26 + float(i) * 0.02),
			0.115 - float(i) * 0.01,
			Vector3(1.35, 0.55, 0.5),
			16,
			8,
		)
	# The hump: a bone-plated back with spikes.
	for i: int in 4:
		var t: float = float(i) / 3.0
		_sphere(
			mesher,
			hide_dark,
			Vector3(0.0, 1.22 + t * 0.34, 0.2 + t * 0.02),
			0.17 - t * 0.03,
			Vector3(1.25, 0.65, 0.6),
			16,
			8,
		)
		_cone(
			mesher,
			bone,
			Vector3(0.0, 1.3 + t * 0.34, 0.32),
			0.038,
			0.2 - t * 0.04,
			Vector3(0.0, 0.68, 0.74),
		)
	# Heavy trapezius muscles under the head, so the neck is buried.
	for side: float in [-1.0, 1.0]:
		_sphere(mesher, hide, Vector3(0.22 * side, 1.48, -0.02), 0.19, Vector3(1.0, 0.8, 0.95))

	# Shoulders high, forearms thicker than the upper arms, fists with claws.
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(0.46 * side, 1.45, -0.02)
		var elbow := Vector3(0.64 * side, 1.12, 0.02)
		var wrist := Vector3(0.58 * side, 0.8, -0.2)
		_sphere(mesher, hide_dark, shoulder, 0.22, Vector3(1.05, 0.95, 1.0))
		_cone(
			mesher,
			bone,
			shoulder + Vector3(0.1 * side, 0.19, 0.02),
			0.045,
			0.18,
			Vector3(0.5 * side, 0.8, 0.25),
		)
		_capsule(
			mesher,
			hide,
			(shoulder + elbow) * 0.5,
			0.12,
			shoulder.distance_to(elbow) + 0.08,
			Vector3.ZERO
		)
		_capsule(
			mesher, hide, (elbow + wrist) * 0.5, 0.14, elbow.distance_to(wrist) + 0.08, Vector3.ZERO
		)
		_sphere(mesher, hide_light, elbow, 0.11, Vector3.ONE, 16, 8)
		_sphere(mesher, hide_light, wrist, 0.15, Vector3(1.0, 0.95, 1.1), 20, 10)
		for k: int in 3:
			var offset: float = (float(k) - 1.0) * 0.07
			_cone(
				mesher,
				bone,
				wrist + Vector3(offset, -0.05, -0.18),
				0.03,
				0.18,
				Vector3(offset, -0.35, -0.94),
			)

	# Head thrust forward below the shoulders, with a heavy brow and jaw.
	_capsule(mesher, hide, Vector3(0.0, 1.5, -0.22), 0.09, 0.16, Vector3(-55.0, 0.0, 0.0))
	var head := Vector3(0.0, 1.5, -0.38)
	_sphere(mesher, hide, head, 0.16, Vector3(0.98, 0.86, 1.12))
	_sphere(mesher, hide_dark, head + Vector3(0.0, 0.07, -0.04), 0.12, Vector3(1.15, 0.45, 0.8))
	_sphere(mesher, hide_light, head + Vector3(0.0, -0.06, -0.13), 0.1, Vector3(0.95, 0.7, 1.0))
	_sphere(mesher, hide_dark, head + Vector3(0.0, -0.1, -0.21), 0.065, Vector3(1.0, 0.5, 0.6))
	for side: float in [-1.0, 1.0]:
		_sphere(mesher, glow, head + Vector3(0.065 * side, 0.03, -0.14), 0.022, Vector3.ONE, 12, 6)
		_cone(
			mesher,
			bone,
			head + Vector3(0.05 * side, -0.08, -0.25),
			0.014,
			0.07,
			Vector3(0.1 * side, -0.75, -0.65),
		)
		# Horns curling up and back.
		var horn_base: Vector3 = head + Vector3(0.11 * side, 0.1, 0.02)
		var horn_mid: Vector3 = horn_base + Vector3(0.08 * side, 0.13, 0.06)
		var horn_tip: Vector3 = horn_mid + Vector3(0.03 * side, 0.11, 0.09)
		_cone(
			mesher,
			bone,
			(horn_base + horn_mid) * 0.5,
			0.045,
			horn_base.distance_to(horn_mid) + 0.05,
			horn_mid - horn_base,
		)
		_cone(
			mesher,
			bone,
			(horn_mid + horn_tip) * 0.5,
			0.03,
			horn_mid.distance_to(horn_tip) + 0.05,
			horn_tip - horn_mid,
		)

	# Tail with a bone spike at the end.
	var tail: Array[Vector3] = [
		Vector3(0.0, 0.92, 0.2),
		Vector3(0.03, 0.8, 0.44),
		Vector3(0.07, 0.64, 0.64),
		Vector3(0.11, 0.48, 0.76),
		Vector3(0.13, 0.36, 0.84),
	]
	for i: int in range(1, tail.size()):
		var from: Vector3 = tail[i - 1]
		var to: Vector3 = tail[i]
		var radius: float = 0.09 * (1.0 - float(i) / float(tail.size()))
		_capsule(mesher, hide, (from + to) * 0.5, radius, from.distance_to(to) + 0.05, Vector3.ZERO)
	_cone(
		mesher,
		bone,
		tail[tail.size() - 1] + Vector3(0.02, -0.06, 0.09),
		0.03,
		0.2,
		Vector3(0.0, -0.5, 0.86),
	)


## Zodd: a monstrous blood-red minotaur. Massive torso, hooves, a bull head with
## long horns and a slab of a back.
static func _zodd(mesher: PropMesher) -> void:
	var skin: StandardMaterial3D = _mat(Color("4e1a1e"), 0.84)
	var skin_light: StandardMaterial3D = _mat(Color("6e2626"), 0.82)
	var skin_dark: StandardMaterial3D = _mat(Color("241315"), 0.88)
	var horn: StandardMaterial3D = _mat(Color("cbb79a"), 0.5)
	var glow: StandardMaterial3D = _mat(Color("ffcf6a"), 0.25, Color("ff8a2a"), 2.6)

	# Hooves and powerful legs.
	for side: float in [-1.0, 1.0]:
		_sphere(
			mesher,
			horn,
			Vector3(0.26 * side, 0.09, -0.04),
			0.14,
			Vector3(1.05, 0.78, 1.5),
			16,
			8,
		)
		var ankle := Vector3(0.26 * side, 0.17, 0.0)
		var knee := Vector3(0.28 * side, 0.67, 0.1)
		var hip := Vector3(0.29 * side, 1.07, 0.02)
		_capsule(
			mesher,
			skin_dark,
			(ankle + knee) * 0.5,
			0.12,
			ankle.distance_to(knee) + 0.07,
			Vector3.ZERO
		)
		_capsule(mesher, skin, (knee + hip) * 0.5, 0.18, knee.distance_to(hip) + 0.1, Vector3.ZERO)
		_sphere(mesher, skin_light, knee, 0.15, Vector3(1.0, 1.1, 1.0))

	# Waist, slab of a torso, pectorals and abs.
	_sphere(mesher, skin_dark, Vector3(0.0, 1.09, 0.03), 0.31, Vector3(1.15, 0.78, 0.95))
	_sphere(mesher, skin, Vector3(0.0, 1.48, 0.0), 0.46, Vector3(1.06, 1.02, 0.86))
	for side: float in [-1.0, 1.0]:
		_sphere(
			mesher, skin_light, Vector3(0.21 * side, 1.63, -0.27), 0.24, Vector3(1.0, 0.72, 0.6)
		)
	for i: int in 3:
		for side: float in [-1.0, 1.0]:
			_sphere(
				mesher,
				skin_light,
				Vector3(0.12 * side, 1.29 - float(i) * 0.12, -0.37 + float(i) * 0.01),
				0.09,
				Vector3(0.9, 0.75, 0.4),
				16,
				8,
			)
	# Back: a ridge of bone spikes.
	for i: int in 5:
		var t: float = float(i) / 4.0
		_cone(
			mesher,
			horn,
			Vector3(0.0, 1.29 + t * 0.42, 0.29 + t * 0.02),
			0.048 - t * 0.01,
			0.22 - t * 0.04,
			Vector3(0.0, 0.7, 0.72),
		)

	# Shoulders, arms and fists.
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(0.52 * side, 1.76, 0.0)
		var elbow := Vector3(0.73 * side, 1.38, 0.03)
		var wrist := Vector3(0.69 * side, 1.0, -0.12)
		_sphere(mesher, skin_dark, shoulder, 0.25, Vector3(1.05, 0.95, 1.0))
		_capsule(
			mesher,
			skin,
			(shoulder + elbow) * 0.5,
			0.15,
			shoulder.distance_to(elbow) + 0.1,
			Vector3.ZERO
		)
		_capsule(
			mesher,
			skin_dark,
			(elbow + wrist) * 0.5,
			0.125,
			elbow.distance_to(wrist) + 0.08,
			Vector3.ZERO
		)
		_sphere(mesher, skin_light, wrist, 0.17, Vector3(1.0, 0.9, 1.1), 20, 10)
		for k: int in 3:
			var offset: float = (float(k) - 1.0) * 0.075
			_cone(
				mesher,
				horn,
				wrist + Vector3(offset, -0.06, -0.2),
				0.035,
				0.2,
				Vector3(offset, -0.3, -0.95),
			)
		_cone(
			mesher,
			horn,
			shoulder + Vector3(0.12 * side, 0.2, 0.04),
			0.05,
			0.2,
			Vector3(0.5 * side, 0.8, 0.3),
		)

	# Neck and bull head.
	_capsule(mesher, skin, Vector3(0.0, 1.92, -0.03), 0.17, 0.22, Vector3(16.0, 0.0, 0.0))
	var head := Vector3(0.0, 2.08, -0.12)
	_sphere(mesher, skin, head, 0.24, Vector3(0.94, 0.92, 1.1), 24, 12)
	# A heavy brow over the eyes.
	_sphere(mesher, skin_dark, head + Vector3(0.0, 0.1, -0.14), 0.17, Vector3(1.05, 0.45, 0.7))
	# Muzzle pushed forward so the bull face reads at a glance.
	_sphere(mesher, skin_light, head + Vector3(0.0, -0.09, -0.28), 0.16, Vector3(0.95, 0.8, 1.25))
	_sphere(mesher, skin_dark, head + Vector3(0.0, -0.19, -0.4), 0.09, Vector3(1.15, 0.45, 0.6))
	for side: float in [-1.0, 1.0]:
		_sphere(
			mesher,
			skin_dark,
			head + Vector3(0.06 * side, -0.13, -0.45),
			0.03,
			Vector3.ONE,
			12,
			6,
		)
		_cone(
			mesher,
			skin_light,
			head + Vector3(0.22 * side, 0.05, 0.02),
			0.07,
			0.14,
			Vector3(0.9 * side, 0.35, 0.2),
		)
		_sphere(mesher, glow, head + Vector3(0.09 * side, 0.02, -0.22), 0.03, Vector3.ONE, 12, 6)
		# Long horns sweeping out, up and slightly forward.
		var horn_base: Vector3 = head + Vector3(0.16 * side, 0.13, 0.0)
		var horn_mid: Vector3 = horn_base + Vector3(0.17 * side, 0.07, -0.04)
		var horn_tip: Vector3 = horn_mid + Vector3(0.09 * side, 0.14, -0.07)
		_cone(
			mesher,
			horn,
			(horn_base + horn_mid) * 0.5,
			0.075,
			horn_base.distance_to(horn_mid) + 0.06,
			horn_mid - horn_base,
		)
		_cone(
			mesher,
			horn,
			(horn_mid + horn_tip) * 0.5,
			0.05,
			horn_mid.distance_to(horn_tip) + 0.06,
			horn_tip - horn_mid,
		)
	# A shaggy mane around the neck, kept off the face.
	for k: int in 14:
		var around: float = TAU * float(k) / 14.0
		var sideways: float = cos(around) * 0.9
		var backward: float = sin(around) * 0.7
		if backward < -0.25:
			continue
		var dir := Vector3(sideways, -0.15, backward).normalized()
		var base: Vector3 = head + Vector3(0.0, -0.2, 0.02) + dir * 0.22
		_cone(mesher, skin_dark, base, 0.035, 0.22, dir)

	# Tail.
	var tail: Array[Vector3] = [
		Vector3(0.0, 1.02, 0.28),
		Vector3(0.04, 0.86, 0.55),
		Vector3(0.09, 0.68, 0.76),
		Vector3(0.13, 0.52, 0.9),
	]
	for i: int in range(1, tail.size()):
		var from: Vector3 = tail[i - 1]
		var to: Vector3 = tail[i]
		_capsule(
			mesher,
			skin,
			(from + to) * 0.5,
			0.1 * (1.0 - float(i) / float(tail.size())),
			from.distance_to(to) + 0.05,
			Vector3.ZERO,
		)
	_cone(
		mesher,
		skin_dark,
		tail[tail.size() - 1] + Vector3(0.02, -0.03, 0.12),
		0.07,
		0.24,
		Vector3(0.0, -0.3, 0.95),
	)


# ---------------------------------------------------------------- primitives


static func _sphere(
	mesher: PropMesher,
	material: StandardMaterial3D,
	position: Vector3,
	radius: float,
	scale: Vector3 = Vector3.ONE,
	segments: int = 24,
	rings: int = 12
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mesher.add_at(mesh, position, material, Vector3.ZERO, scale)


static func _capsule(
	mesher: PropMesher,
	material: StandardMaterial3D,
	position: Vector3,
	radius: float,
	height: float,
	rotation_deg: Vector3
) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.001)
	mesh.radial_segments = 18
	mesh.rings = 6
	mesher.add_at(mesh, position, material, rotation_deg)


## A cone whose base is at `position - direction * height * 0.5`.
static func _cone(
	mesher: PropMesher,
	material: StandardMaterial3D,
	position: Vector3,
	radius: float,
	height: float,
	direction: Vector3
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesher.add_along(mesh, position, direction, material)


static func _mat(
	color: Color, roughness: float = 0.85, emission: Color = Color.BLACK, energy: float = 0.0
) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%s|%.2f" % [color.to_html(), roughness, emission.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	_mat_cache[key] = material
	return material
