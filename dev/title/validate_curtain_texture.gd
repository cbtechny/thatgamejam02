extends SceneTree

# Compare the actual skinned rendering against an unmodified Sprite2D, including
# transparent space outside the PNG. This catches UV edge-clamping streaks.
func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Texture validation needs a rendering display; omit --headless.")
		quit(1)
		return
	var scene_path := "res://dev/title/curtain.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	var scene: Node2D = load(scene_path).instantiate()
	var mesh: Polygon2D = scene.get_node("Polygon2D")
	# The editor may save an in-progress animated pose (for example, Row03
	# translated left). Compare texture mapping in rest pose, not that pose.
	scene.transform = Transform2D.IDENTITY
	var player: AnimationPlayer = scene.get_node("AnimationPlayer")
	player.autoplay = ""
	for bone in scene.get_node("Skeleton2D").find_children("*", "Bone2D", true, false):
		bone.apply_rest()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	var actual := await _capture(viewport)
	scene.visible = false
	var reference := Sprite2D.new()
	reference.texture = mesh.texture
	reference.centered = false
	viewport.add_child(reference)
	var expected := await _capture(viewport)
	var stretched_pixels := 0
	var missing_pixels := 0
	var extra_pixels := 0
	for y in viewport.size.y:
		for x in viewport.size.x:
			var source := expected.get_pixel(x, y)
			var result := actual.get_pixel(x, y)
			if source.a > 0.99 and result.a > 0.99:
				var error := maxf(absf(source.r - result.r), maxf(absf(source.g - result.g), absf(source.b - result.b)))
				if error > 0.04:
					stretched_pixels += 1
			elif source.a > 0.99 and result.a < 0.5:
				missing_pixels += 1
			elif source.a < 0.01 and result.a > 0.5:
				extra_pixels += 1
	var passed := stretched_pixels < 100 and missing_pixels < 100 and extra_pixels < 100
	print("CURTAIN_TEXTURE_%s stretched=%d missing=%d extra=%d" % ["PASS" if passed else "FAIL", stretched_pixels, missing_pixels, extra_pixels])
	quit(0 if passed else 1)

func _capture(viewport: SubViewport) -> Image:
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
