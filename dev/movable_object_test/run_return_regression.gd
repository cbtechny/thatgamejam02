extends SceneTree
## Return regression for the main scene and the currently authored music-box paths.
## Add -- --capture with a rendering driver to test real mouse input and save images.

var _checks: int = 0
var _failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if _capture:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _run() -> void:
	for path: String in ["res://Main.tscn", "res://Level/music_box.tscn"]:
		var scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await _ticks(2)
		var key: WindingObjectController = scene.find_child("WindingKey1", true, false) as WindingObjectController
		var area: WinderDrag = scene.find_child("WinderHitArea", true, false) as WinderDrag
		var objects: Array[MovableObject2D] = []
		var nodes: Array[Node] = [scene]
		var index: int = 0
		while index < nodes.size():
			if nodes[index] is MovableObject2D:
				objects.append(nodes[index] as MovableObject2D)
			nodes.append_array(nodes[index].get_children())
			index += 1
		var cycle_index: int = 0
		for charge: float in [1.0, 0.5, 1.0]:
			var capture_cycle: bool = _capture and path == "res://Level/music_box.tscn" and cycle_index == 0
			if _capture:
				await _wind_with_mouse(area, charge)
				_expect(key.phase == WindingObjectController.MotionPhase.MOVING and absf(key.get_wound_fraction() - charge) < 0.01, "Real mouse winding releases the expected charge: " + path)
			else:
				_expect(key.start_motion(charge), "A fresh or repeated release starts: " + path)
			# Pointer coordinates can produce a fraction just above the typed target.
			# Include the boundary tick before observing the post-zero phase.
			await _ticks(ceili(key.full_unwind_duration * key.get_wound_fraction() * 60.0) + 1)
			var holding: bool = true
			for object: MovableObject2D in objects:
				holding = holding and object.motion_state == MovableObject2D.MotionState.HOLDING
			_expect(holding, "The bound objects enter hold when the winding key reaches zero")
			if capture_cycle:
				await _save_capture("return-hold.png")
			await _ticks(ceili((key.hold_duration + key.return_duration + 1.0) * 60.0))
			for object: MovableObject2D in objects:
				var body: Node2D = object.get_node("Body") as Node2D
				var returned: bool = object.motion_state == MovableObject2D.MotionState.STOPPED and not object.is_blocked and object.get_distance_along_path() < 0.01 and body.global_position.distance_to(object.to_global(object.points[0])) < 0.1 and absf(angle_difference(body.rotation, deg_to_rad(object.get_point_rotation_degrees(0)))) < 0.001
				_expect(returned, "Position and rotation return after %.0f-degree winding: %s/%s" % [charge * 270.0, path, object.name])
			if capture_cycle:
				await _save_capture("return-restored.png")
			cycle_index += 1
		scene.queue_free()
		await process_frame
	print("Authored return checks: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _wind_with_mouse(area: WinderDrag, charge: float) -> void:
	var center: Vector2 = (area.get_parent() as Node2D).global_position
	var angle: float = -PI * 0.5
	var position: Vector2 = center + Vector2.from_angle(angle) * 70.0
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await _ticks(2)
	var steps: int = ceili(charge * 270.0 / 15.0)
	for step: int in range(steps):
		angle = -PI * 0.5 + deg_to_rad(charge * 270.0 * float(step + 1) / float(steps))
		position = center + Vector2.from_angle(angle) * 70.0
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _save_capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "res://.godot/editor_winding_validation/" + filename
	_expect(root.get_texture().get_image().save_png(path) == OK, "Rendered return pose captured: " + filename)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await physics_frame
		await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
