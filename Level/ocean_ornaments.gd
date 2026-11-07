extends Node2D
## Shared painted assets with a tide drift / night constellation presentation.
## Behind water and platforms, so decorations never masquerade as landing targets.
@export var night_mode: bool = false
const TEXTURES: Array[Texture2D] = [
	preload("res://Art/Textures/BackgroundOrnaments/painted_ball.png"),
	preload("res://Art/Textures/BackgroundOrnaments/painted_spiral.png"),
	preload("res://Art/Textures/BackgroundOrnaments/painted_star.png"),
	preload("res://Art/Textures/BackgroundOrnaments/painted_drum.png"),
]
const DAY_CENTERS: Array[Vector2] = [Vector2(108, 44), Vector2(173, 73), Vector2(294, 40), Vector2(69, 113)]
const NIGHT_CENTERS: Array[Vector2] = [Vector2(102, 40), Vector2(173, 68), Vector2(287, 36), Vector2(265, 103)]
const SIZES: Array[float] = [57.6, 83.2, 52.8, 59.2]
var _sky: Control
var _sprites: Array[Sprite2D] = []

func _ready() -> void:
	show_behind_parent = true
	_sky = preload("res://Level/living_backdrop.tscn").instantiate()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sky.show_behind_parent = true
	var sky_material: ShaderMaterial = _sky.material as ShaderMaterial
	sky_material.set_shader_parameter("sky_mode", true)
	sky_material.set_shader_parameter("tint", Color.WHITE)
	sky_material.set_shader_parameter("motion_speed", 0.08)
	sky_material.set_shader_parameter("motion_amount", 0.022)
	add_child(_sky)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for index: int in range(TEXTURES.size()):
		var sprite := Sprite2D.new()
		sprite.name = "PaintedOrnament%d" % index
		sprite.texture = TEXTURES[index]
		if night_mode:
			sprite.material = unlit
		add_child(sprite)
		_sprites.append(sprite)
	_update_pose()
	queue_redraw()

func _draw() -> void:
	pass

func _process(_delta: float) -> void:
	_update_pose()

func _update_pose() -> void:
	var room: Node = get_parent()
	_sky.position = room._scenery_bounds.position
	_sky.size = room._scenery_bounds.size
	var time: float = room.get("_elapsed_time")
	var crank_angle: float = room.get("_crank_angle")
	for index: int in range(_sprites.size()):
		var sprite: Sprite2D = _sprites[index]
		var phase: float = index * 1.7
		var factor: float = SIZES[index] / float(sprite.texture.get_width())
		if night_mode:
			# Small elliptical orbits and a slow breathing halo-like silhouette.
			var orbit: float = time * (0.10 + index * 0.012) + phase
			sprite.position = NIGHT_CENTERS[index] + Vector2(cos(orbit) * 6.0, sin(orbit) * 4.0)
			sprite.rotation = -time * 0.045 + phase * 0.2
			sprite.scale = Vector2.ONE * factor * (1.0 + sin(time * 0.7 + phase) * 0.045)
			sprite.modulate = Color(0.60, 0.72, 1.0, 0.30 + 0.12 * (0.5 + 0.5 * sin(time * 0.7 + phase)))
		else:
			# Drift with the current, rise with the tide and rock instead of spinning.
			var tide: float = 0.5 + 0.5 * sin(crank_angle)
			sprite.position = DAY_CENTERS[index] + Vector2(sin(time * 0.22 + phase) * 7.0, sin(time * 0.8 + phase) * 2.0 - tide * 8.0)
			sprite.rotation = sin(time * 0.5 + phase) * 0.13
			sprite.scale = Vector2.ONE * factor
			sprite.modulate = Color(0.8, 0.93, 0.96, 0.52)
