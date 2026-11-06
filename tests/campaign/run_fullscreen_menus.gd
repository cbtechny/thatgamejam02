extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1920,1080)
	for mode: String in ["PauseMenu", "MissScreen", "WinScreen"]:
		paused = false
		change_scene_to_file("res://Level/level_1_music_box.tscn")
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage._process(2.2)
		var room: Node = stage._room
		match mode:
			"PauseMenu": room._show_pause_menu()
			"MissScreen": room._show_miss_screen()
			"WinScreen":
				room._show_win_screen()
				room._finish_win_presentation()
		await process_frame
		var backdrop: Control = stage.find_child(mode, true, false)
		check(backdrop != null and backdrop.get_viewport() == root, mode + " uses main viewport instead of clipped gameplay viewport")
		if backdrop != null and backdrop.get_viewport() == root:
			for extent: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(1080,1080)]:
				root.size = extent
				await process_frame
				await process_frame
				check(backdrop.get_global_rect().is_equal_approx(root.get_visible_rect()), mode + " covers viewport after resize")
			root.size = Vector2i(1920,1080)
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/fullscreen-%s.png" % mode)
		if mode == "PauseMenu":
			room._resume_from_pause()
			await process_frame
			check(not paused and stage.find_child(mode, true, false) == null, "Resume removes full-screen pause overlay")
		if mode == "WinScreen" and backdrop.get_viewport() == root:
			var button: Button
			for child: Node in backdrop.find_children("*", "Button", true, false):
				if child.text == "Continue to the ocean": button = child
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = button.get_global_rect().get_center()
			event.pressed = true
			root.push_input(event, true)
			event = event.duplicate()
			event.pressed = false
			root.push_input(event, true)
			await process_frame
			await process_frame
			check(not paused and current_scene.scene_file_path.contains("level_2_ocean"), "Full-screen victory Continue works with mouse")
	paused = false
	current_scene.free()
	await process_frame
	print("Fullscreen menus: %d failures" % failures)
	quit(1 if failures else 0)
