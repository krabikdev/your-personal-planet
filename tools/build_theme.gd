extends SceneTree

## One-off tool that writes ui/theme/app_theme.tres with the game's fonts,
## colours and panel/button styles. Run:
##   godot --headless --path . --script tools/build_theme.gd
## Re-run it whenever the visual language changes; the .tres is committed.

const FONT_PATH: String = "res://assets/fonts/Underdog-Regular.ttf"

const CREAM := Color("f3e7d3")
const CREAM_SOFT := Color("d9cbb8")
const MUTED := Color("b9a9b8")
const PEACH := Color("e8ae86")
const SAGE := Color("8fb3ad")
const INK := Color("14131f")
const PANEL := Color("171425")
const PANEL_EDGE := Color("6c5a6b")
const DANGER := Color("d98a8a")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/theme"))
	var theme := Theme.new()
	var base: FontFile = load(FONT_PATH) as FontFile
	var body: Font = _bold(base, 0.3)
	var title: Font = _bold(base, 0.7)
	var strong: Font = _bold(base, 0.5)

	theme.default_font = body
	theme.default_font_size = 20

	theme.set_color("font_color", "Label", CREAM_SOFT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 3)

	_build_variation(theme, "TitleLabel", "Label", title, 66, CREAM)
	_build_variation(theme, "MenuTitle", "Label", title, 72, CREAM)
	_build_variation(theme, "H1", "Label", strong, 32, CREAM)
	_build_variation(theme, "Subtitle", "Label", title, 22, MUTED)
	_build_variation(theme, "SmallLabel", "Label", body, 15, MUTED)
	_build_variation(theme, "StatValue", "Label", strong, 21, CREAM)
	_build_variation(theme, "AccentLabel", "Label", body, 17, PEACH)
	_build_variation(theme, "DangerLabel", "Label", body, 22, DANGER)
	_build_variation(theme, "SectionLabel", "Label", strong, 16, SAGE)

	theme.set_color("font_color", "Button", CREAM_SOFT)
	theme.set_color("font_hover_color", "Button", CREAM)
	theme.set_color("font_pressed_color", "Button", CREAM)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_font("font", "Button", body)
	theme.set_font_size("font_size", "Button", 22)
	theme.set_constant("outline_size", "Button", 0)
	theme.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.40))
	theme.set_constant("shadow_offset_x", "Button", 2)
	theme.set_constant("shadow_offset_y", "Button", 2)

	var button_normal := _style(Color("211d31", 0.90), PANEL_EDGE, 1, 12)
	button_normal.content_margin_left = 24
	button_normal.content_margin_right = 24
	button_normal.content_margin_top = 12
	button_normal.content_margin_bottom = 12
	var button_hover := _style(Color("2c2743", 0.96), PEACH, 1, 12)
	button_hover.content_margin_left = 24
	button_hover.content_margin_right = 24
	button_hover.content_margin_top = 12
	button_hover.content_margin_bottom = 12
	var button_pressed := _style(Color("3a2f48", 1.0), PEACH, 2, 12)
	button_pressed.content_margin_left = 24
	button_pressed.content_margin_right = 24
	button_pressed.content_margin_top = 12
	button_pressed.content_margin_bottom = 12
	var button_disabled := _style(Color("1b1827", 0.55), Color("4a3f4c", 0.5), 1, 12)
	button_disabled.content_margin_left = 24
	button_disabled.content_margin_right = 24
	button_disabled.content_margin_top = 12
	button_disabled.content_margin_bottom = 12
	var focus := _style(Color(0, 0, 0, 0), PEACH, 2, 12)
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", focus)

	var panel := _style(Color("171425", 0.92), PANEL_EDGE, 1, 20)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	panel.content_margin_left = 26
	panel.content_margin_right = 26
	panel.content_margin_top = 22
	panel.content_margin_bottom = 22
	theme.set_stylebox("panel", "PanelContainer", panel)

	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox(
		"panel", "HudPanel", _style(Color("171425", 0.72), Color("6c5a6b", 0.55), 1, 14)
	)

	theme.set_type_variation("Card", "Button")
	theme.set_font_size("font_size", "Card", 16)
	var card_normal := _style(Color("211d31", 0.92), Color("55465c", 1.0), 1, 12)
	var card_hover := _style(Color("2d2743", 0.98), PEACH, 1, 12)
	var card_pressed := _style(Color("3b3049", 1.0), PEACH, 2, 12)
	var card_player := _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12)
	for style: StyleBoxFlat in [card_normal, card_hover, card_pressed, card_player]:
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	theme.set_stylebox("normal", "Card", card_normal)
	theme.set_stylebox("hover", "Card", card_hover)
	theme.set_stylebox("pressed", "Card", card_pressed)
	theme.set_stylebox("hover_pressed", "Card", card_pressed)
	theme.set_stylebox("focus", "Card", card_player)

	theme.set_color("font_color", "Card", CREAM_SOFT)
	theme.set_color("font_pressed_color", "Card", CREAM)

	theme.set_stylebox(
		"separator", "HSeparator", _style(Color("6c5a6b", 0.35), Color(0, 0, 0, 0), 0, 0)
	)
	theme.set_constant("separation", "HSeparator", 10)

	var slider := _style(Color("171425", 0.9), Color("4a3f52", 1.0), 1, 4)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	var grabber := _style(PEACH, PEACH, 0, 4)
	grabber.content_margin_top = 4
	grabber.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", grabber)
	theme.set_stylebox("grabber_area_highlight", "HSlider", _style(CREAM, CREAM, 0, 4))

	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_color("font_color", "PopupMenu", CREAM_SOFT)

	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("separation", "HFlowContainer", 10)
	theme.set_constant("h_separation", "GridContainer", 10)
	theme.set_constant("v_separation", "GridContainer", 10)

	var error := ResourceSaver.save(theme, "res://ui/theme/app_theme.tres")
	if error != OK:
		printerr("Could not save theme: %s" % error)
	else:
		print("Saved res://ui/theme/app_theme.tres")
	quit()


func _bold(base: FontFile, amount: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_embolden = amount
	return font


func _build_variation(
	theme: Theme, name: String, base: String, font: Font, size: int, color: Color
) -> void:
	theme.set_type_variation(name, base)
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	theme.set_color("font_shadow_color", name, Color(0, 0, 0, 0.25))


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.anti_aliasing = true
	return style
