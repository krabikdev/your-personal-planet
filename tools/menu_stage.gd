extends Node

## Development staging for the menu screenshots.

@onready var menu: Control = $MainMenu


func _ready() -> void:
	await get_tree().create_timer(1.6).timeout
	var panel: SettingsPanel = menu.get_node("%SettingsPanel") as SettingsPanel
	panel.open()
