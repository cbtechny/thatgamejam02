extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920, 1080)
	for n: int in [2, 3]:
		change_scene_to_file("res://dev/level_%d_ocean/level_%d_ocean.tscn" % [n, n])
		await process_frame
		await process_frame
		var room: Node = current_scene.get_node("MusicBox/RoomClip/Room")
		var art: Node2D = room.get_node("BackgroundOrnaments")
		assert(art.get_child_count() == 4)
		await create_timer(2.4).timeout
		var before: Vector2 = art.get_child(0).position
		await create_timer(0.2).timeout
		assert(before != art.get_child(0).position)
		paused = true
		var held: Vector2 = art.get_child(0).position
		await create_timer(0.1).timeout
		assert(held == art.get_child(0).position)
		paused = false
		room.reset_level()
		art._process(0.0)
		assert(is_zero_approx(room._elapsed_time))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/level%d-ornaments-preview.png" % n)
	print("Ocean ornaments PASS: both modes, motion, pause, reset, 4 shared assets")
	current_scene.free()
	await process_frame
	quit()
