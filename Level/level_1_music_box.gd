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

func _replace_puzzle_for_restart() -> Node:
	var old_room: Node = _room
	var parent: Node = old_room.get_parent()
	var replacement: Node = load(old_room.scene_file_path).instantiate()
	parent.remove_child(old_room)
	old_room.queue_free()
	_room = replacement
	parent.add_child(replacement)
	replacement._transitioning = true
	replacement.set_presentation_locked(true)
	return self
