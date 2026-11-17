extends GutTest

## Sample GUT test proving the headless test pipeline works.
## Replace or extend this as real systems land.


func test_addition_sanity() -> void:
	assert_eq(1 + 1, 2, "Integer addition should be stable")


func test_string_contains() -> void:
	var greeting: String = "hello godot"
	assert_string_contains(greeting, "godot", "Greeting should mention the engine")
