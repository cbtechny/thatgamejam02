extends SceneTree
## Real-physics checks for winding limits, normalized paths, collisions, and timing.
## Run with --headless --fixed-fps 60 --script res://dev/movable_object_test/run_movable_object_tests.gd.

const MOVABLE_SCENE: PackedScene = preload("res://Level/objects/movable_object.tscn")

var _failures: int = 0
var _checks: int = 0
var _pointer_angle: float = -PI * 0.5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_normalized_paths()
	await _test_partial_tick_release()
	await _test_corners_and_endpoint()
	await _test_blocking_and_resume()
	await _test_diagonal_and_object_collisions()
	await _test_return_timing()
	await _test_blocked_return()
	await _test_independent_keys()
	await _test_input_lock_and_reset()
	await _test_invalid_and_transformed_paths()
	await _test_path_rotations()
	await _test_rotation_blocking()
	await _test_rotating_contact_return()
	await _test_repeatability()
	await _test_music_box_input()
	await _test_shader_integration()
	print("Winding and movable object checks: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _test_normalized_paths() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var short_path: MovableObject2D = _add_object(fixture, key, _straight_path(100.0))
	var long_path: MovableObject2D = _add_object(fixture, key, _straight_path(400.0, 100.0))
	key.start_motion(0.5)
	await _ticks(15)
	_expect(absf(short_path.get_distance_along_path() - 25.0) < 0.1 and absf(long_path.get_distance_along_path() - 100.0) < 0.1, "Different path lengths share the same winding progress")
	await _ticks(15)
	_expect(absf(short_path.get_distance_along_path() - 50.0) < 0.1 and absf(long_path.get_distance_along_path() - 200.0) < 0.1, "135 degrees advances every clear path by exactly one half")
	key.reset_objects()
	key.start_motion(1.0)
	await _ticks(60)
	_expect(absf(short_path.get_distance_along_path() - 100.0) < 0.1 and absf(long_path.get_distance_along_path() - 400.0) < 0.1, "270 degrees reaches both endpoints together")
	var exposes_speed: bool = false
	for property: Dictionary in short_path.get_property_list():
		if property.name == "speed":
			exposes_speed = true
	_expect(not exposes_speed, "Movable objects no longer expose an independent Speed property")
	await _dispose(fixture)


func _test_corners_and_endpoint() -> void:
	var fixture: Node2D = _fixture(0.1)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, PackedVector2Array([
		Vector2.ZERO, Vector2.ZERO, Vector2(40, 0), Vector2(40, 40), Vector2(1120, 40),
	]))
	_add_wall(fixture, Vector2(20, 20), Vector2(4, 4))
	var end_count: Array[int] = [0]
	object.path_end_reached.connect(func() -> void: end_count[0] += 1)
	await _ticks(2)
	key.start_motion()
	await _ticks(1)
	var expected: Vector2 = Vector2(40.0 + 1160.0 / 6.0 - 80.0, 40.0)
	_expect(object.get_body_position().distance_to(expected) < 0.1, "A fast winding tick visits each corner without taking a diagonal shortcut")
	await _ticks(10)
	_expect(object.get_body_position().distance_to(Vector2(1120, 40)) < 0.1 and end_count[0] == 1, "The endpoint is exact and emits one arrival signal")
	_expect(absf(object.get_path_length() - 1160.0) < 0.1, "Duplicate path points do not add distance")
	await _dispose(fixture)


func _test_partial_tick_release() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(1000.0))
	key.start_motion(0.37)
	await _ticks(23)
	_expect(absf(object.get_distance_along_path() - 370.0) < 0.1, "A winding amount between physics ticks stops at its exact path fraction")
	_expect(absf(key.get_cooldown_remaining() - (2.0 - (23.0 / 60.0 - 0.37))) < 0.0001, "Cooldown accounts for the unused part of the final unwind tick")
	await _dispose(fixture)


func _test_blocking_and_resume() -> void:
	var fixture: Node2D = _fixture(4.0)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(60000.0))
	var wall: StaticBody2D = _add_wall(fixture, Vector2(80, 0), Vector2(2, 80))
	var blocked_count: Array[int] = [0]
	object.blocked_changed.connect(func(blocked: bool) -> void:
		if blocked:
			blocked_count[0] += 1
	)
	await _ticks(2)
	key.start_motion()
	await _ticks(1)
	_expect(object.is_blocked and object.get_body_position().x > 73.0 and object.get_body_position().x < 75.0, "Fast normalized movement cannot tunnel through a thin barrier")
	await _ticks(30)
	var stopped_at: float = object.get_distance_along_path()
	await _ticks(30)
	_expect(absf(object.get_distance_along_path() - stopped_at) < 0.02 and blocked_count[0] == 1, "Contact stays stable without accumulating blocked travel")
	wall.collision_layer = 0
	await _ticks(1)
	_expect(absf(object.get_distance_along_path() - stopped_at - 250.0) < 0.1 and not object.is_blocked, "Opening a barrier consumes only the next winding step, without catching up")
	await _dispose(fixture)


func _test_diagonal_and_object_collisions() -> void:
	var fixture: Node2D = _fixture(4.0)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var diagonal: MovableObject2D = _add_object(fixture, key, PackedVector2Array([Vector2.ZERO, Vector2(200, 200)]))
	_add_wall(fixture, Vector2(80, 100), Vector2(2, 250))
	key.start_motion()
	await _ticks(180)
	var at: Vector2 = diagonal.get_body_position()
	# Recovery at a resting diagonal contact can differ by two solver margins.
	_expect(diagonal.is_blocked and absf(at.x - at.y) < 0.2 and at.x < 74.2, "A diagonal collision stays on the path within physics contact tolerance")
	await _dispose(fixture)
	fixture = _fixture()
	key = fixture.get_node("Key") as WindingObjectController
	var first: MovableObject2D = _add_object(fixture, key, _straight_path(200.0))
	var second: MovableObject2D = _add_object(fixture, key, PackedVector2Array([Vector2(160, 0), Vector2(-40, 0)]))
	await _ticks(2)
	key.start_motion()
	await _ticks(50)
	_expect(first.is_blocked and second.is_blocked and second.get_body_position().x - first.get_body_position().x > 9.9, "Two objects driven by one key block each other")
	_expect(absf(first.get_distance_along_path() - first.get_body_position().x) < 0.1 and absf(second.get_distance_along_path() - 160.0 + second.get_body_position().x) < 0.1, "Collision recovery does not create false path progress")
	await _dispose(fixture)


func _test_return_timing() -> void:
	var fixture: Node2D = _fixture(1.0, WindingObjectController.StopBehavior.RETURN_TO_START)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(200.0))
	key.start_motion(0.5)
	await _ticks(30)
	_expect(object.motion_state == MovableObject2D.MotionState.HOLDING and key.get_wound_fraction() == 0.0, "Key 1 starts its hold exactly when winding reaches zero")
	await _ticks(89)
	_expect(absf(object.get_distance_along_path() - 100.0) < 0.1, "Key 1 holds its actual stopped position for 1.5 seconds")
	await _ticks(16)
	_expect(absf(object.get_distance_along_path() - 50.0) < 3.5, "Key 1 returns over 0.5 seconds")
	await _ticks(16)
	_expect(object.get_distance_along_path() < 0.01 and object.motion_state == MovableObject2D.MotionState.STOPPED, "Key 1 ends its return at the authored first point")
	await _dispose(fixture)


func _test_blocked_return() -> void:
	var fixture: Node2D = _fixture(1.0, WindingObjectController.StopBehavior.RETURN_TO_START)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	key.hold_duration = 0.0
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(200.0))
	key.start_motion(0.5)
	await _ticks(30)
	var wall: StaticBody2D = _add_wall(fixture, Vector2(50, 0), Vector2(4, 100))
	await _ticks(60)
	_expect(object.is_blocked and object.get_body_position().x > 56.0, "Return movement also stops at a barrier")
	wall.collision_layer = 0
	await _ticks(40)
	_expect(object.get_distance_along_path() < 0.01, "A delayed return finishes after the barrier opens")
	await _dispose(fixture)


func _test_independent_keys() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var other_key: WindingObjectController = WindingObjectController.new()
	other_key.full_unwind_duration = 1.0
	other_key.stop_behavior = WindingObjectController.StopBehavior.KEEP_POSITION
	fixture.add_child(other_key)
	var first: MovableObject2D = _add_object(fixture, key, _straight_path(1000.0))
	var second: MovableObject2D = _add_object(fixture, other_key, _straight_path(1000.0, 100.0))
	key.start_motion(0.25)
	await _ticks(15)
	_expect(absf(first.get_distance_along_path() - 250.0) < 0.1 and second.get_distance_along_path() == 0.0, "Each object responds to exactly one winding key")
	await _ticks(120)
	_expect(absf(first.get_distance_along_path() - 250.0) < 0.1, "Keep Position preserves the actual stopped progress")
	key.start_motion(0.25)
	other_key.start_motion(0.5)
	await _ticks(30)
	_expect(absf(first.get_distance_along_path() - 500.0) < 0.1 and absf(second.get_distance_along_path() - 500.0) < 0.1, "The next winding adds proportional travel from the kept position")
	await _dispose(fixture)


func _test_input_lock_and_reset() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(100.0))
	key.start_motion(0.5)
	_expect(not key.begin_winding() and not key.start_motion(), "A released winding key cannot be operated during unwind")
	key.set_winding_amount(1.0)
	_expect(is_equal_approx(key.get_wound_fraction(), 0.5), "Locked input cannot refill or replace the active winding")
	await _ticks(30)
	_expect(key.phase == WindingObjectController.MotionPhase.COOLDOWN and not key.begin_winding(), "Input remains locked when the key first reaches zero")
	await _ticks(119)
	_expect(not key.begin_winding(), "The post-return input lock lasts the full two seconds")
	await _ticks(1)
	_expect(key.begin_winding(), "The key becomes available two seconds after zero")
	key.release_winding()
	_expect(key.phase == WindingObjectController.MotionPhase.IDLE, "A zero-charge click does not start movement or cooldown")
	key.start_motion()
	await _ticks(10)
	key.freeze_objects()
	var stopped_at: float = object.get_distance_along_path()
	await _ticks(60)
	_expect(not key.start_motion() and absf(object.get_distance_along_path() - stopped_at) < 0.1, "Success freeze locks both movement and winding input")
	key.reset_objects()
	_expect(object.get_distance_along_path() == 0.0 and key.get_wound_fraction() == 0.0 and key.get_cooldown_remaining() == 0.0 and key.begin_winding(), "Reset restores objects, clears winding and cooldown, and unlocks the key")
	await _dispose(fixture)


func _test_invalid_and_transformed_paths() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var empty: MovableObject2D = _add_object(fixture, key, PackedVector2Array())
	var duplicate: MovableObject2D = _add_object(fixture, key, PackedVector2Array([Vector2(0, 100), Vector2(0, 100)]))
	var unassigned: MovableObject2D = _add_object(fixture, null, _straight_path(100.0, 200.0))
	key.start_motion()
	await _ticks(10)
	_expect(empty.get_path_length() == 0.0 and duplicate.get_path_length() == 0.0 and unassigned.get_distance_along_path() == 0.0, "Invalid and unassigned paths remain safe and still")
	await _dispose(fixture)
	fixture = _fixture()
	fixture.position = Vector2(300, 300)
	fixture.rotation = 0.4
	fixture.scale = Vector2(2.0, 1.5)
	key = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(100.0))
	object.show_path_in_game = false
	key.start_motion(0.5)
	await _ticks(30)
	_expect(object.get_body_position().distance_to(fixture.to_global(Vector2(50, 0))) < 0.1, "Placed, rotated, and scaled paths still map half winding to their midpoint")
	_expect(is_zero_approx(object.self_modulate.a) and (object.get_node("Body/Placeholder") as Polygon2D).is_visible_in_tree(), "Hiding the guide keeps the moving body visible")
	await _dispose(fixture)


func _test_path_rotations() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 300)]), PackedFloat32Array([30, 90, 270]))
	var body: Node2D = object.get_node("Body") as Node2D
	_expect(absf(body.rotation_degrees - 30.0) < 0.01, "Point zero sets the initial body and collider rotation")
	key.start_motion()
	await _ticks(15)
	_expect(object.get_body_position().distance_to(Vector2(100, 0)) < 0.1 and absf(angle_difference(body.rotation, PI * 0.5)) < 0.001, "A path waypoint has its authored rotation")
	await _ticks(15)
	_expect(absf(angle_difference(body.rotation, deg_to_rad(150.0))) < 0.001, "Rotation interpolates by distance within each unequal path segment")
	await _ticks(30)
	_expect(absf(angle_difference(body.rotation, deg_to_rad(270.0))) < 0.001, "The endpoint preserves its authored angle")
	key.reset_objects()
	_expect(absf(body.rotation_degrees - 30.0) < 0.01, "Reset restores the first point rotation")
	await _dispose(fixture)
	fixture = _fixture(1.0, WindingObjectController.StopBehavior.RETURN_TO_START)
	key = fixture.get_node("Key") as WindingObjectController
	object = _add_object(fixture, key, _straight_path(200.0), PackedFloat32Array([0, 360]))
	body = object.get_node("Body") as Node2D
	key.start_motion(0.5)
	await _ticks(30)
	_expect(absf(angle_difference(body.rotation, PI)) < 0.001, "Zero to 360 degrees preserves a full authored turn instead of taking the shortest angle")
	await _ticks(105)
	_expect(object.get_distance_along_path() > 20.0 and object.get_distance_along_path() < 80.0 and absf(angle_difference(body.rotation, object.get_distance_along_path() / 200.0 * TAU)) < 0.001, "Return movement reverses the same rotation path")
	await _ticks(20)
	_expect(object.get_distance_along_path() < 0.01 and absf(body.rotation) < 0.001, "Returning to the start restores both position and rotation")
	await _dispose(fixture)
	fixture = _fixture()
	fixture.rotation = 0.4
	fixture.scale = Vector2(2.0, 1.5)
	key = fixture.get_node("Key") as WindingObjectController
	object = _add_object(fixture, key, _straight_path(200.0), PackedFloat32Array([20, 100]))
	key.start_motion(0.5)
	await _ticks(30)
	_expect(absf(angle_difference((object.get_node("Body") as Node2D).rotation, deg_to_rad(60.0))) < 0.001 and object.get_body_position().distance_to(fixture.to_global(Vector2(100, 0))) < 0.1, "Point rotations remain local to placed, rotated, and scaled path roots")
	await _dispose(fixture)


func _test_rotation_blocking() -> void:
	var fixture: Node2D = _fixture(4.0)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, _straight_path(200.0), PackedFloat32Array([0, 90]))
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(80, 10)
	object.body_shape = shape
	var wall: StaticBody2D = _add_wall(fixture, Vector2(100, -25), Vector2(400, 2))
	var wall_collider: CollisionShape2D = wall.get_child(0) as CollisionShape2D
	await _ticks(2)
	key.start_motion()
	await _ticks(120)
	var distance: float = object.get_distance_along_path()
	var body: Node2D = object.get_node("Body") as Node2D
	_expect(object.is_blocked and distance > 20.0 and distance < 100.0, "A rotating long collider stops when its corner reaches an obstacle")
	_expect(absf(angle_difference(body.rotation, deg_to_rad(distance / 200.0 * 90.0))) < 0.001 and not shape.collide(body.global_transform, wall_collider.shape, wall.global_transform), "Blocked rotation stays aligned with actual travel without overlapping the obstacle")
	await _ticks(10)
	_expect(absf(object.get_distance_along_path() - distance) < 0.01, "A rotation block does not bank movement or keep turning in place")
	wall_collider.disabled = true
	await _ticks(3)
	_expect(not object.is_blocked and object.get_distance_along_path() > distance and object.get_distance_along_path() < distance + 4.0, "Clearing a rotation obstacle resumes only the remaining winding travel")
	await _dispose(fixture)


func _test_rotating_contact_return() -> void:
	var fixture: Node2D = _fixture(4.0, WindingObjectController.StopBehavior.RETURN_TO_START)
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	# Fixed contact fixture from the authored level: two differently shaped,
	# rotated movers can separate only by translating and rotating together.
	var bow: MovableObject2D = _add_object(fixture, key, PackedVector2Array([
		Vector2(148.20856, -30.90683), Vector2(59.56952, 74.24603), Vector2(114.11261, 136.13348),
		Vector2(149.4668, 51.231384), Vector2(247.11029, 151.38544), Vector2(322.87286, 74.85422), Vector2(313.4323, -2.868866),
	]), PackedFloat32Array([0, 126.00244, 47.30944, -35.842693]), Transform2D(0.6034133, Vector2(744.00006, 406.00003)))
	var shaft: MovableObject2D = _add_object(fixture, key, PackedVector2Array([
		Vector2.ZERO, Vector2(-17.263916, 71.777176), Vector2(-109.43829, 69.80867), Vector2(-59.630005, 135.31541),
		Vector2(-92.97473, 198.06993), Vector2(-10, 234), Vector2(50, 262),
	]), PackedFloat32Array([0, -115.841736, -39.80742, 0, 69.8255]), Transform2D(0.19731627, Vector2(992.00006, 431)))
	var bow_shape: RectangleShape2D = RectangleShape2D.new()
	bow_shape.size = Vector2(62, 62)
	bow.body_shape = bow_shape
	var shaft_shape: RectangleShape2D = RectangleShape2D.new()
	shaft_shape.size = Vector2(62, 12)
	shaft.body_shape = shaft_shape
	await _ticks(2)
	key.start_motion()
	await _ticks(240)
	_expect(bow.motion_state == MovableObject2D.MotionState.HOLDING and shaft.motion_state == MovableObject2D.MotionState.HOLDING and bow.get_distance_along_path() < bow.get_path_length() * 0.9 and shaft.get_distance_along_path() < shaft.get_path_length() * 0.9, "Rotated movers touching before their endpoints enter the post-zero hold")
	await _ticks(180)
	var both_returned: bool = true
	for object: MovableObject2D in [bow, shaft]:
		var body: Node2D = object.get_node("Body") as Node2D
		both_returned = both_returned and object.motion_state == MovableObject2D.MotionState.STOPPED and object.get_distance_along_path() < 0.01 and body.global_position.distance_to(object.to_global(object.points[0])) < 0.1 and absf(body.rotation) < 0.001
	_expect(both_returned, "Touching rotated movers can retreat together and restore both authored start poses")
	await _dispose(fixture)


func _test_repeatability() -> void:
	var fixture: Node2D = _fixture()
	var key: WindingObjectController = fixture.get_node("Key") as WindingObjectController
	var object: MovableObject2D = _add_object(fixture, key, PackedVector2Array([Vector2.ZERO, Vector2(50, 0), Vector2(50, 100)]))
	_add_wall(fixture, Vector2(50, 70), Vector2(90, 4))
	await _ticks(2)
	var positions: Array[Vector2] = []
	for attempt: int in range(3):
		key.reset_objects()
		key.start_motion(0.75)
		await _ticks(90)
		positions.append(object.get_body_position())
	_expect(positions[0].distance_to(positions[1]) < 0.01 and positions[1].distance_to(positions[2]) < 0.01, "The same winding and fixed-tick input repeats the same blocked result")
	await _dispose(fixture)


func _test_music_box_input() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	root.add_child(main)
	var timeline: MusicBoxTimeline = main.get_node("MusicBoxPrototype") as MusicBoxTimeline
	var key: WindingObjectController = timeline.object_controller
	key.full_unwind_duration = 1.0
	var area: WinderDrag = timeline.get_node("MusicBox/WinderTwoBlade/WinderHitArea") as WinderDrag
	var sprite: Node2D = area.get_parent() as Node2D
	var rest_rotation: float = sprite.rotation
	var bow: MovableObject2D = timeline.get_node("MovableObjects/KeyFragmentBow") as MovableObject2D
	_press_winder(area)
	_rotate_winder(area, 360.0)
	_expect(is_equal_approx(key.get_wound_fraction(), 1.0) and absf(sprite.rotation - rest_rotation - deg_to_rad(270.0)) < 0.0001, "Clockwise dragging clamps the real winding key at 270 degrees")
	_rotate_winder(area, -1.0)
	_expect(absf(key.get_wound_fraction() * 270.0 - 269.0) < 0.001, "Counterclockwise dragging responds immediately after overshooting the angle limit")
	_rotate_winder(area, -450.0)
	_expect(key.get_wound_fraction() == 0.0 and absf(sprite.rotation - rest_rotation) < 0.0001, "Counterclockwise dragging cannot rotate below the start")
	_move_pointer(area, sprite.global_position + Vector2.from_angle(_pointer_angle) * 140.0)
	_expect(key.get_wound_fraction() == 0.0, "Radial pointer movement does not wind the key")
	_move_pointer(area, sprite.global_position)
	_pointer_angle = deg_to_rad(179.0)
	_move_pointer(area, sprite.global_position + Vector2.from_angle(_pointer_angle) * 70.0)
	_expect(key.get_wound_fraction() == 0.0, "Crossing the key center does not cause an angle jump")
	_rotate_winder(area, 2.0)
	_expect(absf(key.get_wound_fraction() * 270.0 - 2.0) < 0.001, "Dragging across the pointer angle wrap keeps the correct direction")
	_rotate_winder(area, -2.0)
	_rotate_winder(area, 135.0)
	await _ticks(5)
	_expect(bow.get_distance_along_path() == 0.0, "Objects stay at their start while the real key is held")
	_release_winder(area)
	_expect(absf(sprite.rotation - rest_rotation - deg_to_rad(135.0)) < 0.0001 and not area.is_input_enabled(), "Release preserves the wound angle and locks input")
	await _ticks(15)
	_expect(absf(key.get_wound_fraction() - 0.25) < 0.001 and absf(sprite.rotation - rest_rotation - deg_to_rad(67.5)) < 0.001, "The actual key visibly unwinds from its released angle toward zero")
	var paths_match: bool = true
	for fragment: Node in timeline.get_node("MovableObjects").get_children():
		var object: MovableObject2D = fragment as MovableObject2D
		paths_match = paths_match and absf(object.get_distance_along_path() / object.get_path_length() - 0.25) < 0.001
	_expect(paths_match, "All three real fragments advance by the same winding fraction")
	_press_winder(area)
	_rotate_winder(area, 270.0)
	_expect(absf(key.get_wound_fraction() - 0.25) < 0.001, "Mouse input during automatic unwind is ignored")
	await _ticks(15)
	_expect(absf(sprite.rotation - rest_rotation) < 0.0001 and not area.is_input_enabled(), "The key reaches its exact rest angle before cooldown begins")
	await _ticks(89)
	_expect(absf(bow.get_distance_along_path() / bow.get_path_length() - 0.5) < 0.001, "Real fragments hold their half-path result after the key reaches zero")
	await _ticks(16)
	_expect(absf(bow.get_distance_along_path() / bow.get_path_length() - 0.25) < 0.035, "The integrated hold leads into the timed object return")
	await _ticks(14)
	_expect(not area.is_input_enabled(), "The real winding key stays locked for 119 cooldown ticks")
	await _ticks(1)
	_expect(area.is_input_enabled() and key.phase == WindingObjectController.MotionPhase.IDLE and bow.get_distance_along_path() < 0.01, "At two seconds, the key unlocks and unobstructed objects are back at their start")
	main.queue_free()
	await process_frame


func _test_shader_integration() -> void:
	var scene: PackedScene = load("res://dev/shader test/music_box_surreal_test.tscn") as PackedScene
	var timeline: MusicBoxTimeline = scene.instantiate() as MusicBoxTimeline
	root.add_child(timeline)
	var key: WindingObjectController = timeline.object_controller
	key.full_unwind_duration = 1.0
	key.start_motion(0.5)
	await _ticks(15)
	var texture: TextureRect = timeline.get_node("BoxWindow/TextureRect") as TextureRect
	var material: ShaderMaterial = timeline.get_node("SurrealMarbledBackground").material as ShaderMaterial
	_expect(texture.position.x < 0.0 and float(material.get_shader_parameter("forward_blend")) > 0.0, "The shader comparison shares the new winding clock and still animates its panorama and palette")
	timeline.queue_free()
	await process_frame


func _press_winder(area: WinderDrag) -> void:
	_pointer_angle = -PI * 0.5
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.global_position = (area.get_parent() as Node2D).global_position + Vector2.from_angle(_pointer_angle) * 70.0
	event.position = event.global_position
	area._on_input_event(root, event, 0)


func _rotate_winder(area: WinderDrag, degrees: float) -> void:
	var steps: int = maxi(ceili(absf(degrees) / 30.0), 1)
	for step: int in range(steps):
		_pointer_angle += deg_to_rad(degrees) / float(steps)
		_move_pointer(area, (area.get_parent() as Node2D).global_position + Vector2.from_angle(_pointer_angle) * 70.0)


func _move_pointer(area: WinderDrag, position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	area._input(event)


func _release_winder(area: WinderDrag) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	area._input(event)


func _fixture(duration: float = 1.0, behavior: WindingObjectController.StopBehavior = WindingObjectController.StopBehavior.KEEP_POSITION) -> Node2D:
	var fixture: Node2D = Node2D.new()
	var key: WindingObjectController = WindingObjectController.new()
	key.name = "Key"
	key.full_unwind_duration = duration
	key.stop_behavior = behavior
	fixture.add_child(key)
	root.add_child(fixture)
	return fixture


func _add_object(fixture: Node2D, key: WindingObjectController, path: PackedVector2Array, rotations: PackedFloat32Array = PackedFloat32Array(), placement: Transform2D = Transform2D.IDENTITY) -> MovableObject2D:
	var object: MovableObject2D = MOVABLE_SCENE.instantiate() as MovableObject2D
	object.transform = placement
	object.points = path
	object.point_rotations_degrees = rotations
	object.winding_key = key
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10, 10)
	object.body_shape = shape
	fixture.add_child(object)
	return object


func _add_wall(fixture: Node2D, at: Vector2, size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 2
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = shape
	wall.add_child(collision_shape)
	fixture.add_child(wall)
	return wall


func _straight_path(length: float, y: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, y), Vector2(length, y)])


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await physics_frame
		await process_frame


func _dispose(fixture: Node) -> void:
	fixture.queue_free()
	await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
