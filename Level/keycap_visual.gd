extends Control
## Raised keycap decoration on a native Button: native input/focus stays intact.
const CREAM := Color("eee3c2")
const GOLD := Color("ffda88")
const INK := Color("112639")
var _button: Button
var _face: Panel
var _key_label: Label
var _action_label: Label
var _style: StyleBoxFlat
var _caption: String
var _action: String
var _keycode: Key
var _metric: float = 1.0
var _keyboard_down: bool = false
var _tap_remaining: float = 0.0
var _tap_pending: bool = false
var _travel: float = 0.0
var _restart_border := Color.TRANSPARENT

static func attach(button: Button, caption: String, action: String, keycode: Key, metric: float = 1.0) -> Control:
	var visual: Control = load("res://Level/keycap_visual.gd").new()
	visual.name = "KeycapVisual"
	visual._caption = caption
	visual._action = action
	visual._keycode = keycode
	visual._metric = metric
	button.add_child(visual)
	return visual

func _ready() -> void:
	_button = get_parent() as Button
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The raised face supplies the visuals while the button keeps native input.
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color.TRANSPARENT
		_button.add_theme_stylebox_override(state, empty)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		_button.add_theme_color_override(state, Color.TRANSPARENT)
	var shadow := ColorRect.new()
	shadow.name = "KeyShadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 3 * _metric
	shadow.offset_top = 5 * _metric
	shadow.offset_right = -1 * _metric
	add_child(shadow)
	var depth := ColorRect.new()
	depth.name = "KeyDepth"
	depth.color = Color("695031")
	depth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	depth.offset_left = 2 * _metric
	depth.offset_right = -2 * _metric
	depth.offset_top = 6 * _metric
	depth.offset_bottom = -1 * _metric
	add_child(depth)
	_face = Panel.new()
	_face.name = "KeyFace"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = CREAM
	_style.border_color = Color("fff3d8")
	_style.set_border_width_all(roundi(2 * _metric))
	_style.border_width_bottom = roundi(4 * _metric)
	_style.set_corner_radius_all(roundi(7 * _metric))
	_face.add_theme_stylebox_override("panel", _style)
	add_child(_face)
	_key_label = _make_label(_caption, _button.get_theme_font_size("font_size"))
	_action_label = _make_label(_action, maxi(12, roundi(_button.get_theme_font_size("font_size") * 0.38)))
	_button.button_down.connect(_begin_tap)
	resized.connect(_layout)
	_layout()

func _make_label(caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	_face.add_child(label)
	return label

func set_keyboard_down(value: bool) -> void:
	_keyboard_down = value and (not _button.disabled or _keyboard_down)
	if value and not _button.disabled:
		_begin_tap()

func _begin_tap() -> void:
	_tap_remaining = 0.16
	_tap_pending = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_keyboard_down = false

func _process(delta: float) -> void:
	# Show every tap for at least one rendered frame, even during a slow frame.
	if _tap_pending:
		_tap_pending = false
	else:
		_tap_remaining = maxf(0.0, _tap_remaining - delta)
	var held: bool = _keyboard_down or (not _button.disabled and (Input.is_key_pressed(_keycode) or _button.is_pressed()))
	var pushed: bool = _tap_remaining > 0.0 or held
	_travel = move_toward(_travel, 1.0 if pushed else 0.0, delta * 24.0)
	if pushed:
		_style.bg_color = Color("e5b768")
	elif _button.disabled:
		_style.bg_color = Color("8d9995")
	else:
		_style.bg_color = GOLD if _button.is_hovered() else CREAM
	_update_border()
	_layout()

func set_restart_glow(border: Color, shadow: Color, radius: int) -> void:
	_restart_border = border
	_style.shadow_size = radius
	_style.shadow_color = shadow
	_update_border()

func _update_border() -> void:
	if _restart_border.a > 0.0:
		_style.border_color = _restart_border
	else:
		_style.border_color = GOLD if _button.has_focus() else Color("fff3d8")

func _layout() -> void:
	if not is_instance_valid(_face):
		return
	_face.position = Vector2(2 * _metric, 5 * _metric * _travel)
	_face.size = Vector2(maxf(0.0, size.x - 4 * _metric), maxf(0.0, size.y - 7 * _metric))
	_key_label.position = Vector2.ZERO
	_key_label.size = Vector2(_face.size.x, _face.size.y * 0.7)
	_action_label.position = Vector2(0.0, _face.size.y * 0.65)
	_action_label.size = Vector2(_face.size.x, _face.size.y * 0.3)
