extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://dev/Level 1 - Alt/level_1.tscn")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	var level: Node = current_scene
	var crank: Node2D = level._crank
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = crank.to_global(Vector2(576, 0))
	root.push_input(press, true)
	check(level._dragging_crank, "Crank receives mouse press")
	# Feed real drag events between physics ticks; the fan must never bounce back.
	var previous_y: float = level._left_fan.position.y
	for step: int in range(1, 25):
		var motion := InputEventMouseMotion.new()
		motion.position = crank.to_global(Vector2.from_angle(step * 0.025) * 576)
		level._unhandled_input(motion)
		level._process(0.0)
		var expected: float = level._left_fan_start_y - step * 2.5
		check(absf(level._left_fan.position.y - expected) < 0.01, "Fan follows winding displacement before physics")
		await physics_frame
		await process_frame
		await _wait_for_scene_fade()
		level._process(0.0)
		check(absf(level._left_fan.position.y - expected) < 0.01, "Fan retains winding displacement after physics")
		check(level._left_fan.position.y <= previous_y + 0.01, "Fan never moves backwards during forward winding")
		previous_y = level._left_fan.position.y
	for step: int in range(23, -1, -1):
		var motion := InputEventMouseMotion.new()
		motion.position = crank.to_global(Vector2.from_angle(step * 0.025) * 576)
		level._unhandled_input(motion)
		await physics_frame
		await process_frame
		await _wait_for_scene_fade()
		level._process(0.0)
		check(absf(level._left_fan.position.y - (level._left_fan_start_y - step * 2.5)) < 0.01, "Reverse winding preserves fan displacement after physics")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	level._input(release)
	for frame: int in range(6):
		await physics_frame
		await process_frame
		await _wait_for_scene_fade()
		level._process(0.0)
		check(absf(level._left_fan.position.y - level._left_fan_start_y) < 0.01, "Fan holds position after mouse release")
	level._show_win_screen()
	level._finish_win_presentation()
	await process_frame
	await _wait_for_scene_fade()
	var next: Button
	for button: Node in level._ui.find_children("*", "Button", true, false):
		if button.text == "Continue to the ocean":
			next = button
	check(next != null and next.can_process(), "Next stage button processes while victory pauses tree")
	if next != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = next.get_global_rect().get_center()
		click.pressed = true
		root.push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click, true)
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	check(current_scene != level and not paused, "Mouse click on victory Continue enters next stage and unpauses")
	current_scene.free()
	await process_frame
	await _wait_for_scene_fade()
	print("Level 1 input regression: %d failures" % failures)
	quit(1 if failures else 0)


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
