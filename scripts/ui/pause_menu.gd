class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal menu_requested

@onready var _overlay: Control = %Overlay
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_overlay.visible = false
	_resume_button.pressed.connect(_on_resume)
	_menu_button.pressed.connect(_on_menu)


func open() -> void:
	_overlay.visible = true
	_resume_button.grab_focus()


func close() -> void:
	_overlay.visible = false
	get_viewport().gui_release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_on_resume()
		get_viewport().set_input_as_handled()


func _on_resume() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	resume_requested.emit()


func _on_menu() -> void:
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	menu_requested.emit()
