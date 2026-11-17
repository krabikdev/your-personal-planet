class_name GameOverUI
extends CanvasLayer

## Cold, quiet game-over card with the two ways out.

signal restart_requested
signal menu_requested

var _tween: Tween

@onready var _overlay: Control = %Overlay
@onready var _panel: PanelContainer = %Panel
@onready var _stats_label: Label = %StatsLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_overlay.visible = false
	_restart_button.pressed.connect(_on_restart)
	_menu_button.pressed.connect(_on_menu)


func open(planet_radius: float, stones_used: int) -> void:
	_overlay.visible = true
	_stats_label.text = (
		"Планета: %.1f\nВмазано каміння: %d"
		% [PlanetProfile.diameter_in_boys(planet_radius), stones_used]
	)
	_overlay.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_overlay, "modulate:a", 1.0, 0.9)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK)
	_restart_button.grab_focus()


func _on_restart() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	restart_requested.emit()


func _on_menu() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	menu_requested.emit()
