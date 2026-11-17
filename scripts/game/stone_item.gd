class_name StoneItem
extends RefCounted

## One piece of space debris that has been caught and now sits in the bag.

enum Kind { ROCK, ICE }

var kind: Kind
var size_factor: float
var shape_seed: int


func _init(p_kind: Kind = Kind.ROCK, p_size: float = 1.0, p_seed: int = 0) -> void:
	kind = p_kind
	size_factor = clampf(p_size, 0.35, 2.0)
	shape_seed = p_seed


func display_name() -> String:
	if kind == Kind.ICE:
		return "Лід"
	return "Камінь"


func size_label() -> String:
	return "%.1f × хлопчик" % size_factor


func growth_value() -> float:
	return pow(size_factor, 1.5)


func is_ice() -> bool:
	return kind == Kind.ICE


func accent_color() -> Color:
	if kind == Kind.ICE:
		return Color("a9d7d6")
	return Color("d8a184")
