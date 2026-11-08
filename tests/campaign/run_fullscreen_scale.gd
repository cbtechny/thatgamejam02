extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var paths: Array[String] = ["res://Level/level_1_music_box.tscn", "res://dev/level_2_ocean/level_2_ocean.tscn", "res://dev/level_3_ocean/level_3_ocean.tscn"]
	var reference: Dictionary = {}
	for index: int in range(paths.size()):
		change_scene_to_file(paths[index])
		await process_frame
		await _wait_for_scene_fade()
		await process_frame
		await _wait_for_scene_fade()
		var stage: Node = current_scene
		stage.set_process(false)
		for extent: Vector2 in [Vector2(1920,1080), Vector2(1280,720), Vector2(1080,1080)]:
			for time: float in [0.0, 1.25, 2.15]:
				stage._entrance_elapsed = time
				stage._apply_layout(extent)
				var key: String = "%s/%s" % [extent, time]
				var pose: Transform2D = stage._box.transform
				if index == 0:
					reference[key] = pose
				else:
					check(pose.is_equal_approx(reference[key]), "All stages share camera transform at %s" % key)
			var bounds: Rect2
			if index == 0:
				var display: Control = stage.get_node("MusicBox/RoomClip/Room")
				bounds = Rect2(display.global_position, display.size * display.get_global_transform().get_scale())
			else:
				bounds = Rect2(stage._room.global_position, Vector2(360,200) * stage._room.get_global_transform().get_scale())
			var key: String = "bounds/%s" % extent
			if index == 0:
				reference[key] = bounds
			else:
				var expected: Rect2 = reference[key]
				check(bounds.position.distance_to(expected.position) < 0.1 and bounds.size.distance_to(expected.size) < 0.1, "All stages share playable bounds at %s" % extent)
		if DisplayServer.get_name() != "headless":
			root.mode = Window.MODE_FULLSCREEN
			await create_timer(0.15).timeout
			stage._fit_viewport()
			var actual: Transform2D = stage._box.transform
			if index == 0:
				reference["fullscreen"] = actual
			else:
				check(actual.is_equal_approx(reference["fullscreen"]), "All stages share fullscreen framing")
			root.mode = Window.MODE_WINDOWED
			await process_frame
			await _wait_for_scene_fade()
	print("Three-stage scale parity: %d failures" % failures)
	current_scene.free()
	await process_frame
	await _wait_for_scene_fade()
	quit(1 if failures else 0)


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
