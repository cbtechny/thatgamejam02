extends SceneTree
## Quiet failure and curtain-only restart in the campaign and standalone scene.

var failures: int = 0
var checks: int = 0
var capture: bool = false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
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

func save(label: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level1-restart-qa/%s.png" % label)

func finish_restart() -> void:
	for frame: int in range(480):
		if root.get_node_or_null("Level1RestartCurtains") == null:
			return
		await physics_frame
	check(false, "Restart completes within both authored curtain durations")

func run() -> void:
	for extent: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = extent
		change_scene_to_file("res://Level/level_1_music_box.tscn")
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage._process(3.0)
		var room: Node = stage._room
		var initial_transform: Transform2D = stage._box.transform
		var music_id: int = root.get_node("ReleaseSession").music.get_instance_id()
		# A real low release must miss without opening a modal or pausing.
		room._release_key()
		for frame: int in range(240):
			if room._missed:
				break
			await physics_frame
		check(room._missed and not paused, "Real miss leaves gameplay unpaused")
		check(stage.find_child("MissScreen", true, false) == null, "No miss modal is created")
		check(room._release_hint.text == "Hit R to restart", "Minimal restart hint is shown")
		var pulse: float = room._middle_fan_pulse_time
		await create_timer(0.1).timeout
		check(room._middle_fan_pulse_time != pulse, "Target motion continues after a miss")
		await save("miss-%d" % extent.x)
		key(KEY_ESCAPE)
		await process_frame
		check(paused and room._pause_menu_open, "Escape remains available after failure")
		room._resume_from_pause()
		key(KEY_R, true)
		check(root.get_node_or_null("Level1RestartCurtains") == null, "Held-key echo cannot restart")
		key(KEY_R)
		await process_frame
		var curtains: Node = root.get_node_or_null("Level1RestartCurtains")
		check(curtains != null and curtains.get_viewport() == root, "Curtains cover the main viewport")
		check(room._presentation_locked and not paused, "Restart locks gameplay without pausing the theme")
		key(KEY_R)
		check(root.find_children("Level1RestartCurtains", "CanvasLayer", false, false).size() == 1, "Repeated R creates one transition")
		await create_timer(1.0).timeout
		check(stage._room == room, "Puzzle is retained while curtains close")
		check(stage._box.transform.is_equal_approx(initial_transform), "Closing curtains do not move the camera")
		await save("closing-%d" % extent.x)
		# Changing size mid-transition must resize the screen-level curtains.
		root.size = Vector2i(1080, 1080)
		await process_frame
		check(curtains._stage.scale.is_equal_approx(root.get_visible_rect().size / Vector2(1920, 1080)), "Curtains resize while moving")
		root.size = extent
		await process_frame
		for frame: int in range(240):
			if stage._room != room:
				break
			await physics_frame
		check(stage._room != room and stage._room._presentation_locked, "Puzzle resets while the curtain reveal still locks input")
		if capture:
			for player: AnimationPlayer in curtains._players:
				player.seek(0.0, true)
				player.pause()
			await save("closed-%d" % extent.x)
			for player: AnimationPlayer in curtains._players:
				player.play(&"curtain")
		await finish_restart()
		check(current_scene == stage and stage._room != room, "Only the puzzle instance is replaced")
		room = stage._room
		check(stage._entrance_finished and stage._box.transform.is_equal_approx(initial_transform), "Retry retains the completed entrance and framing")
		check(not room._released and not room._missed and not room._presentation_locked and not room._transitioning, "New puzzle is fresh and input is unlocked")
		check(root.get_node("ReleaseSession").music.get_instance_id() == music_id, "Restart retains the theme player")
		await save("reopened-%d" % extent.x)
		# The visible tail must not freeze at the old center-only boundary.
		room._release_key()
		room._key.global_position = Vector2(1942, 350)
		room._key.linear_velocity = Vector2(600, 0)
		room._mark_missed()
		var position: Vector2 = room._key.global_position
		await physics_frame
		await physics_frame
		check(not room._key.freeze and room._key.global_position != position, "Visible fragment keeps flying after miss registration")
		for frame: int in range(90):
			if room._key.freeze:
				break
			await physics_frame
		check(room._key.freeze and not room._key.visible and not paused, "Fully offscreen fragment is cleaned up without pausing")
	# The exported campaign intentionally omits the standalone development scene.
	if not OS.get_cmdline_user_args().has("--campaign-only"):
		change_scene_to_file("res://dev/Level 1 - Alt/level_1.tscn")
		await process_frame
		await process_frame
		var standalone: Node = current_scene
		standalone._mark_missed()
		key(KEY_R)
		await finish_restart()
		check(current_scene != standalone and not current_scene._missed and not current_scene._presentation_locked, "Standalone scene uses the same curtain restart")
		current_scene.free()
	await process_frame
	var session: Node = root.get_node("ReleaseSession")
	session.music.stop()
	session.music.stream = null
	print("Level 1 curtain restart: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
