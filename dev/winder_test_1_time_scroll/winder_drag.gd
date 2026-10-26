extends Area2D

signal winding_started
signal crank_delta(revolutions: float)
signal winding_released

var _dragging: bool = false
var _previous_angle: float = 0.0
@onready var _winder: Node2D = get_parent()


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _dragging:
		_dragging = true
		_previous_angle = _angle_to_pointer(event.global_position)
		winding_started.emit()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		winding_released.emit()
		return

	if event is InputEventMouseMotion:
		var pointer_offset: Vector2 = event.global_position - _winder.global_position
		if pointer_offset.length_squared() < 1.0:
			return

		var current_angle: float = pointer_offset.angle()
		var angular_delta: float = wrapf(current_angle - _previous_angle, -PI, PI)
		_winder.rotation += angular_delta
		_previous_angle = current_angle

		# In Godot's canvas coordinates, positive angular movement is clockwise.
		crank_delta.emit(angular_delta / TAU)


func _angle_to_pointer(pointer_position: Vector2) -> float:
	return (pointer_position - _winder.global_position).angle()
