extends GutTest

const THEME_PATH: String = "res://ui/theme/app_theme.tres"
const UKRAINIAN: String = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя" + "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"


func _font() -> Font:
	var theme: Theme = load(THEME_PATH) as Theme
	return theme.default_font


func test_the_game_ships_its_own_font() -> void:
	var font: Font = _font()
	assert_not_null(font, "the theme needs a default font")
	assert_false(font is SystemFont, "the game must not borrow a font from the machine")
	assert_true(font is FontVariation, "the theme should ask for a specific weight")
	var base: Font = (font as FontVariation).base_font
	assert_true(base is FontFile, "the variation should sit on the imported font file")


func test_the_game_font_covers_every_ukrainian_letter() -> void:
	var font: Font = _font()
	for index: int in UKRAINIAN.length():
		var letter: String = UKRAINIAN[index]
		assert_true(
			font.has_char(letter.unicode_at(0)), "the game font is missing the letter %s" % letter
		)


func test_the_titles_are_heavier_than_the_body_text() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	var body := theme.default_font as FontVariation
	var title := theme.get_font("font", "MenuTitle") as FontVariation
	assert_not_null(title, "the menu title should use a font variation")
	assert_gt(
		title.variation_embolden,
		body.variation_embolden,
		"the title should be the chunky weight, the labels the calm one",
	)
