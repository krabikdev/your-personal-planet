class_name InventoryModel
extends RefCounted

## Plain data model for the boy's bag. The UI never mutates it directly.
## The watering can is a bag item; the water inside it lives here, because it
## is a single number no matter how many finds are lying next to it.

signal changed

var items: Array[StoneItem] = []
## How much water the can holds. There is no upper limit: ice keeps melting.
var water: float = 0.0


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


func has_watering_can() -> bool:
	for item: StoneItem in items:
		if item != null and item.kind == StoneItem.Kind.WATERING_CAN:
			return true
	return false


## Melting ice pours into the can. The can itself is never full.
func add_water(amount: float) -> void:
	if amount <= 0.0:
		return
	water += amount
	changed.emit()


## Takes at most what is left and returns what was actually spent.
func spend_water(amount: float) -> float:
	var spent: float = minf(maxf(amount, 0.0), water)
	if spent <= 0.0:
		return 0.0
	water -= spent
	changed.emit()
	return spent
