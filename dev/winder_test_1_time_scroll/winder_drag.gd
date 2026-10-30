@tool
class_name WinderDrag
extends Area2D
## Drag around the key's center: clockwise winds, counterclockwise reduces it.

signal winding_started
signal crank_delta(revolutions: float)
signal winding_released

const MAX_WINDING_DEGREES: float = WindingObjectController.MAX_WINDING_DEGREES
const MAX_WINDING_RADIANS: float = PI * 1.5

var _dragging: bool = false
var _input_enabled: bool = true
var _winding_fraction: float = 0.0
var _rest_rotation: float = 0.0
var _previous_angle: float = 0.0
var _has_pointer_angle: bool = false
var _editor_preview_degrees: float = -1.0
var _editor_rest_rotation: float = 0.0

@onready var _winder: Node2D = get_parent()


func _ready() -> void:
	_rest_rotation = _winder.rotation
	if Engine.is_editor_hint():
		set_process_input(false)
		return
	set_winding_fraction(0.0)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if Engine.is_editor_hint() or not _input_enabled or _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		var offset: Vector2 = event.global_position - _winder.global_position
		_has_pointer_angle = offset.length_squared() >= 1.0
		_previous_angle = offset.angle()
		winding_started.emit()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_drag()
	elif event is InputEventMouseMotion:
		var offset: Vector2 = event.global_position - _winder.global_position
		if offset.length_squared() < 1.0:
			_has_pointer_angle = false
			return
		var angle: float = offset.angle()
		if not _has_pointer_angle:
			_previous_angle = angle
			_has_pointer_angle = true
			return
		var angular_delta: float = wrapf(angle - _previous_angle, -PI, PI)
		# Keep tracking the pointer at either limit so reversing responds at once.
		_previous_angle = angle
		var previous: float = _winding_fraction
		set_winding_fraction(previous + angular_delta / MAX_WINDING_RADIANS)
		var applied: float = _winding_fraction - previous
		if not is_zero_approx(applied):
			crank_delta.emit(applied * MAX_WINDING_RADIANS / TAU)


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if not is_instance_valid(_winder) or _editor_preview_degrees < 0.0:
			return
		if what == NOTIFICATION_EDITOR_PRE_SAVE:
			_winder.rotation = _editor_rest_rotation
		elif what == NOTIFICATION_EDITOR_POST_SAVE:
			_winder.rotation = _editor_rest_rotation + deg_to_rad(_editor_preview_degrees)
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _dragging:
		_release_drag()


func set_editor_preview_degrees(degrees: float) -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(_winder):
		return
	if _editor_preview_degrees < 0.0:
		_editor_rest_rotation = _winder.rotation
	_editor_preview_degrees = clampf(degrees, 0.0, MAX_WINDING_DEGREES)
	_winder.rotation = _editor_rest_rotation + deg_to_rad(_editor_preview_degrees)


func clear_editor_preview() -> void:
	if Engine.is_editor_hint() and _editor_preview_degrees >= 0.0 and is_instance_valid(_winder):
		_winder.rotation = _editor_rest_rotation
		_editor_preview_degrees = -1.0


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_dragging = false


func is_input_enabled() -> bool:
	return _input_enabled


func get_winding_fraction() -> float:
	return _winding_fraction


## Used by the controller during unwind; this never emits another input event.
func set_winding_fraction(fraction: float) -> void:
	_winding_fraction = clampf(fraction, 0.0, 1.0)
	if is_instance_valid(_winder):
		_winder.rotation = _rest_rotation + _winding_fraction * MAX_WINDING_RADIANS


func _release_drag() -> void:
	_dragging = false
	winding_released.emit()
