extends "res://Level/music_box_presentation.gd"
## Extend ocean scenery to the painted aperture without moving the puzzle layout.

func _ready() -> void:
	var clip: Control = $MusicBox/RoomClip
	var backdrop: Polygon2D = $MusicBox/InteriorBackdrop
	var play_area := Rect2(clip.position, clip.size)
	var aperture := Rect2(backdrop.polygon[0], Vector2.ZERO)
	for point: Vector2 in backdrop.polygon:
		aperture = aperture.expand(point)
	aperture = backdrop.transform * aperture
	clip.position = aperture.position
	clip.size = aperture.size
	_room.set_stage_layout(Rect2(play_area.position - aperture.position, play_area.size))
	super._ready()
