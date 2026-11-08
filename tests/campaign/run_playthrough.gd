extends SceneTree
## Scripted solve using mouse/key input and real frame/physics clocks.
## This is reproducible integration evidence, not an uncoached human playtest.

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func click_caption(caption: String) -> void:
	if caption == "Continue":
		await create_timer(0.45).timeout
	# Deliver synthetic unpause input before physics flushes its pending queries.
	await physics_frame
	for button: Node in current_scene.find_children("*", "Button", true, false):
		if button.text.nocasecmp_to(caption) == 0:
			mouse(button.get_global_rect().get_center(), true)
			mouse(button.get_global_rect().get_center(), false)
			await process_frame
			await _wait_for_scene_fade()
			return
	check(false, "Missing button: " + caption)

func wait_scene(path: String) -> bool:
	for frame: int in range(360):
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
			await _wait_for_scene_fade()
			return true
		await physics_frame
	check(false, "Transition timed out: " + path)
	return false

func wait_entrance() -> void:
	for frame: int in range(240):
		if current_scene._entrance_finished:
			return
		await physics_frame
	check(false, "Entrance did not finish")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://release-captures"
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Save " + label)

func solve_first_level() -> void:
	await wait_entrance()
	await capture("01-key")
	var room: Node = current_scene._room
	var display: Control = current_scene.get_node("MusicBox/RoomClip/Room")
	var crank: Node2D = room._crank
	mouse(display.get_global_transform_with_canvas() * crank.to_global(Vector2(576, 0)), true)
	for step: int in range(1, 31):
		var motion := InputEventMouseMotion.new()
		motion.position = display.get_global_transform_with_canvas() * crank.to_global(Vector2.from_angle(float(step) * 0.1) * 576)
		root.push_input(motion, true)
		await physics_frame
	mouse(Vector2.ZERO, false)
	await physics_frame
	# Wait for the visible target's cycle rather than changing puzzle state.
	for frame: int in range(150):
		if room._middle_fan_pulse_time < 0.04:
			break
		await physics_frame
	key(KEY_SPACE)
	for frame: int in range(360):
		if paused:
			break
		await physics_frame
	check(room._key_snapped and not room._missed, "Real winding/release solves Level 1")
	await capture("02-key-complete")
	await click_caption("Continue to the ocean")

func hop(room: Node) -> void:
	key(KEY_SPACE)
	for frame: int in range(90):
		if room._state != 1:
			return
		await physics_frame
	check(false, "Hop did not land")

func set_tide(room: Node, target: float) -> void:
	var crank: Node2D = room._crank
	var angle: float = room._crank_angle
	var delta: float = wrapf(target - angle, -PI, PI)
	if absf(delta) < 0.001:
		return
	mouse(crank.to_global(Vector2.from_angle(angle) * 576), true)
	# Finish small adjustments before the next launch window in the night route.
	for step: int in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = crank.to_global(Vector2.from_angle(angle + delta * float(step) / 8.0) * 576)
		root.push_input(motion, true)
		await physics_frame
	mouse(Vector2.ZERO, false)
	check(absf(wrapf(room._crank_angle - target, -PI, PI)) < 0.01, "Mouse crank sets the planned tide")

func wait_launch(room: Node, time: float) -> bool:
	for frame: int in range(1200):
		if room._elapsed_time >= time:
			var on_time: bool = room._elapsed_time < time + 0.08
			check(on_time, "Reach launch window at %.2fs (actual %.3fs)" % [time, room._elapsed_time])
			return on_time
		await physics_frame
	check(false, "Stage clock did not reach the launch window")
	return false

func solve_ocean(number: int) -> void:
	var path: String = "res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number]
	if not await wait_scene(path):
		return
	await wait_entrance()
	var room: Node = current_scene._room
	# Deliberately miss a moving board, then use the real Retry button.
	await wait_launch(room, 3.0 if number == 3 else 1.35)
	await hop(room)
	for frame: int in range(90):
		if room._state == 2:
			break
		await physics_frame
	check(room._state == 2 and not room._fragment.visible, "Mistimed shot misses the ferry")
	await capture("0%d-missed-retry" % (number + 1))
	key(KEY_ESCAPE)
	await process_frame
	await _wait_for_scene_fade()
	await click_caption("Retry stage")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	await wait_entrance()
	room = current_scene._room
	check(not paused and room._current_platform == 0, "Retry restores shore")
	var times: Array[float] = [0.8, 4.8, 7.45, 10.8]
	var angles: Array[float] = [-PI * 0.5, asin(-0.35), asin(0.85), asin(0.95)]
	if number == 3:
		times.assign([0.35, 1.10, 4.45, 12.65, 16.80])
		angles.assign([-PI * 0.5, asin(-0.45), asin(-0.45), asin(0.55), asin(0.65)])
	for platform: int in range(times.size()):
		await set_tide(room, angles[platform])
		if not await wait_launch(room, times[platform]):
			return
		await hop(room)
		check(room._current_platform == platform + 1, "Timed shot %d lands in ocean %d" % [platform + 1, number])
		if room._current_platform != platform + 1:
			return
		if platform == 1:
			await capture("0%d-ocean" % (number + 3))
	check(room._state == 3, "Real input route solves ocean %d" % number)
	await process_frame
	await _wait_for_scene_fade()
	await click_caption("Continue")

func run() -> void:
	change_scene_to_file("res://Main.tscn")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	await click_caption("Play")
	if not await wait_scene("res://Level/level_1_music_box.tscn"):
		root.get_node("ReleaseSession").quit_game(1)
		return
	await solve_first_level()
	await solve_ocean(2)
	await solve_ocean(3)
	if await wait_scene("res://Level/ending.tscn"):
		await capture("07-ending")
		await click_caption("Play again")
		check(await wait_scene("res://Level/level_1_music_box.tscn"), "Ending replay works")
		await wait_entrance()
		key(KEY_ESCAPE)
		await process_frame
		await _wait_for_scene_fade()
		check(paused, "Replay can pause")
		await click_caption("Resume")
		check(not paused, "Replay can resume")
	print("Scripted full playthrough: %d failures; real input, real physics, four day/five night shots, both miss retries, ending and replay." % failures)
	root.get_node("ReleaseSession").quit_game(1 if failures else 0)


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
