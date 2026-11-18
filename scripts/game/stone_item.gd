class_name StoneItem
extends RefCounted

## One piece of space debris that has been caught and now sits in the bag.

enum Kind { ROCK, ICE, WATERING_CAN }

var kind: Kind
var size_factor: float
var shape_seed: int


func _init(p_kind: Kind = Kind.ROCK, p_size: float = 1.0, p_seed: int = 0) -> void:
	kind = p_kind
	size_factor = clampf(p_size, 0.35, 2.0)
	shape_seed = p_seed


func is_stone() -> bool:
	return kind == Kind.ROCK or kind == Kind.ICE


func display_name() -> String:
	match kind:
		Kind.ICE:
			return "Лід"
		Kind.WATERING_CAN:
			return "Поливалка"
		_:
			return "Камінь"


func size_label() -> String:
	if not is_stone():
		return "знахідка"
	return "%.1f × хлопчик" % size_factor


func growth_value() -> float:
	if not is_stone():
		return 0.0
	return pow(size_factor, 1.5)


func is_ice() -> bool:
	return kind == Kind.ICE


## Ice no longer feeds the planet: it melts into that much water for the can.
func melt_value() -> float:
	if not is_ice():
		return 0.0
	return size_factor


func accent_color() -> Color:
	match kind:
		Kind.ICE:
			return Color("a9d7d6")
		Kind.WATERING_CAN:
			return Color("93b4a8")
		_:
			return Color("d8a184")
