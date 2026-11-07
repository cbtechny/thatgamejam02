extends Node2D
## Keep interaction and landing boundaries legible outside the moving light.
## Coordinates come from the puzzle's actual anchors; no collision changes.

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 1

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var room: Node = get_parent()
	var edge := Color(0.43, 0.57, 0.66, 0.8)
	for platform: int in range(room.PLATFORM_X.size()):
		var anchor: Vector2 = room._platform_anchor(platform)
		var floating: bool = platform in [room.Platform.LOG_1, room.Platform.LOG_2, room.Platform.LOG_3]
		var width: float = 28.0 if floating else (42.0 if platform == room.Platform.GOAL else 26.0)
		var height: float = 6.0 if floating else 169.0 - anchor.y
		draw_line(anchor - Vector2(width * 0.5, 0), anchor + Vector2(width * 0.5, 0), edge, 0.65, true)
		draw_set_transform(Vector2(anchor.x - width * 0.5, anchor.y + height + 7.0), 0.0, Vector2.ONE / room.UI_RESOLUTION)
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, room.PLATFORM_NAMES[platform], HORIZONTAL_ALIGNMENT_CENTER, width * room.UI_RESOLUTION, 30, Color("b5cbd8"))
		draw_set_transform(Vector2.ZERO)
	var knob: Vector2 = to_local(room._crank.to_global(room.CRANK_KNOB_LOCAL_POSITION.rotated(room._crank_handle.rotation)))
	draw_arc(knob, 5.5, 0.0, TAU, 32, Color("d6bd7a"), 0.6, true)
