extends SceneTree
## Fast black restart, real R input, camera retention, and fresh puzzle state.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
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
func run() -> void:
	for extent: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size = extent
		change_scene_to_file("res://Level/level_1_music_box.tscn")
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage._process(3.0)
		var room: Node = stage._room
		var original: Transform2D = stage._box.transform
		var music_id: int = root.get_node("ReleaseSession").music.get_instance_id()
		room._mark_missed()
		key(KEY_R, true)
		check(root.get_node_or_null("Level1RestartFade") == null, "Echo does not restart")
		key(KEY_R)
		check(root.get_node_or_null("Level1RestartFade") != null, "R starts black restart")
		check(room._presentation_locked and not paused, "Restart locks input without pausing music")
		key(KEY_R)
		check(root.find_children("Level1RestartFade", "CanvasLayer", false, false).size() == 1, "Repeat R starts only one fade")
		var fade: Node = root.get_node("SceneFade")
		var saw_black: bool = false
		for frame: int in range(30):
			await process_frame
			saw_black = saw_black or fade._cover.modulate.a > 0.0
			if root.get_node_or_null("Level1RestartFade") == null:
				break
		check(saw_black, "Screen actually fades toward black")
		root.size = Vector2i(1080,1080)
		await process_frame
		check(fade._cover.get_global_rect().is_equal_approx(root.get_visible_rect()), "Black cover fits resized viewport")
		root.size = extent
		await create_timer(0.35).timeout
		check(not fade.busy and root.get_node_or_null("Level1RestartFade") == null, "Fast restart finishes in under half a second")
		check(stage._room != room and current_scene == stage, "Only the puzzle is replaced")
		room = stage._room
		check(stage._box.transform.is_equal_approx(original) and stage._entrance_finished, "Restart keeps camera and skips entrance")
		check(not room._missed and not room._released and not room._transitioning and not room._presentation_locked, "Fresh puzzle accepts input")
		check(root.get_node("ReleaseSession").music.get_instance_id() == music_id, "Music player is retained")
		check(stage.find_children("*", "AnimationPlayer", true, false).is_empty(), "Restart creates no curtain animations")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/fast-restart-%d.png" % extent.x)
	if not OS.get_cmdline_user_args().has("--campaign-only"):
		change_scene_to_file("res://dev/Level 1 - Alt/level_1.tscn")
		await process_frame
		await process_frame
		var original: Node = current_scene
		original._mark_missed()
		key(KEY_R)
		await create_timer(0.4).timeout
		check(current_scene != original and not current_scene._missed and not current_scene._presentation_locked, "Standalone restart also uses fast fade")
	current_scene.free()
	print("Level 1 fast restart: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
