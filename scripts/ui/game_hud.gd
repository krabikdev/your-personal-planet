class_name GameHUD
extends CanvasLayer

## In-game HUD: planet vitals, the inventory button, the debris warning and
## contextual prompts. Everything is driven by game.gd through plain methods.

signal inventory_requested

var _toast_tween: Tween
var _warning_tween: Tween
var _intro_tween: Tween

@onready var _diameter_label: Label = %DiameterLabel
@onready var _gravity_label: Label = %GravityLabel
@onready var _jump_label: Label = %JumpLabel
@onready var _safety_label: Label = %SafetyLabel
@onready var _inventory_button: Button = %InventoryButton
@onready var _warning_label: Label = %WarningLabel
@onready var _toast_label: Label = %ToastLabel
@onready var _cold_label: Label = %ColdLabel
@onready var _intro_panel: Control = %IntroPanel
@onready var _controls_label: Label = %ControlsLabel


func _ready() -> void:
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_warning_label.visible = false
	_cold_label.visible = false
	_toast_label.modulate.a = 0.0
	_intro_panel.visible = false
	_controls_label.modulate.a = 0.8
	_populate_controls()


func _on_inventory_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, -3.0)
	inventory_requested.emit()


func set_planet_stats(radius: float, gravity: float, jump_height: float, safe: bool) -> void:
	_diameter_label.text = "%.1f" % PlanetProfile.diameter_in_boys(radius)
	_gravity_label.text = "Гравітація  %.1f" % gravity
	_jump_label.text = "Стрибок  %.1f м" % jump_height
	if safe:
		_safety_label.text = "безпечний стрибок"
		_safety_label.add_theme_color_override("font_color", Color("8fb3ad"))
	else:
		_safety_label.text = "небезпечний стрибок"
		_safety_label.add_theme_color_override("font_color", Color("e8ae86"))


func set_inventory_count(count: int) -> void:
	_inventory_button.text = "I   ·   Сумка  %d" % count


func show_toast(text: String, color: Color = Color("f3e7d3"), seconds: float = 3.2) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.22)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.7)
	_toast_tween.tween_callback(func() -> void: _toast_label.visible = false)


func show_warning(kind: int) -> void:
	var text: String = "Крига летить повз планету"
	var color := Color("a9d7d6")
	if kind == StoneItem.Kind.ROCK:
		text = "Камінь летить повз планету"
		color = Color("e8ae86")
	_warning_label.text = text + "\nдивись у небо і готуйся"
	_warning_label.add_theme_color_override("font_color", color)
	_warning_label.visible = true
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_label.modulate.a = 0.45
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.85)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.45, 0.85)


func hide_warning() -> void:
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_label.visible = false


func set_cold(amount: float) -> void:
	var value: float = clampf(amount, 0.0, 1.0)
	_cold_label.visible = value > 0.04
	_cold_label.modulate.a = clampf(value * 1.6, 0.0, 1.0)
	if value > 0.75:
		_cold_label.text = "Ти замерзаєш..."
	else:
		_cold_label.text = "Холод тягне тебе в темряву"


func show_intro() -> void:
	_intro_panel.visible = true
	_intro_panel.modulate.a = 0.0
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro_panel, "modulate:a", 1.0, 0.8)
	_intro_tween.tween_interval(8.5)
	_intro_tween.tween_property(_intro_panel, "modulate:a", 0.0, 1.0)
	_intro_tween.tween_callback(func() -> void: _intro_panel.visible = false)


func hide_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_panel.visible = false


func set_dead() -> void:
	hide_warning()
	_cold_label.visible = false
	_controls_label.visible = false
	_inventory_button.disabled = true
	_intro_panel.visible = false


func fade_controls() -> void:
	if _controls_label == null:
		return
	var tween := create_tween()
	tween.tween_interval(16.0)
	tween.tween_property(_controls_label, "modulate:a", 0.0, 2.0)


func _populate_controls() -> void:
	_controls_label.text = (
		"WASD  рух     ·     Shift  біг     ·     Пробіл  стрибок     ·     "
		+ "Q  кілок     ·     ЛКМ  сачок     ·     I  сумка     ·     Миша  поворот камери"
	)
