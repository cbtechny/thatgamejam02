extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://dev/Level 1 - Alt/level_1.tscn")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	current_scene._continue_campaign()
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	assert(current_scene.scene_file_path.contains("level_2_ocean"))
	for n in [2, 3]:
		var room: Node = current_scene.get_node("MusicBox/RoomClip/Room")
		var menu: Node = room._campaign_menu
		menu.show_menu(false)
		assert(paused)
		var elapsed: float = room._elapsed_time
		await process_frame
		await _wait_for_scene_fade()
		assert(room._elapsed_time == elapsed)
		menu.resume()
		assert(not paused)
		room._state = 3
		menu.show_menu(true)
		assert(paused)
		menu.advance()
		await process_frame
		await _wait_for_scene_fade()
		await process_frame
		await _wait_for_scene_fade()
		assert(not paused)
	assert(current_scene.scene_file_path == "res://Level/ending.tscn")
	change_scene_to_file("res://Main.tscn")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	assert(not paused)
	print("Campaign PASS: level 1 -> 2 -> 3 -> ending -> Main; pause freezes tide; transitions resume.")
	quit()


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
