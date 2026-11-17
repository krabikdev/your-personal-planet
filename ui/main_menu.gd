extends Control

## Main menu smoke test: proves the container-based layout and signal wiring work.
## Replace the button handlers with real scene transitions when gameplay lands.

@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	print("Main menu: Start Game pressed")


func _on_settings_pressed() -> void:
	print("Main menu: Settings pressed")


func _on_quit_pressed() -> void:
	print("Main menu: Quit pressed")
	get_tree().quit()
