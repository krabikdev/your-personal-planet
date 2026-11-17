class_name InventoryUI
extends CanvasLayer

## The bag. Opens over a paused game, lists every caught stone and turns one
## into a single "smear it into the planet" action.

signal use_requested(index: int)
signal closed

var _items: Array[StoneItem] = []
var _selected: int = -1
var _planet_radius: float = PlanetProfile.BASE_RADIUS
var _group: ButtonGroup
var _cards: Array[Button] = []

@onready var _overlay: Control = %Overlay
@onready var _grid: HFlowContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _selection_panel: PanelContainer = %SelectionPanel
@onready var _preview: StoneIcon = %Preview
@onready var _item_name: Label = %ItemName
@onready var _item_size: Label = %ItemSize
@onready var _item_growth: Label = %ItemGrowth
@onready var _item_flavor: Label = %ItemFlavor
@onready var _use_button: Button = %UseButton
@onready var _close_button: Button = %CloseButton
@onready var _count_label: Label = %CountLabel


func _ready() -> void:
	_overlay.visible = false
	_group = ButtonGroup.new()
	_group.allow_unpress = false
	_use_button.pressed.connect(_on_use_pressed)
	_close_button.pressed.connect(close)
	_use_button.disabled = true


func open(items: Array[StoneItem], planet_radius: float) -> void:
	_items.clear()
	for item: StoneItem in items:
		_items.append(item)
	_planet_radius = planet_radius
	_selected = 0 if not _items.is_empty() else -1
	_populate()
	_refresh()
	_overlay.visible = true
	if not _items.is_empty() and not _cards.is_empty():
		_cards[0].button_pressed = true
	AudioDirector.play_sfx("ui_click", 0.02, -2.0)


func close() -> void:
	if not _overlay.visible:
		return
	_overlay.visible = false
	get_viewport().gui_release_focus()
	AudioDirector.play_sfx("ui_click", 0.02, -2.0)
	closed.emit()


func is_open() -> bool:
	return _overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _populate() -> void:
	for card: Button in _cards:
		card.queue_free()
	_cards.clear()
	for i: int in _items.size():
		var card: Button = _make_card(_items[i], i)
		_grid.add_child(card)
		_cards.append(card)


func _make_card(item: StoneItem, index: int) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"Card"
	card.toggle_mode = true
	card.button_group = _group
	card.custom_minimum_size = Vector2(112, 138)
	card.tooltip_text = "%s · %s" % [item.display_name(), item.size_label()]
	card.pressed.connect(_on_card_pressed.bind(index))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon := StoneIcon.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(item, 1.0)
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.display_name()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var size_label := Label.new()
	size_label.text = "%.1f ×" % item.size_factor
	size_label.theme_type_variation = &"SmallLabel"
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(size_label)
	return card


func _on_card_pressed(index: int) -> void:
	_selected = index
	AudioDirector.play_sfx("ui_click", 0.02, -4.0)
	_refresh_details()


func _refresh() -> void:
	_empty_label.visible = _items.is_empty()
	_grid.visible = not _items.is_empty()
	_selection_panel.visible = not _items.is_empty() and _selected >= 0
	_count_label.text = _findings_text(_items.size())
	if _items.is_empty():
		_count_label.text = "порожньо"
		_use_button.disabled = true
		return
	_refresh_details()


func _findings_text(count: int) -> String:
	var last: int = count % 10
	var last_two: int = count % 100
	if last == 1 and last_two != 11:
		return "%d знахідка" % count
	if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14):
		return "%d знахідки" % count
	return "%d знахідок" % count


func _refresh_details() -> void:
	if _selected < 0 or _selected >= _items.size():
		_use_button.disabled = true
		return
	var item: StoneItem = _items[_selected]
	_preview.setup(item, 1.7)
	_item_name.text = "%s з орбіти" % item.display_name()
	_item_size.text = "%.1f × зросту хлопчика" % item.size_factor
	var growth: float = PlanetProfile.growth_for_stone(_planet_radius, item.size_factor)
	_item_growth.text = "Додасть планеті +%.1f м радіуса" % growth
	if item.is_ice():
		_item_flavor.text = (
			"Крига, що пам'ятає холод порожнечі. "
			+ "Пальці ломить, але вона гарна — як скло далекої зорі."
		)
	else:
		_item_flavor.text = (
			"Теплий камінь з орбіти. Пахне пилом і далекими мандрами. "
			+ "Його можна вмазати в землю — і планета стане трохи більшою."
		)
	_use_button.disabled = false


func _on_use_pressed() -> void:
	if _selected < 0 or _selected >= _items.size():
		return
	AudioDirector.play_sfx("ui_click", 0.02, 0.0)
	use_requested.emit(_selected)
