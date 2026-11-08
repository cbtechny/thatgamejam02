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
func photograph(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await _wait_for_scene_fade()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/restart-" + label + ".png")
func run() -> void:
	for number: int in [1, 2, 3]:
		paused = false
		change_scene_to_file("res://Level/level_1_music_box.tscn" if number == 1 else "res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number])
		await process_frame
		await _wait_for_scene_fade()
		await process_frame
		await _wait_for_scene_fade()
		var stage: Node = current_scene
		stage._process(3.0)
		var room: Node = stage._room
		room.set_process(false)
		if number == 1:
			check(room._failure_restart == null, "Level One restart cue absent before failure")
			room._mark_missed()
		else:
			check(not room._reset_prompt.active, "Ocean restart cue inactive before failure")
			room._touchdown_time = room._elapsed_time
			room._fragment.position = Vector2(-1000, -1000)
			room._land()
		var button: Button = room._failure_restart if number == 1 else room._reset_button
		var cue: Node = button.get_node("RestartPrompt")
		var face: StyleBoxFlat = button.get_node("KeycapVisual/KeyFace").get_theme_stylebox("panel")
		check(cue.active and not button.disabled, "Failed run enables a usable restart cue")
		check(cue._audio.volume_db <= -36.0 and cue._audio.bus == &"Master", "Beep is very quiet and respects Master mute")
		var rect: Rect2 = button.get_global_rect()
		cue._process(0.1)
		var first_size: int = face.shadow_size
		cue._process(0.5)
		check(face.shadow_size != first_size, "Visible keycap face actually pulses")
		check(button.get_global_rect().is_equal_approx(rect), "Pulse leaves button bounds unchanged")
		for extent: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720)]:
			root.size = extent
			await process_frame
			await _wait_for_scene_fade()
			await photograph("level%d-%d" % [number, extent.x])
		if number == 1:
			room._show_pause_menu()
		else:
			room._campaign_menu.show_menu(false)
		await process_frame
		await _wait_for_scene_fade()
		var menu: Node = stage.find_child("PauseMenu", true, false) if number == 1 else room._campaign_menu.panel
		var retry: Button
		for child: Node in menu.find_children("*", "Button", true, false):
			if child.text == "Restart":
				retry = child
		check(retry != null and retry.get_node("RestartPrompt").active, "Paused failed run also highlights Restart")
		await photograph("level%d-pause" % number)
		if number == 1:
			room._resume_from_pause()
			check(button.visible and cue.active, "Resume restores Level One restart cue")
			button.pressed.emit()
			for frame: int in range(480):
				if root.get_node_or_null("Level1RestartFade") == null:
					break
				await physics_frame
			await process_frame
			await _wait_for_scene_fade()
			check(not current_scene._room._missed and current_scene._room._failure_restart == null, "Restart clears Level One cue")
		else:
			room._campaign_menu.resume()
			room._reset_button.pressed.emit()
			check(root.get_node("SceneFade").busy and room._presentation_locked, "Ocean Restart starts the shared black fade")
			await _wait_for_scene_fade()
			check(not cue.active and not cue._audio.playing and face.shadow_size == 0, "Restart clears the glow and stops beep")
			room._state = room.State.COMPLETED
			room._update_guidance()
			check(not cue.active, "Success never pulses restart")
	paused = false
	current_scene.free()
	await process_frame
	await _wait_for_scene_fade()
	print("Restart cues: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
