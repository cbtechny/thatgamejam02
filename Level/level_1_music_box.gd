extends "res://Level/music_box_presentation.gd"
## Continue the rope through the decorative border above the gameplay viewport.

func _process(delta: float) -> void:
	super._process(delta)
	var rope: Line2D = _room._rope_line
	var points: PackedVector2Array = rope.points
	var upper: Line2D = $MusicBox/RopeUpperExtension
	upper.hide()
	if points.size() < 2:
		return
	var start: Vector2 = rope.to_global(points[0])
	if start.y >= 0.0:
		return
	var previous: Vector2 = start
	for index: int in range(1, points.size()):
		var point: Vector2 = rope.to_global(points[index])
		if point.y >= 0.0:
			var edge: Vector2 = previous.lerp(point, -previous.y / (point.y - previous.y))
			var display: Control = $MusicBox/RoomClip/Room
			var clip: Control = $MusicBox/RoomClip
			upper.points = PackedVector2Array([
				clip.position + display.position + start * display.scale,
				clip.position + display.position + edge * display.scale,
			])
			upper.show()
			return
		previous = point
