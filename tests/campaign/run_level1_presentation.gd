extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level1-entrance-%s.png" % label)
func run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://Level/level_1_music_box.tscn")
	await process_frame
	await process_frame
	var stage: Node = current_scene
	var room: Node = stage._room
	var display: Control = stage.get_node("MusicBox/RoomClip/Room")
	check(room._presentation_locked, "Entrance locks crank and release")
	room._release_key()
	check(not room._released, "Space cannot release during entrance")
	await capture("wide")
	await create_timer(1.1).timeout
	await capture("zoom")
	await create_timer(1.3).timeout
	check(stage._entrance_finished and not room._presentation_locked, "Entrance unlocks after same ocean timing")
	await capture("ready")
	var local_knob: Vector2 = room._crank.to_global(Vector2(576, 0))
	var screen_knob: Vector2 = display.get_global_transform_with_canvas() * local_knob
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_knob
	root.push_input(press, true)
	await process_frame
	check(room._dragging_crank, "Screen click reaches crank inside transformed viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = display.get_global_transform_with_canvas() * room._crank.to_global(Vector2.from_angle(0.3) * 576)
	root.push_input(motion, true)
	await physics_frame
	await process_frame
	check(absf(room._wound_key_y - (room._key_start_y - 30.0)) < 0.1, "Viewport mapping preserves drag angle and lift")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = screen_knob
	root.push_input(release, true)
	await process_frame
	check(not room._dragging_crank, "Mouse release clears viewport drag")
	for extent: Vector2 in [Vector2(1920,1080), Vector2(1280,720), Vector2(1080,1080)]:
		stage._apply_layout(extent)
		var rect := Rect2(display.global_position, display.size * display.get_global_transform().get_scale())
		check(Rect2(Vector2.ZERO, extent).grow(0.5).encloses(rect), "Playable room fits viewport %s" % extent)
	stage._fit_viewport()
	room._show_pause_menu()
	check(paused and not room.can_process(), "Nested puzzle freezes when paused")
	room._resume_from_pause()
	check(not paused, "Nested pause resumes")
	room._retry_level()
	await wait_restart()
	await process_frame
	await process_frame
	stage = current_scene
	room = stage._room
	display = stage.get_node("MusicBox/RoomClip/Room")
	check(not room._presentation_locked and not room._released and stage._entrance_finished, "Retry replaces the puzzle without replaying the entrance")
	await create_timer(2.3).timeout
	room._show_win_screen()
	room._finish_win_presentation()
	await process_frame
	var next: Button
	for button: Node in room._get_menu_ui().find_children("*", "Button", true, false):
		if button.text == "Continue to the ocean":
			next = button
	var point: Vector2 = next.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	await process_frame
	check(current_scene != stage and not paused, "Victory mouse click leaves nested viewport for Level 2")
	print("Level 1 music-box presentation: %d failures" % failures)
	current_scene.free()
	await process_frame
	quit(1 if failures else 0)

func wait_restart() -> void:
	for frame: int in range(480):
		if root.get_node_or_null("Level1RestartCurtains") == null:
			return
		await physics_frame
	check(false, "Curtain restart timed out")
