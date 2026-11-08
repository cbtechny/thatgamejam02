extends SceneTree
## Real keyboard/mouse regression for GUI focus stealing the launch shortcut.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func run() -> void:
	for number: int in [2, 3]:
		paused = false
		change_scene_to_file("res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number])
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage._process(3.0)
		stage.set_process(false)
		var room: Node = stage._room
		room.set_process(false)
		for cycle: int in range(6):
			room._process(1.35 if number == 2 else 3.0)
			room.fire_fan()
			room._process(room._flight_duration + 0.01)
			room._process(0.4)
			check(room._state == room.State.FAILED, "Timed miss enters failure before Reset")
			click(room._reset_button)
			check(root.gui_get_focus_owner() == room._reset_button, "Mouse Reset reproduces focused HUD button")
			key(KEY_SPACE)
			check(room._state == room.State.HOPPING, "Space launches after focused Reset, cycle %d level %d" % [cycle, number])
			room._process(0.05)
			var elapsed: float = room._hop_elapsed
			key(KEY_SPACE, true)
			key(KEY_SPACE)
			check(room._state == room.State.HOPPING and room._hop_elapsed == elapsed, "Held/repeated Space cannot reset or relaunch an active hop")
			key(KEY_ENTER)
			check(room._state == room.State.RESTING, "Enter still activates focused Reset")
		check(room.get_node_or_null("TitleButton") == null, "Gameplay has no title button")
		key(KEY_SPACE)
		check(current_scene == stage and room._state == room.State.HOPPING, "Space fires during gameplay")
		key(KEY_R)
		check(room._state == room.State.RESTING, "R remains available")
		room._campaign_menu.show_menu(false)
		check(paused, "Pause opens normally")
		key(KEY_SPACE)
		check(not paused and room._state == room.State.RESTING, "Space activates Resume in the pause menu without firing")
		await process_frame
		room._campaign_menu.show_menu(false)
		await process_frame
		await process_frame
		var retry: Button
		for button: Node in room._campaign_menu.panel.find_children("*", "Button", true, false):
			check(button.text != "Return to Title", "Pause menu has no title button")
			if button.text == "Retry Stage":
				retry = button
		click(retry)
		await create_timer(0.65).timeout
		check(current_scene != stage and not root.get_node("SceneFade").busy, "Menu Retry completes its fade")
		stage = current_scene
		stage._process(3.0)
		room = stage._room
		room._reset_button.grab_focus()
		key(KEY_SPACE)
		check(room._state == room.State.HOPPING, "Space launches after menu Retry even with HUD focus")
	paused = false
	current_scene.free()
	var session: Node = root.get_node("ReleaseSession")
	session.music.stop()
	session.music.stream = null
	await create_timer(0.1).timeout
	print("Ocean Space input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
