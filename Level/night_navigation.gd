extends Node2D
## Keep interaction and landing boundaries legible outside the moving light.
## Coordinates come from the puzzle's actual anchors; no collision changes.

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	# The lighthouse uses a drawn mask; unshaded alone cannot bypass it.
	z_index = 11

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var room: Node = get_parent()
	var edge := Color(0.43, 0.57, 0.66, 0.8)
	for platform: int in range(room._platform_names.size()):
		var anchor: Vector2 = room._platform_anchor(platform)
		var floating: bool = platform in room._floating_platforms
		var width: float = 26.0 if floating else 28.0
		draw_line(anchor - Vector2(width * 0.5, 0), anchor + Vector2(width * 0.5, 0), edge, 0.65, true)
	room._draw_keyhole(room._platform_names.size() - 1, self)
