extends SceneTree

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	var menu: Control = load("res://Level/title_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var player: AnimationPlayer = menu.get_node("Curtain/AnimationPlayer")
	var right: AnimationPlayer = menu.get_node("RightCurtainAnchor/Curtain/AnimationPlayer")
	var anchor: Node2D = menu.get_node("RightCurtainAnchor")
	assert(anchor.scale == Vector2(-1, 1) and anchor.position.x == menu.size.x)
	var button: Button = menu.get_node("ContentMargins/MainBdy/ButtonContainer/PlayButton")
	var source: Node = load("res://dev/title/curtain.tscn").instantiate()
	var original: Animation = source.get_node("AnimationPlayer").get_animation("curtain")
	assert(original.loop_mode == Animation.LOOP_LINEAR)
	assert(player.get_animation("curtain") != original)
	assert(player.get_animation("curtain").loop_mode == Animation.LOOP_NONE)
	assert(menu.get_node("Curtain").z_index < menu.get_node("ContentMargins").z_index)
	assert(not player.is_playing() and not button.disabled)
	assert(not right.is_playing() and is_zero_approx(right.current_animation_position))
	assert(is_zero_approx(player.current_animation_position))
	var left_mesh: Polygon2D = menu.get_node("Curtain/Polygon2D")
	var right_mesh: Polygon2D = menu.get_node("RightCurtainAnchor/Curtain/Polygon2D")
	assert(left_mesh.texture.resource_path.ends_with("/T_Curtain.png"))
	assert(right_mesh.texture.resource_path.ends_with("/T_CurtainRight.png"))
	for bone: Bone2D in menu.find_children("*", "Bone2D", true, false):
		assert(bone.transform.is_equal_approx(bone.rest), "The first frame must close both curtains")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	right.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	button.pressed.emit()
	assert(player.is_playing() and button.disabled)
	assert(right.is_playing())
	player.advance(0.75)
	right.advance(0.75)
	assert(player.current_animation_position == right.current_animation_position)
	var left_curtain: Node2D = menu.get_node("Curtain")
	var right_curtain: Node2D = menu.get_node("RightCurtainAnchor/Curtain")
	assert(is_equal_approx(left_curtain.global_position.x + right_curtain.global_position.x, menu.size.x))
	assert(is_equal_approx(player.current_animation_position, 0.75))
	button.pressed.emit()
	assert(is_equal_approx(player.current_animation_position, 0.75), "Repeated presses restarted playback")
	player.advance(original.length)
	assert(button.disabled, "Wait for both curtains to finish")
	right.advance(original.length)
	await scene_changed
	assert(current_scene.scene_file_path == "res://Level/level_1_music_box.tscn")
	assert(original.loop_mode == Animation.LOOP_LINEAR)
	source.free()
	print("MENU_CURTAIN_PASS distinct_textures=true closed_pose=true synchronized_playback=true waits_for_both=true repeated_press_guard=true enters_level_1=true authored_loop_preserved=true")
	quit()
