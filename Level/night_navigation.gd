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
		# Align with the room captions instead of introducing a second label row.
		var caption: String = room._platform_names[platform]
		var text_width: float = ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x / room.UI_RESOLUTION
		draw_set_transform(anchor + Vector2(-text_width * 0.5, 14.0), 0.0, Vector2.ONE / room.UI_RESOLUTION)
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("b5cbd8"))
		draw_set_transform(Vector2.ZERO)
	var knob: Vector2 = to_local(room._crank.to_global(room.CRANK_KNOB_LOCAL_POSITION.rotated(room._crank_handle.rotation)))
	draw_arc(knob, 5.5, 0.0, TAU, 32, Color("d6bd7a"), 0.6, true)
