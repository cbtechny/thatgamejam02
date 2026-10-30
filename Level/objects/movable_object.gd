@tool
class_name MovableObject2D
extends Line2D
## Edit this node's line points in the 2D viewport. Only Body moves at runtime.

signal motion_state_changed(state: MotionState)
signal blocked_changed(blocked: bool)
signal path_end_reached

enum MotionState { STOPPED, FORWARD, HOLDING, RETURNING }

const DISTANCE_EPSILON: float = 0.0001
const COLLISION_MARGIN: float = 0.08
const MAX_ROTATION_STEP: float = PI / 180.0

## Saved separately from the transient preview. Missing entries use zero degrees.
@export_storage var point_rotations_degrees: PackedFloat32Array = PackedFloat32Array()

@export_group("Movement")
## One controller per winding key. An unassigned object stays at its first point.
@export var winding_key: WindingObjectController
@export var show_path_in_game: bool = true:
	set(value):
		show_path_in_game = value
		if not Engine.is_editor_hint():
			self_modulate.a = 1.0 if value else 0.0

@export_group("Appearance")
## Leave empty to use the simple placeholder polygon.
@export var object_texture: Texture2D:
	set(value):
		object_texture = value
		_sync_body_settings()
@export var object_color: Color = Color(1.0, 0.78, 0.35):
	set(value):
		object_color = value
		_sync_body_settings()

@export_group("Collision")
@export var body_shape: Shape2D:
	set(value):
		body_shape = value
		_sync_body_settings()
@export_flags_2d_physics var body_collision_layer: int = 2:
	set(value):
		body_collision_layer = value
		_sync_body_settings()
@export_flags_2d_physics var body_collision_mask: int = 3:
	set(value):
		body_collision_mask = value
		_sync_body_settings()

var motion_state: MotionState = MotionState.STOPPED
var is_blocked: bool = false

var _body: PhysicsBody2D
var _world_points: PackedVector2Array = PackedVector2Array()
var _point_distances: PackedFloat64Array = PackedFloat64Array()
var _point_rotations: PackedFloat64Array = PackedFloat64Array()
var _distance: float = 0.0
var _path_length: float = 0.0
var _hold_remaining: float = 0.0
var _return_speed: float = 0.0
var _cycle_active: bool = false
var _frozen: bool = false
var _editor_preview_fraction: float = -1.0
var _editor_saving: bool = false
var _editor_point_count: int = -1


func _enter_tree() -> void:
	# Place the body before it joins the physics world, so first-tick queries see
	# each instance at its own start rather than all bodies at the line origin.
	var body: PhysicsBody2D = get_node_or_null("Body") as PhysicsBody2D
	if body != null:
		body.position = points[0] if not points.is_empty() else Vector2.ZERO
		body.rotation = deg_to_rad(get_point_rotation_degrees(0))


func _ready() -> void:
	_body = get_node("Body") as PhysicsBody2D
	_sync_body_settings()
	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	set_process(false)
	self_modulate.a = 1.0 if show_path_in_game else 0.0
	_cache_path()
	reset_to_start()
	if is_instance_valid(winding_key):
		winding_key.phase_changed.connect(_on_winding_phase_changed)
		winding_key.motion_advanced.connect(_on_motion_advanced)
		winding_key.rest_advanced.connect(_on_rest_advanced)
		winding_key.reset_requested.connect(reset_to_start)
		winding_key.freeze_requested.connect(freeze)
		_on_winding_phase_changed(winding_key.phase)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if _editor_point_count != points.size():
			_editor_point_count = points.size()
			notify_property_list_changed()
		_update_editor_preview()


func _on_motion_advanced(path_fraction: float) -> void:
	if Engine.is_editor_hint() or _frozen or _path_length <= DISTANCE_EPSILON:
		return
	if _distance >= _path_length - DISTANCE_EPSILON:
		return
	_advance_along_path(maxf(path_fraction, 0.0) * _path_length)
	if _distance >= _path_length - DISTANCE_EPSILON:
		_set_motion_state(MotionState.STOPPED)
		path_end_reached.emit()


func _on_rest_advanced(delta: float) -> void:
	if Engine.is_editor_hint() or _frozen or not is_instance_valid(winding_key):
		return
	match motion_state:
		MotionState.HOLDING:
			var return_delta: float = maxf(delta - _hold_remaining, 0.0)
			_hold_remaining = maxf(_hold_remaining - delta, 0.0)
			if _hold_remaining <= 0.0:
				_return_speed = _distance / maxf(winding_key.return_duration, 0.01)
				_set_motion_state(MotionState.RETURNING)
				_step_return(return_delta)
		MotionState.RETURNING:
			_step_return(delta)


## Full-level reset: deliberately restores the authored start, including after freeze.
func reset_to_start() -> void:
	_frozen = false
	_cycle_active = false
	_hold_remaining = 0.0
	_return_speed = 0.0
	_distance = 0.0
	if is_instance_valid(_body) and not _world_points.is_empty():
		_body.global_position = _world_points[0]
		_body.rotation = _point_rotations[0]
		_body.force_update_transform()
	_set_blocked(false)
	_set_motion_state(MotionState.STOPPED)


## Used by a future level-success check. Winding cannot resume a frozen object.
func freeze() -> void:
	_frozen = true
	_cycle_active = false
	_set_blocked(false)
	_set_motion_state(MotionState.STOPPED)


func get_distance_along_path() -> float:
	return _distance


func get_path_length() -> float:
	return _path_length


func get_body_position() -> Vector2:
	return _body.global_position


func get_point_rotation_degrees(index: int) -> float:
	return point_rotations_degrees[index] if index >= 0 and index < point_rotations_degrees.size() else 0.0


func set_point_rotation_degrees(index: int, degrees: float) -> void:
	if index < 0 or index >= points.size() or not is_finite(degrees):
		return
	if point_rotations_degrees.size() <= index:
		point_rotations_degrees.resize(index + 1)
	point_rotations_degrees[index] = degrees
	if Engine.is_editor_hint():
		_update_editor_preview()


## Transient editor pose. Its value is intentionally not exported or saved.
func set_editor_preview_degrees(degrees: float) -> void:
	if Engine.is_editor_hint():
		_editor_preview_fraction = clampf(degrees / WindingObjectController.MAX_WINDING_DEGREES, 0.0, 1.0)
		_update_editor_preview()


func clear_editor_preview() -> void:
	if Engine.is_editor_hint():
		_editor_preview_fraction = -1.0
		_update_editor_preview()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_editor_saving = true
		_update_editor_preview()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_editor_saving = false
		_update_editor_preview()


func _on_winding_phase_changed(phase: WindingObjectController.MotionPhase) -> void:
	if _frozen:
		return
	match phase:
		WindingObjectController.MotionPhase.MOVING:
			_cycle_active = true
			_set_motion_state(MotionState.STOPPED if _distance >= _path_length - DISTANCE_EPSILON else MotionState.FORWARD)
		WindingObjectController.MotionPhase.COOLDOWN:
			if not _cycle_active:
				return
			_cycle_active = false
			_set_blocked(false)
			if winding_key.stop_behavior == WindingObjectController.StopBehavior.KEEP_POSITION or _distance <= DISTANCE_EPSILON:
				_set_motion_state(MotionState.STOPPED)
			else:
				_hold_remaining = maxf(winding_key.hold_duration, 0.0)
				_set_motion_state(MotionState.HOLDING)


func _step_return(delta: float) -> void:
	_advance_along_path(-_return_speed * delta)
	if _distance <= DISTANCE_EPSILON:
		_set_motion_state(MotionState.STOPPED)


func _advance_along_path(signed_distance: float) -> void:
	if is_zero_approx(signed_distance):
		return
	var direction: float = signf(signed_distance)
	var remaining: float = absf(signed_distance)
	var blocked: bool = false
	# Visit every corner, even when one physics tick crosses several segments.
	while remaining > DISTANCE_EPSILON:
		var waypoint: float = _next_waypoint_distance(direction)
		var step: float = minf(absf(waypoint - _distance), remaining)
		if step <= DISTANCE_EPSILON:
			break
		var next_distance: float = _distance + direction * step
		var angle_change: float = absf(_rotation_at_distance(next_distance) - _rotation_at_distance(_distance))
		if angle_change > 0.000001:
			var rotation_step: float = _safe_rotation_step()
			if angle_change > rotation_step:
				step *= rotation_step / angle_change
				next_distance = _distance + direction * step
		var old_transform: Transform2D = _body.transform
		var next_rotation: float = _rotation_at_distance(next_distance)
		var path_position: Vector2 = _position_at_distance(_distance)
		var target_position: Vector2 = _position_at_distance(next_distance)
		var motion: Vector2 = target_position - _body.global_position
		if not is_equal_approx(_body.rotation, next_rotation):
			# Test the rotated collider with its translation. A contact can block
			# rotating in place while still allowing the combined step away.
			# Angular steps keep edge travel inside the collision margin.
			_body.rotation = next_rotation
			if _body.test_move(_body.global_transform, motion, null, COLLISION_MARGIN, true):
				_body.transform = old_transform
				blocked = true
				break
		var collision: KinematicCollision2D = _body.move_and_collide(motion, false, COLLISION_MARGIN, true)
		# Other movers must query this body's updated transform in the same tick.
		_body.force_update_transform()
		if collision != null:
			# Only consume actual travel. A blocked object never banks missed distance.
			# Recovery can move backwards. Project the final position instead of
			# clamping a travel fraction, which would discard backwards correction.
			var path_direction: Vector2 = (target_position - path_position).normalized()
			var travel: float = (_body.global_position - path_position).dot(path_direction)
			var actual_distance: float = clampf(_distance + direction * travel, 0.0, _path_length)
			var actual_rotation: float = _rotation_at_distance(actual_distance)
			if not is_equal_approx(_body.rotation, actual_rotation):
				_body.rotation = actual_rotation
				if _body.test_move(_body.global_transform, Vector2.ZERO, null, COLLISION_MARGIN, true):
					_body.transform = old_transform
				else:
					_distance = actual_distance
			else:
				_distance = actual_distance
			_body.force_update_transform()
			blocked = true
			break
		_distance = next_distance
		remaining -= step
	_set_blocked(blocked)


func _next_waypoint_distance(direction: float) -> float:
	if direction > 0.0:
		for point_distance: float in _point_distances:
			if point_distance > _distance + DISTANCE_EPSILON:
				return point_distance
		return _path_length
	for index: int in range(_point_distances.size() - 1, -1, -1):
		if _point_distances[index] < _distance - DISTANCE_EPSILON:
			return _point_distances[index]
	return 0.0


func _position_at_distance(distance: float) -> Vector2:
	for index: int in range(1, _world_points.size()):
		if distance <= _point_distances[index]:
			var segment_length: float = _point_distances[index] - _point_distances[index - 1]
			var weight: float = (distance - _point_distances[index - 1]) / segment_length
			return _world_points[index - 1].lerp(_world_points[index], weight)
	return _world_points[_world_points.size() - 1]


func _rotation_at_distance(distance: float) -> float:
	for index: int in range(1, _point_distances.size()):
		if distance <= _point_distances[index]:
			var weight: float = (distance - _point_distances[index - 1]) / (_point_distances[index] - _point_distances[index - 1])
			# Deliberately keep authored turns: 0 -> 360 is a full clockwise turn.
			return lerpf(_point_rotations[index - 1], _point_rotations[index], weight)
	return _point_rotations[-1] if not _point_rotations.is_empty() else deg_to_rad(get_point_rotation_degrees(0))


func _safe_rotation_step() -> float:
	if body_shape == null:
		return MAX_ROTATION_STEP
	var rect: Rect2 = body_shape.get_rect()
	var radius: float = maxf(rect.position.length(), rect.end.length())
	radius = maxf(radius, maxf(Vector2(rect.position.x, rect.end.y).length(), Vector2(rect.end.x, rect.position.y).length()))
	# The basis norm bounds scale in every direction, including nonuniform roots.
	radius *= sqrt(global_transform.x.length_squared() + global_transform.y.length_squared())
	return minf(MAX_ROTATION_STEP, COLLISION_MARGIN / maxf(radius, COLLISION_MARGIN))


func _cache_path() -> void:
	_world_points.clear()
	_point_distances.clear()
	_point_rotations.clear()
	_path_length = 0.0
	var path_points: PackedVector2Array = points.duplicate()
	if closed and path_points.size() > 1:
		path_points.append(path_points[0])
	for index: int in range(path_points.size()):
		var point: Vector2 = path_points[index]
		var world_point: Vector2 = to_global(point)
		if not _world_points.is_empty():
			var segment_length: float = _world_points[-1].distance_to(world_point)
			if segment_length <= DISTANCE_EPSILON:
				continue
			_path_length += segment_length
		_world_points.append(world_point)
		_point_distances.append(_path_length)
		_point_rotations.append(deg_to_rad(get_point_rotation_degrees(index % points.size())))


func _set_motion_state(value: MotionState) -> void:
	if motion_state == value:
		return
	motion_state = value
	motion_state_changed.emit(value)


func _set_blocked(value: bool) -> void:
	if is_blocked == value:
		return
	is_blocked = value
	blocked_changed.emit(value)


func _sync_body_settings() -> void:
	var body: PhysicsBody2D = get_node_or_null("Body") as PhysicsBody2D
	if body == null:
		return
	body.collision_layer = body_collision_layer
	body.collision_mask = body_collision_mask
	(body.get_node("CollisionShape2D") as CollisionShape2D).shape = body_shape
	var sprite: Sprite2D = body.get_node("Sprite2D") as Sprite2D
	sprite.texture = object_texture
	sprite.visible = object_texture != null
	sprite.modulate = object_color
	var placeholder: Polygon2D = body.get_node("Placeholder") as Polygon2D
	placeholder.visible = object_texture == null
	placeholder.color = object_color


func _update_editor_preview() -> void:
	if not is_instance_valid(_body):
		return
	if _editor_preview_fraction < 0.0 or _editor_saving:
		_body.position = points[0] if not points.is_empty() else Vector2.ZERO
		_body.rotation = deg_to_rad(get_point_rotation_degrees(0))
	else:
		# Rebuild from the live line so point and transform edits update the pose.
		_cache_path()
		if _world_points.is_empty():
			_body.position = Vector2.ZERO
		else:
			_body.global_position = _position_at_distance(_path_length * _editor_preview_fraction)
			_body.rotation = _rotation_at_distance(_path_length * _editor_preview_fraction)


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [{"name": "Path Rotations", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP}]
	for index: int in range(points.size()):
		properties.append({
			"name": "point_%d_rotation" % index, "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "-360,360,0.1,or_less,or_greater,suffix:deg",
			"usage": PROPERTY_USAGE_EDITOR,
		})
	return properties


func _get(property: StringName) -> Variant:
	if property.begins_with("point_") and property.ends_with("_rotation"):
		return get_point_rotation_degrees(property.get_slice("_", 1).to_int())
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("point_") and property.ends_with("_rotation"):
		set_point_rotation_degrees(property.get_slice("_", 1).to_int(), float(value))
		return true
	return false


func _property_can_revert(property: StringName) -> bool:
	return property.begins_with("point_") and property.ends_with("_rotation")


func _property_get_revert(_property: StringName) -> Variant:
	return 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if points.size() < 2:
		warnings.append("Add at least two distinct line points to define a movement path.")
	if winding_key == null:
		warnings.append("Assign a WindingObjectController to Winding Key. This object stays still without one.")
	if body_shape == null:
		warnings.append("Assign Body Shape to enable collision blocking.")
	return warnings
