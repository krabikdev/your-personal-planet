class_name SettingsPanel
extends Control

## Settings overlay used by the main menu. Only audio for now, but the layout
## is ready for more sections.

signal closed

@onready var _overlay: Control = %Overlay
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	# The panel spans the whole screen; when closed it must not swallow clicks
	# meant for the menu buttons underneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_back_button.pressed.connect(close)
	_sync_values()


func open() -> void:
	_sync_values()
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.22)
	_back_button.grab_focus()


func close() -> void:
	if not _overlay.visible:
		return
	_overlay.visible = false
	get_viewport().gui_release_focus()
	AudioDirector.play_sfx("ui_click", 0.02, -2.0)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _sync_values() -> void:
	_music_slider.set_value_no_signal(AudioDirector.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(AudioDirector.sfx_volume * 100.0)
	_music_value.text = "%d%%" % roundi(AudioDirector.music_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(AudioDirector.sfx_volume * 100.0)


func _on_music_changed(value: float) -> void:
	AudioDirector.set_music_volume(value / 100.0)
	_music_value.text = "%d%%" % roundi(value)


func _on_sfx_changed(value: float) -> void:
	AudioDirector.set_sfx_volume(value / 100.0)
	_sfx_value.text = "%d%%" % roundi(value)
