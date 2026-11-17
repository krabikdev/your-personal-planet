class_name StoneIcon
extends Control

## Tiny hand-drawn icon for one inventory stone. The shape is derived from the
## item's seed, so every rock in the bag looks different.

var _stone: StoneItem
var _scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(stone: StoneItem, icon_scale: float = 1.0) -> void:
	_stone = stone
	_scale = clampf(icon_scale, 0.5, 2.5)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.30 * _scale
	if _stone == null:
		draw_arc(center, radius, 0.0, TAU, 28, Color(0.72, 0.66, 0.68, 0.35), 1.5, true)
		draw_circle(center, radius * 0.12, Color(0.72, 0.66, 0.68, 0.18))
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _stone.shape_seed
	var count: int = 7 if not _stone.is_ice() else 6
	var points := PackedVector2Array()
	for i: int in count:
		var angle: float = TAU * float(i) / float(count) - PI * 0.5
		var wobble: float = rng.randf_range(0.72, 1.10)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	var closed := points.duplicate()
	closed.append(points[0])

	draw_circle(center + Vector2(0.0, radius * 0.16), radius * 1.16, Color(0.0, 0.0, 0.0, 0.22))

	var base: Color
	var facet: Color
	var rim: Color
	if _stone.is_ice():
		base = Color(0.48, 0.74, 0.76, 0.92)
		facet = Color(0.78, 0.94, 0.95, 0.95)
		rim = Color(0.88, 0.99, 1.0, 0.95)
	else:
		base = Color(0.46, 0.39, 0.38, 0.98)
		facet = Color(0.63, 0.53, 0.49, 0.95)
		rim = Color(0.86, 0.62, 0.51, 0.85)

	draw_colored_polygon(points, base)

	var facet_points := PackedVector2Array()
	for i: int in points.size():
		facet_points.append(center + (points[i] - center) * 0.68 + Vector2(0.0, -radius * 0.16))
	draw_colored_polygon(facet_points, facet)
	draw_polyline(closed, rim, 2.0, true)

	if _stone.is_ice():
		for i: int in 3:
			var target: Vector2 = points[rng.randi_range(0, points.size() - 1)]
			draw_line(center, target, Color(0.92, 1.0, 1.0, 0.55), 1.2, true)
		draw_circle(
			center + Vector2(radius * 0.25, -radius * 0.30), radius * 0.10, Color(1, 1, 1, 0.9)
		)
	else:
		var crack_from: Vector2 = points[rng.randi_range(0, points.size() - 1)]
		var crack_to: Vector2 = points[rng.randi_range(0, points.size() - 1)]
		draw_line(crack_from, crack_to, Color(0.20, 0.16, 0.18, 0.35), 1.0, true)
