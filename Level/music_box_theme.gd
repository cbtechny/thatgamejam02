extends RefCounted
## Shared music-box colors; scale styles for controls rasterized in small rooms.
const INK := Color("112639")
const CREAM := Color("f7f1dd")
const GOLD := Color("ffda88")
const BUTTON_SIZE := Vector2(420, 62)

static func plaque(border: Color = GOLD, metric_scale: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(2 * metric_scale)))
	style.set_corner_radius_all(roundi(8 * metric_scale))
	style.content_margin_left = 18 * metric_scale
	style.content_margin_right = 18 * metric_scale
	style.content_margin_top = 8 * metric_scale
	style.content_margin_bottom = 8 * metric_scale
	return style

static func create(metric_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", CREAM)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := plaque(GOLD.darkened(0.3), metric_scale)
		match state:
			"hover":
				style.bg_color = Color("24455d")
				style.border_color = GOLD
			"pressed":
				style.bg_color = Color("091a29")
				style.border_color = GOLD
			"disabled":
				style.bg_color = Color("1a2a36")
				style.border_color = Color("5b635e")
			"focus":
				style.draw_center = false
				style.border_color = GOLD
				style.set_border_width_all(maxi(2, roundi(3 * metric_scale)))
		theme.set_stylebox(state, "Button", style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", CREAM)
	theme.set_color("font_disabled_color", "Button", Color("9babae"))
	theme.set_font_size("font_size", "Button", 26)
	return theme
