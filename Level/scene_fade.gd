extends CanvasLayer
## One screen quad and two short tweens, shared by scene navigation.
var busy := false
var _cover: ColorRect
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	add_child(_cover)
func go(path: String) -> Error:
	if busy:
		return ERR_BUSY
	busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition.call_deferred(path)
	return OK
func _transition(path: String) -> void:
	var fade := create_tween()
	fade.tween_property(_cover, "modulate:a", 1.0, 0.22)
	await fade.finished
	var result := get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(_cover, "modulate:a", 0.0, 0.22)
	await fade.finished
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	if result != OK:
		push_error("Unable to open scene: " + path)
