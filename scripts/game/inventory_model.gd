class_name InventoryModel
extends RefCounted

## Plain data model for the boy's bag. The UI never mutates it directly.

signal changed

var items: Array[StoneItem] = []


func add(stone: StoneItem) -> void:
	items.append(stone)
	changed.emit()


func remove_at(index: int) -> StoneItem:
	if index < 0 or index >= items.size():
		return null
	var stone: StoneItem = items[index]
	items.remove_at(index)
	changed.emit()
	return stone


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()
