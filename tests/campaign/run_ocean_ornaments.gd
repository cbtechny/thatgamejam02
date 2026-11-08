extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920, 1080)
	for n: int in [2, 3]:
		change_scene_to_file("res://dev/level_%d_ocean/level_%d_ocean.tscn" % [n, n])
		await process_frame
		await _wait_for_scene_fade()
		await process_frame
		await _wait_for_scene_fade()
		var room: Node = current_scene.get_node("MusicBox/RoomClip/Room")
		var art: Node2D = room.get_node("OceanScenery")
		assert(art.night_mode == (n == 3))
		assert(art.show_behind_parent and art._bounds == room._scenery_bounds)
		if art.night_mode:
			var mask: ShaderMaterial = room.get_node("NightMask/Darkness").material
			assert(mask.get_shader_parameter("night_scenery") == art.NIGHT_COAST)
		await create_timer(2.4).timeout
		assert(not is_instance_valid(current_scene._outside_backdrop))
		if not art.night_mode:
			room.reset_level()
			var initial: Vector2 = art._mist_center(0)
			await create_timer(0.2).timeout
			assert(initial != art._mist_center(0))
			paused = true
			var held: Vector2 = art._mist_center(0)
			await create_timer(0.1).timeout
			assert(held == art._mist_center(0))
			paused = false
			room.reset_level()
			assert(initial == art._mist_center(0))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/level%d-scenery-preview.png" % n)
	print("Ocean scenery PASS: aperture fit, day mist motion/pause/reset, night mask texture")
	current_scene.free()
	await process_frame
	await _wait_for_scene_fade()
	quit()


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
