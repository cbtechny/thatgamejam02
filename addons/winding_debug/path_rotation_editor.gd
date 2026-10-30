@tool
extends RefCounted
## Viewport handles edit the same point rotation properties as the Inspector.

const HANDLE_LENGTH: float = 48.0
const HANDLE_RADIUS: float = 9.0
const COLOR: Color = Color(1.0, 0.55, 0.15)

var _object: MovableObject2D
var _enabled: bool = false
var _drag_index: int = -1
var _original_degrees: float = 0.0
var _drag_degrees: float = 0.0
var _previous_angle: float = 0.0


func edit(object: MovableObject2D) -> void:
	cancel_drag()
	_object = object


func set_enabled(enabled: bool) -> void:
	if not enabled:
		cancel_drag()
	_enabled = enabled


func draw(overlay: Control) -> void:
	if not _enabled or not is_instance_valid(_object) or not _object.is_inside_tree():
		return
	var font: Font = ThemeDB.fallback_font
	for index: int in range(_object.points.size()):
		var origin: Vector2 = _canvas_transform() * _object.points[index]
		var handle: Vector2 = _handle_position(index)
		var direction: Vector2 = (handle - origin).normalized()
		overlay.draw_line(origin, handle, COLOR, 2.0, true)
		overlay.draw_line(handle, handle - direction.rotated(0.5) * 10.0, COLOR, 2.0, true)
		overlay.draw_line(handle, handle - direction.rotated(-0.5) * 10.0, COLOR, 2.0, true)
		overlay.draw_circle(handle, 5.0, COLOR, true, -1.0, true)
		overlay.draw_string(font, handle + Vector2(9, -8), "P%d  %.1f deg" % [index, _object.get_point_rotation_degrees(index)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, COLOR)


func handle_input(event: InputEvent, undo: EditorUndoRedoManager) -> bool:
	if not _enabled or not is_instance_valid(_object) or not _object.is_inside_tree():
		return false
	if _drag_index >= _object.points.size():
		cancel_drag()
	if _drag_index >= 0 and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		return true
	if event is InputEventMouseButton:
		if _drag_index >= 0 and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()
			return true
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not event.pressed and _drag_index >= 0:
			var degrees: float = _object.get_point_rotation_degrees(_drag_index)
			if not is_equal_approx(degrees, _original_degrees):
				var property: StringName = "point_%d_rotation" % _drag_index
				undo.create_action("Rotate Path Point", UndoRedo.MERGE_DISABLE, _object)
				undo.add_do_property(_object, property, degrees)
				undo.add_undo_property(_object, property, _original_degrees)
				undo.commit_action(false)
			_drag_index = -1
			return true
		if event.pressed:
			var closest: float = HANDLE_RADIUS
			for index: int in range(_object.points.size()):
				var distance: float = _handle_position(index).distance_to(event.position)
				if distance < closest:
					closest = distance
					_drag_index = index
			if _drag_index >= 0:
				_original_degrees = _object.get_point_rotation_degrees(_drag_index)
				_drag_degrees = _original_degrees
				_previous_angle = _pointer_angle(event.position)
				return true
	if _drag_index >= 0 and event is InputEventMouseMotion:
		var angle: float = _pointer_angle(event.position)
		_drag_degrees += rad_to_deg(wrapf(angle - _previous_angle, -PI, PI))
		_previous_angle = angle
		_object.set_point_rotation_degrees(_drag_index, snappedf(_drag_degrees, 15.0) if event.shift_pressed else _drag_degrees)
		return true
	return false


func cancel_drag() -> void:
	if _drag_index >= 0 and is_instance_valid(_object):
		_object.set_point_rotation_degrees(_drag_index, _original_degrees)
	_drag_index = -1


func _handle_position(index: int) -> Vector2:
	var transform: Transform2D = _canvas_transform()
	var direction: Vector2 = transform.basis_xform(Vector2.from_angle(deg_to_rad(_object.get_point_rotation_degrees(index)))).normalized()
	return transform * _object.points[index] + direction * HANDLE_LENGTH


func _pointer_angle(position: Vector2) -> float:
	var local: Vector2 = _canvas_transform().affine_inverse() * position
	return (local - _object.points[_drag_index]).angle()


func _canvas_transform() -> Transform2D:
	# The editor's pan and zoom live on the SubViewport's global canvas transform.
	return EditorInterface.get_editor_viewport_2d().global_canvas_transform * _object.get_global_transform_with_canvas()
