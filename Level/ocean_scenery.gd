extends Node2D
## Full-aperture coastal scenery. Its scale is independent of the playable area.

const DAY_COAST := preload("res://Art/Textures/StageScenery/T_TidalCoast.svg")
const NIGHT_COAST := preload("res://Art/Textures/StageScenery/T_MoonlitCoast.svg")
const MIST := preload("res://Art/Textures/StageScenery/T_CoastalMist.svg")
const LIGHTHOUSE := preload("res://Art/Textures/StageScenery/T_Lighthouse.svg")
const LIGHTHOUSE_RECT := Rect2(140.0, 4.0, 80.0, 152.0)
const PAINT := preload("res://Art/Materials/M_PaintedScenery.tres")
const PAINT_TEXTURES := [&"brushwork", &"painted_ball", &"painted_spiral", &"painted_drum", &"painted_star"]

@export var night_mode: bool = false

@onready var _room: Node2D = get_parent()
var _bounds := Rect2()
var _ground := TextureRect.new()
var _paint: ShaderMaterial


func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_ground.position = bounds.position
	_ground.size = bounds.size
	queue_redraw()


func _ready() -> void:
	_paint = PAINT.duplicate()
	_paint.set_shader_parameter(&"room_style", 2 if night_mode else 1)
	_ground.show_behind_parent = true
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ground.texture = NIGHT_COAST if night_mode else DAY_COAST
	_ground.material = _paint
	add_child(_ground)
	set_process(not night_mode)


func _process(_delta: float) -> void:
	_paint.set_shader_parameter(&"scenery_time", _room._elapsed_time)
	queue_redraw()


func _draw() -> void:
	if not _bounds.has_area():
		return
	if night_mode:
		draw_texture_rect(LIGHTHOUSE, LIGHTHOUSE_RECT, false)
		return
	# Stagger the wisps so the drift reads at different depths.
	for index: int in range(4):
		var extent := Vector2(0.47, 0.039 + 0.012 * (index % 2)) * _bounds.size
		var origin := _bounds.position + _mist_center(index) * _bounds.size - extent * 0.5
		draw_texture_rect(MIST, Rect2(origin, extent), false, Color(1, 1, 1, 0.49))


func _mist_center(index: int) -> Vector2:
	var time: float = _room._elapsed_time
	var drift: float = sin(time * (0.16 + index * 0.045) + index * 1.7) * 0.075
	return Vector2(0.10 + index * 0.26 + drift, 0.55 + 0.027 * (index % 2))


func copy_paint_textures_to(target: ShaderMaterial) -> void:
	for parameter: StringName in PAINT_TEXTURES:
		target.set_shader_parameter(parameter, PAINT.get_shader_parameter(parameter))
