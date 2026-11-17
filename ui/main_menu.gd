extends Control

## Main menu. Buttons, an audio settings overlay and a soft fade into the game.

var _starting: bool = false
var _fade_tween: Tween

@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _fade: ColorRect = %Fade
@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	AudioDirector.play_music()
	_title_label.text = "Твоя особиста планета"
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	for button: Button in [_start_button, _settings_button, _quit_button]:
		button.mouse_entered.connect(_play_hover)
	_fade.color = Color(0.02, 0.02, 0.04, 1.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, 1.4)
	_fade_tween.tween_callback(func() -> void: _fade.visible = false)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	_set_buttons_enabled(false)
	_fade.visible = true
	_fade.color.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, 0.65)
	_fade_tween.tween_callback(_enter_game)


func _enter_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_settings_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	_set_buttons_enabled(false)
	_settings_panel.open()


func _on_settings_closed() -> void:
	_set_buttons_enabled(true)
	_start_button.grab_focus()


func _on_quit_pressed() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	get_tree().quit()


func _set_buttons_enabled(value: bool) -> void:
	_start_button.disabled = not value
	_settings_button.disabled = not value
	_quit_button.disabled = not value


func _play_hover() -> void:
	AudioDirector.play_sfx("ui_click", 0.04, -14.0)
