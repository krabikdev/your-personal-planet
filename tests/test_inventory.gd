extends GutTest

const START_RADIUS: float = PlanetProfile.BASE_RADIUS


func test_stone_metadata() -> void:
	var rock := StoneItem.new(StoneItem.Kind.ROCK, 1.2, 99)
	assert_eq(rock.display_name(), "Камінь")
	assert_eq(rock.size_label(), "1.2 × хлопчик")
	assert_false(rock.is_ice())

	var ice := StoneItem.new(StoneItem.Kind.ICE, 0.7, 12)
	assert_eq(ice.display_name(), "Лід")
	assert_true(ice.is_ice())
	assert_eq(ice.accent_color(), Color("a9d7d6"))


func test_stone_size_is_clamped() -> void:
	var tiny := StoneItem.new(StoneItem.Kind.ROCK, 0.01, 1)
	var huge := StoneItem.new(StoneItem.Kind.ROCK, 9.0, 1)
	assert_eq(tiny.size_factor, 0.35)
	assert_eq(huge.size_factor, 2.0)


func test_inventory_add_and_remove() -> void:
	var inventory := InventoryModel.new()
	var first := StoneItem.new(StoneItem.Kind.ROCK, 1.0, 1)
	var second := StoneItem.new(StoneItem.Kind.ICE, 1.4, 2)
	inventory.add(first)
	inventory.add(second)
	assert_eq(inventory.size(), 2)
	assert_false(inventory.is_empty())
	var removed: StoneItem = inventory.remove_at(0)
	assert_eq(removed, first)
	assert_eq(inventory.size(), 1)
	assert_eq(inventory.remove_at(9), null)
	assert_eq(inventory.remove_at(-1), null)
	assert_eq(inventory.size(), 1)


func test_inventory_changed_signal() -> void:
	var inventory := InventoryModel.new()
	watch_signals(inventory)
	inventory.add(StoneItem.new(StoneItem.Kind.ROCK, 0.8, 3))
	assert_signal_emitted(inventory, "changed")
	inventory.remove_at(0)
	assert_signal_emit_count(inventory, "changed", 2)


func test_stone_growth_is_bigger_for_bigger_stones() -> void:
	var small: float = PlanetProfile.growth_for_stone(START_RADIUS, 0.5)
	var medium: float = PlanetProfile.growth_for_stone(START_RADIUS, 1.0)
	var large: float = PlanetProfile.growth_for_stone(START_RADIUS, 1.5)
	assert_lt(small, medium)
	assert_lt(medium, large)
