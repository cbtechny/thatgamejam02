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
	for button: Node in current_scene.find_children("*", "Button", true, false):
		if button.text == caption:
			mouse(button.get_global_rect().get_center(), true)
			mouse(button.get_global_rect().get_center(), false)
			await process_frame
			return
	check(false, "Missing button: " + caption)

func wait_scene(path: String) -> bool:
	for frame: int in range(360):
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
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

func raise_tide(room: Node) -> void:
	var crank: Node2D = room._crank
	var angle: float = room._crank_angle
	mouse(crank.to_global(Vector2.from_angle(angle) * 576), true)
	for step: int in range(1, 31):
		var motion := InputEventMouseMotion.new()
		motion.position = crank.to_global(Vector2.from_angle(angle + PI * float(step) / 30.0) * 576)
		root.push_input(motion, true)
		await physics_frame
	mouse(Vector2.ZERO, false)
	check(absf(room._crank_angle - PI * 0.5) < 0.05, "Mouse crank raises tide")

func solve_ocean(number: int) -> void:
	var path: String = "res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number]
	if not await wait_scene(path):
		return
	await wait_entrance()
	var room: Node = current_scene._room
	# Deliberately take the low-water dead end, then use the real Retry button.
	for step: int in range(3):
		await hop(room)
	check(room._state == 2, "Low route reaches rock trap")
	await capture("0%d-rock-retry" % (number + 1))
	key(KEY_ESCAPE)
	await process_frame
	await click_caption("Retry stage")
	await process_frame
	await process_frame
	await wait_entrance()
	room = current_scene._room
	check(not paused and room._current_platform == 0, "Rock retry restores start")
	await hop(room)
	await hop(room)
	await raise_tide(room)
	await capture("0%d-ocean" % (number + 3))
	await hop(room)
	if number == 3:
		await hop(room)
	check(room._state == 3, "Real input route solves ocean %d" % number)
	await process_frame
	await click_caption("Continue")

func run() -> void:
	change_scene_to_file("res://Main.tscn")
	await process_frame
	await process_frame
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
		await click_caption("Return to Title")
		check(await wait_scene("res://Level/title_menu.tscn"), "Replay returns to title")
	print("Scripted full playthrough: %d failures; real input, real physics, both rock retries, ending, replay, title." % failures)
	root.get_node("ReleaseSession").quit_game(1 if failures else 0)
