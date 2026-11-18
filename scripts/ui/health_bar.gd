class_name HealthBar
extends Control

## The duke's health, drawn by hand so the frame, the gloss and the number all
## share the game's palette: sage while safe, peach when hurt, red when nearly
## gone. It reads the theme for its font, so it stays in step with the rest of
## the UI.

const TRACK_COLOR := Color("171425")
const EDGE_COLOR := Color("6c5a6b")
const HIGH_COLOR := Color("8fb3ad")
const MID_COLOR := Color("e8ae86")
const LOW_COLOR := Color("d98a8a")

var _value: float = 100.0
var _maximum: float = 100.0
var _shown: float = 1.0
var _frame: StyleBoxFlat
var _fill: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(TRACK_COLOR.r, TRACK_COLOR.g, TRACK_COLOR.b, 0.92)
	_frame.border_color = EDGE_COLOR
	_frame.set_border_width_all(2)
	_frame.set_corner_radius_all(9)
	_frame.anti_aliasing = true
	_fill = StyleBoxFlat.new()
	_fill.bg_color = HIGH_COLOR
	_fill.set_corner_radius_all(7)
	_fill.anti_aliasing = true


func set_value(current: float, maximum: float) -> void:
	_maximum = maxf(maximum, 1.0)
	_value = clampf(current, 0.0, _maximum)
	queue_redraw()


func get_value() -> float:
	return _value


func get_maximum() -> float:
	return _maximum


func _process(delta: float) -> void:
	var target: float = _value / _maximum
	if is_equal_approx(_shown, target):
		return
	_shown = move_toward(_shown, target, maxf(delta * 1.8, 0.002))
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	draw_style_box(_frame, rect)
	var inner := rect.grow(-4.0)
	var ratio: float = clampf(_shown, 0.0, 1.0)
	if ratio > 0.002:
		_fill.bg_color = _fill_color(ratio)
		draw_style_box(_fill, Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)))
		var gloss := Rect2(
			inner.position + Vector2(2.0, 1.0),
			Vector2(maxf(inner.size.x * ratio - 4.0, 1.0), inner.size.y * 0.38)
		)
		draw_rect(gloss, Color(1.0, 1.0, 1.0, 0.09))
	for i: int in [1, 2, 3]:
		var x: float = inner.position.x + inner.size.x * 0.25 * float(i)
		draw_line(
			Vector2(x, inner.position.y + 1.0),
			Vector2(x, inner.position.y + inner.size.y - 1.0),
			Color(0.0, 0.0, 0.0, 0.22),
			1.0
		)
	var font: Font = get_theme_font("font", "Label")
	if font == null:
		return
	var font_size: int = get_theme_font_size("font_size", "SmallLabel")
	var color: Color = get_theme_color("font_color", "Label")
	var text: String = "%d / %d" % [ceili(_value), int(round(_maximum))]
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = size.y * 0.5 + float(font_size) * 0.36
	draw_string(
		font,
		Vector2((size.x - width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _fill_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HIGH_COLOR
	if ratio > 0.25:
		return MID_COLOR
	return LOW_COLOR
