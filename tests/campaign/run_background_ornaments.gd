extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://dev/Level 1 - Alt/level_1.tscn")
	await process_frame
	await process_frame
	var ornaments: Node = current_scene.get_node("BoxWindow/BackgroundOrnaments")
	assert(ornaments.get_child_count() == 4)
	for sprite: Sprite2D in ornaments.get_children():
		var pixels: Image = sprite.texture.get_image()
		assert(pixels.get_pixel(0, 0).a < 0.01)
		assert(pixels.get_pixel(pixels.get_width()/2, pixels.get_height()/2).a > 0.9)
	var start: float = ornaments.get_child(0).rotation
	await create_timer(0.15).timeout
	assert(ornaments.get_child(0).rotation != start)
	paused = true
	var held: float = ornaments.get_child(0).rotation
	await create_timer(0.1).timeout
	assert(ornaments.get_child(0).rotation == held)
	paused = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/background-ornaments-preview.png")
	print("Background ornaments PASS: 4 transparent textures, rotation, pause")
	quit()
