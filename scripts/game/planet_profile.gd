class_name PlanetProfile
extends RefCounted

## Pure tuning maths for the little planet. No nodes, no side effects, so the
## growth curve, gravity and jump feel can be unit tested headlessly.

const BASE_RADIUS: float = 5.0
const BASE_GRAVITY: float = 3.0
## Gravity stops climbing here. Past this point a bigger world only looks
## heavier: it must not turn the boy's jump into a drop and his landing into a
## wall.
const MAX_GRAVITY: float = 12.0
const GRAVITY_EXPONENT: float = 1.6
const JUMP_BASE_SPEED: float = 14.0
const JUMP_MIN_HEIGHT: float = 1.0
const JUMP_END_RADIUS: float = 1000.0
const GROWTH_GAIN: float = 0.775
const GROWTH_FALLOFF: float = 0.9
const MIN_GROWTH: float = 0.18
const MAX_RADIUS: float = 140.0
const SAFE_MARGIN: float = 0.985


static func surface_gravity(radius: float) -> float:
	var r: float = clampf(radius, 1.0, MAX_RADIUS)
	return minf(BASE_GRAVITY * pow(r / BASE_RADIUS, GRAVITY_EXPONENT), MAX_GRAVITY)


static func gravity_at(radius: float, distance: float) -> float:
	var d: float = maxf(distance, 0.5)
	return surface_gravity(radius) * pow(radius / d, 2.0)


static func escape_velocity(radius: float) -> float:
	return sqrt(2.0 * surface_gravity(radius) * radius)


static func jump_speed(radius: float) -> float:
	return sqrt(2.0 * surface_gravity(radius) * jump_height(radius))


static func base_jump_height() -> float:
	return pow(JUMP_BASE_SPEED, 2.0) / (2.0 * BASE_GRAVITY)


static func jump_height(radius: float) -> float:
	# The jump fades far more gently than gravity grows: a heavy planet still
	# lets the boy hop, and the curve settles on one boy height at JUMP_END_RADIUS.
	var base: float = base_jump_height()
	var r: float = clampf(radius, BASE_RADIUS, JUMP_END_RADIUS)
	var progress: float = log(r / BASE_RADIUS) / log(JUMP_END_RADIUS / BASE_RADIUS)
	return base * pow(JUMP_MIN_HEIGHT / base, progress)


static func growth_for_stone(radius: float, size_factor: float) -> float:
	var size: float = clampf(size_factor, 0.35, 2.0)
	var scaled: float = GROWTH_GAIN * pow(size, 1.5)
	var falloff: float = pow(BASE_RADIUS / maxf(radius, 1.0), GROWTH_FALLOFF)
	var room: float = MAX_RADIUS - radius
	return clampf(scaled * falloff, MIN_GROWTH, maxf(MIN_GROWTH, room))


static func diameter_in_boys(radius: float) -> float:
	return radius * 2.0


static func is_jump_safe(radius: float) -> bool:
	return jump_speed(radius) < escape_velocity(radius) * SAFE_MARGIN


static func safe_radius() -> float:
	var low: float = BASE_RADIUS
	var high: float = MAX_RADIUS
	for _step: int in 60:
		var mid: float = (low + high) * 0.5
		if is_jump_safe(mid):
			high = mid
		else:
			low = mid
	return high


static func cold_altitude(radius: float) -> float:
	return maxf(6.0, radius * 1.2)


static func death_altitude(radius: float) -> float:
	return maxf(24.0, radius * 2.6)
