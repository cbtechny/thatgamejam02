extends RefCounted
## Screen-space keycaps shared by the campaign stages.

const CAMPAIGN_MENU := preload("res://Level/campaign_menu.gd")
const KEYCAP_VISUAL := preload("res://Level/keycap_visual.gd")
const UI_THEME := preload("res://Level/music_box_theme.gd")
const SPACE_SIZE := Vector2(420, 62)
const RESTART_SIZE := Vector2(104, 62)
const SEPARATION := 16
const BOTTOM_OFFSET := 108.0


static func mount(layer: CanvasLayer, space: Button, restart: Button, space_action: String) -> Control:
	var controls := Control.new()
	controls.name = "KeyControls"
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	var half_width := (SPACE_SIZE.x + SEPARATION + RESTART_SIZE.x) * 0.5
	controls.offset_left = -half_width
	controls.offset_right = half_width
	controls.offset_top = -BOTTOM_OFFSET
	controls.offset_bottom = 0.0

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SEPARATION)
	controls.add_child(row)
	_add_keycap(row, space, SPACE_SIZE, "SPACE", space_action, KEY_SPACE)
	restart.text = "R"
	restart.tooltip_text = "Restart [R]"
	_add_keycap(row, restart, RESTART_SIZE, "R", "RESTART", KEY_R)
	return controls


static func add_hint(controls: Control) -> Label:
	var hint := Label.new()
	hint.name = "Hint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UI_THEME.CREAM)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.add_theme_font_size_override("font_size", 24)
	controls.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -500.0
	hint.offset_right = 500.0
	hint.offset_top = -42.0
	hint.offset_bottom = -8.0
	return hint


static func _add_keycap(row: HBoxContainer, button: Button, minimum_size: Vector2, caption: String, action: String, keycode: Key) -> void:
	button.custom_minimum_size = minimum_size
	# The visible caption is drawn by KeycapVisual. Native text must not widen the row.
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 26)
	CAMPAIGN_MENU.style_button(button)
	if button.get_parent() == null:
		row.add_child(button)
	else:
		button.reparent(row, false)
	KEYCAP_VISUAL.attach(button, caption, action, keycode)
