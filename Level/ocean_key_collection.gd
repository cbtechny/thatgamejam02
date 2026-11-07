extends Node2D
## Ocean-only pickups and the same three dim-to-filled key icons as Level One.
const KEY_TEXTURES: Array[Texture2D] = [
	preload("res://Art/Textures/Resources/Key/key0.tres"),
	preload("res://Art/Textures/Resources/Key/key1.tres"),
	preload("res://Art/Textures/Resources/Key/key2.tres"),
]
const DIM := Color(0.65, 0.72, 0.85, 0.5)
const GOLD := Color("ffda88")

var middle_platform: int = -1
var collected: Array[bool] = [true, false, false]
var icons: Array[Sprite2D] = []
var _room: Node2D
var _hud: Control
var _time: float = 0.0

func _ready() -> void:
	_room = get_parent() as Node2D
	# The lighthouse mask occupies z=10; pickups remain visible beyond its beam.
	z_index = 12
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	var layer := CanvasLayer.new()
	layer.name = "KeyHUD"
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	for texture: Texture2D in KEY_TEXTURES:
		var icon := Sprite2D.new()
		icon.texture = texture
		_hud.add_child(icon)
		icons.append(icon)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	reset()

func _layout_hud() -> void:
	var extent: Vector2 = get_viewport_rect().size
	var factor: float = minf(extent.x / 1920.0, extent.y / 1080.0)
	for index: int in range(icons.size()):
		icons[index].position = Vector2(extent.x * 0.5 + (index - 1) * 120.0 * factor, 54.0 * factor)
		icons[index].scale = Vector2.ONE * 0.22 * factor

func reset() -> void:
	collected = [true, false, false]
	for index: int in range(icons.size()):
		icons[index].self_modulate = Color.WHITE if collected[index] else DIM
	refresh()

func collect_on_landing(platform: int) -> void:
	var index: int = 1 if platform == middle_platform else 2 if platform == _room._platform_names.size() - 1 else -1
	if index < 0 or collected[index]:
		return
	collected[index] = true
	icons[index].self_modulate = Color.WHITE
	queue_redraw()

func refresh() -> void:
	# Use the gameplay clock so pause, entrance locks and Reset also govern effects.
	_time = _room._elapsed_time
	queue_redraw()

func pickup_position(index: int) -> Vector2:
	var platform: int = middle_platform if index == 1 else _room._platform_names.size() - 1
	var offset := Vector2(6.0, -18.0) if index == 1 else Vector2(-5.0, -18.0)
	return _room._platform_anchor(platform) + offset + Vector2(0.0, sin(_time * 2.0 + index) * 1.5)

func _draw() -> void:
	if not is_instance_valid(_room):
		return
	for index: int in [1, 2]:
		if collected[index]:
			continue
		var center := pickup_position(index)
		var texture: Texture2D = KEY_TEXTURES[index]
		var size: Vector2 = texture.get_size() * 0.06
		draw_texture_rect(texture, Rect2(center - size * 0.5, size), false)
		# A few deterministic sparkles avoid an extra particle system or timers.
		for mote: int in range(5):
			var phase: float = _time * 1.7 + mote * TAU / 5.0 + index
			var point := center + Vector2(cos(phase) * (size.x * 0.5 + 2.0), sin(phase * 1.3) * 6.0)
			var alpha: float = 0.35 + 0.55 * (0.5 + 0.5 * sin(phase * 2.0))
			draw_circle(point, 0.45, Color(GOLD, alpha), true, -1.0, true)
