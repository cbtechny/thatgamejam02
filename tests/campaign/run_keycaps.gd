extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	root.push_input(event, true)
func mouse(button: Button, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = button.get_global_rect().get_center()
	root.push_input(event, true)
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/keycaps-" + label + ".png")
func run() -> void:
	var reference_bounds: Dictionary = {}
	for number: int in [1,2,3]:
		change_scene_to_file("res://Level/level_1_music_box.tscn" if number == 1 else "res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number,number])
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage._process(3.0)
		var room: Node = stage._room
		var space: Button = room._space_keycap if number == 1 else room._fire_button
		var restart: Button = room._restart_keycap if number == 1 else room._reset_button
		for extent: Vector2i in [Vector2i(1920,1080),Vector2i(1080,1080),Vector2i(1280,720)]:
			root.size = extent
			await process_frame
			await process_frame
			check(root.get_visible_rect().encloses(space.get_global_rect()), "Space keycap fits viewport")
			check(root.get_visible_rect().encloses(restart.get_global_rect()), "R keycap fits viewport")
			var space_bounds: Rect2 = space.get_global_rect()
			var restart_bounds: Rect2 = restart.get_global_rect()
			if number == 1:
				reference_bounds[extent] = [space_bounds, restart_bounds]
				var display: Control = stage.get_node("MusicBox/RoomClip/Room")
				var crank_radius: float = room.CRANK_KNOB_LOCAL_POSITION.length() * room._crank.scale.x + room.CRANK_HIT_RADIUS
				var sweep := Rect2(room._crank.position - Vector2.ONE * crank_radius, Vector2.ONE * crank_radius * 2.0)
				check(not space_bounds.merge(restart_bounds).intersects(display.get_global_transform() * sweep), "Level 1 keycaps clear the crank's full drag area")
			else:
				var expected: Array = reference_bounds[extent]
				check(space_bounds.is_equal_approx(expected[0]) and restart_bounds.is_equal_approx(expected[1]), "Level %d matches the Level 1 keycap layout" % number)
			await capture("level%d-%d" % [number,extent.x])
		if number == 1:
			check(not room._release_hint.visible, "Old black instruction bar is hidden")
			check(not space.disabled and restart.disabled, "Only valid actions are enabled")
		room.set_process(false)
		var visual: Node = space.get_node("KeycapVisual")
		var bounds: Rect2 = space.get_global_rect()
		mouse(space,true)
		await create_timer(0.05).timeout
		check(visual._travel > 0.5, "Mouse press visibly depresses the keycap")
		check(space.get_global_rect().is_equal_approx(bounds), "Animation leaves clickable bounds fixed")
		await capture("level%d-pressed" % number)
		mouse(space,false)
		check(room._released if number == 1 else room._state == room.State.HOPPING, "Mouse keycap triggers the same gameplay action")
		if number != 1:
			restart.grab_focus()
			key(KEY_R,true)
			key(KEY_R,false)
			key(KEY_SPACE,true)
			await create_timer(0.04).timeout
			check(room._state == room.State.HOPPING, "Keyboard Space fires despite Reset focus")
			check(visual._travel > 0.0, "Keyboard Space visibly depresses keycap in level %d" % number)
			await create_timer(0.2).timeout
			check(visual._travel > 0.8, "Held Space remains visually depressed until release")
			key(KEY_SPACE,false)
		else:
			room._mark_missed()
			check(not restart.disabled and space.disabled, "Failure enables R and disables release immediately")
			await capture("level1-failure")
	paused = false
	current_scene.free()
	var session: Node = root.get_node("ReleaseSession")
	session.music.stop()
	session.music.stream = null
	await create_timer(0.1).timeout
	print("3D keycaps: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
