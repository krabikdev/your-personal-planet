class_name DebugPanel
extends CanvasLayer

## Developer overlay for fast playtesting: planet size, simulation speed, cold,
## debris and a couple of cheats. Categories are declared as data and the rows
## are built from containers, so adding a button is one dictionary entry.
##
## The panel itself knows nothing about the game. It emits what was pressed and
## the game decides what that means.

signal action_requested(action: StringName, value: float)

const FONT_SIZE: int = 12
const BUTTON_FONT_SIZE: int = 11
const TITLE_SIZE: int = 14
const BUTTON_MIN_SIZE := Vector2(34.0, 22.0)
const VALUE_MIN_WIDTH: float = 58.0
const TITLE_COLOR := Color("d8b37d")
const VALUE_COLOR := Color("b9cdb4")

const SECTIONS: Array = [
	{
		"title": "Планета",
		"rows":
		[
			{
				"label": "Розмір",
				"stat": &"radius",
				"buttons":
				[
					{"text": "+1", "action": &"planet_add", "value": 1.0},
					{"text": "+10", "action": &"planet_add", "value": 10.0},
					{"text": "+100", "action": &"planet_add", "value": 100.0},
					{"text": "5", "action": &"planet_set", "value": 5.0},
				],
			},
		],
	},
	{
		"title": "Час симуляції",
		"rows":
		[
			{
				"label": "Швидкість",
				"stat": &"time",
				"buttons":
				[
					{"text": "0.5×", "action": &"time_scale", "value": 0.5},
					{"text": "1×", "action": &"time_scale", "value": 1.0},
					{"text": "2×", "action": &"time_scale", "value": 2.0},
					{"text": "4×", "action": &"time_scale", "value": 4.0},
				],
			},
		],
	},
	{
		"title": "Гравець",
		"rows":
		[
			{
				"label": "Холод",
				"stat": &"cold",
				"buttons":
				[
					{"text": "0%", "action": &"cold_set", "value": 0.0},
					{"text": "50%", "action": &"cold_set", "value": 0.5},
					{"text": "100%", "action": &"cold_set", "value": 1.0},
				],
			},
			{
				"label": "Стрибок",
				"buttons":
				[
					{"text": "Підкинути", "action": &"jump", "value": 1.0},
				],
			},
		],
	},
	{
		"title": "Уламки та сумка",
		"rows":
		[
			{
				"label": "Уламок",
				"buttons":
				[
					{"text": "Зараз", "action": &"debris", "value": 1.0},
				],
			},
			{
				"label": "Камінь",
				"stat": &"stones",
				"buttons":
				[
					{"text": "Камінь", "action": &"stone_rock", "value": 1.0},
					{"text": "Лід", "action": &"stone_ice", "value": 1.0},
				],
			},
		],
	},
]

var _stats: Dictionary[StringName, Label] = {}

@onready var _panel: PanelContainer = %Panel
@onready var _sections: VBoxContainer = %Sections


func _ready() -> void:
	visible = false
	_build()


func is_open() -> bool:
	return visible


func set_open(value: bool) -> void:
	visible = value


func toggle() -> void:
	set_open(not visible)


func refresh(values: Dictionary) -> void:
	for key: StringName in values:
		var label: Label = _stats.get(key)
		if label != null:
			label.text = str(values[key])


func _build() -> void:
	for section: Dictionary in SECTIONS:
		_add_section(section)


func _add_section(section: Dictionary) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = section["title"]
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	block.add_child(title)

	for row: Dictionary in section["rows"]:
		block.add_child(_build_row(row))

	_sections.add_child(block)


func _build_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = row["label"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	line.add_child(label)

	var stat: StringName = row.get("stat", &"")
	if stat != &"":
		var value := Label.new()
		value.text = "—"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(VALUE_MIN_WIDTH, 0.0)
		value.add_theme_font_size_override("font_size", FONT_SIZE)
		value.add_theme_color_override("font_color", VALUE_COLOR)
		_stats[stat] = value
		line.add_child(value)

	for button: Dictionary in row["buttons"]:
		line.add_child(_build_button(button))

	return line


func _build_button(button: Dictionary) -> Button:
	var node := Button.new()
	node.text = button["text"]
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = BUTTON_MIN_SIZE
	node.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	node.pressed.connect(_on_pressed.bind(button["action"], button["value"]))
	return node


func _on_pressed(action: StringName, value: float) -> void:
	action_requested.emit(action, value)
