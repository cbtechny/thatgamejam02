extends Node2D
## Shared music-box viewport framing and entrance for all three stages.
## Gameplay retains its own coordinate space; only the outer box is animated.


const BOX_SIZE: Vector2 = Vector2(1536.0, 1024.0)
# Native artwork pixels, clear of the curtains and the lower stage lip.
const ROOM_RECT: Rect2 = Rect2(520.0, 456.0, 496.0, 248.0)

@export_group("Room entrance")
@export_range(0.0, 2.0, 0.05) var establishing_hold: float = 0.35
@export_range(0.1, 4.0, 0.05) var zoom_duration: float = 1.8
@export_range(0.6, 1.0, 0.01) var room_screen_fraction: float = 0.76

@export var room_reference_size: Vector2 = Vector2(360.0, 200.0)

@onready var _box: Node2D = $MusicBox
@export var room_path: NodePath = ^"MusicBox/RoomClip/Room"
@onready var _room: Node = get_node(room_path)

var _outside_backdrop: Control
var _entrance_elapsed: float = 0.0
var _entrance_finished: bool = false


func _ready() -> void:
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -10
	add_child(backdrop_layer)
	var fallback := ColorRect.new()
	fallback.color = Color("12151e")
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.z_index = -101
	backdrop_layer.add_child(fallback)
	var outside: Control = preload("res://Level/living_backdrop.tscn").instantiate()
	_outside_backdrop = outside
	outside.z_index = -100
	backdrop_layer.add_child(outside)
	get_viewport().size_changed.connect(_fit_viewport)
	_room.set_presentation_locked(true)
	_fit_viewport()


func _process(delta: float) -> void:
	if _entrance_finished:
		return
	_entrance_elapsed += delta
	_fit_viewport()
	if _entrance_elapsed >= establishing_hold + zoom_duration:
		_entrance_finished = true
		if is_instance_valid(_outside_backdrop):
			_outside_backdrop.queue_free()
		_room.set_presentation_locked(false)


func _fit_viewport() -> void:
	_apply_layout(get_viewport_rect().size)
	queue_redraw()


func _apply_layout(viewport_size: Vector2) -> void:
	var progress: float = clampf((_entrance_elapsed - establishing_hold) / zoom_duration, 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var wide_scale: float = minf(viewport_size.x / BOX_SIZE.x, viewport_size.y / BOX_SIZE.y) * 0.9
	var room_scale: float = ROOM_RECT.size.y / room_reference_size.y
	var playable_size: Vector2 = room_reference_size * room_scale
	var close_scale: float = minf(viewport_size.x / playable_size.x, viewport_size.y / playable_size.y) * room_screen_fraction
	var factor: float = lerpf(wide_scale, close_scale, eased)
	var focus: Vector2 = (BOX_SIZE * 0.5).lerp(ROOM_RECT.get_center(), eased)
	_box.scale = Vector2.ONE * factor
	_box.position = viewport_size * 0.5 - focus * factor


func _draw() -> void:
	pass
