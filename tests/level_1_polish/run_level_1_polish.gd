extends SceneTree
## Focused presentation regression using the authored crank, flight and menus.

const LevelOne = preload("res://dev/Level 1 - Alt/level_1.gd")
const LEVEL_SCENE: PackedScene = preload("res://dev/Level 1 - Alt/level_1.tscn")

var _checks: int = 0
var _failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _new_level() -> LevelOne:
	var level: LevelOne = LEVEL_SCENE.instantiate() as LevelOne
	root.add_child(level)
	current_scene = level
	return level


func _press_key(keycode: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventKey = InputEventKey.new()
	release.keycode = keycode
	root.push_input(release, true)


func _wind(level: LevelOne, angle: float) -> void:
	var crank: Node2D = level._crank
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = crank.to_global(Vector2(576.0, 0.0))
	root.push_input(press, true)
	for index: int in range(1, 15):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = crank.to_global(Vector2.from_angle(angle * float(index) / 14.0) * 576.0)
		root.push_input(motion, true)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	# Release over the hint's GUI rectangle to check stale dragging too.
	release.position = level._release_hint.get_global_rect().get_center()
	root.push_input(release, true)
	# Synchronize the frozen RigidBody transform before releasing it.
	await physics_frame
	await physics_frame


func _all_highlights_off(level: LevelOne) -> bool:
	for highlight: HighlightPulse in [level._crank_highlight, level._fan_highlight, level._center_highlight, level._third_piece_highlight, level._keyhole_highlight]:
		if highlight.active:
			return false
	return true


func _run() -> void:
	var level: LevelOne = _new_level()
	level.set_process(false)
	_expect(level._crank_highlight.active and not level._fan_highlight.active and not level._center_highlight.active, "Idle guidance singles out the crank")
	_expect(not level._third_piece_highlight.active and not level._keyhole_highlight.active, "Later objectives stay unhighlighted before a catch")
	_expect(level._release_hint.text.contains("crank"), "Idle hint explains the crank")
	_expect(level._key_sparkles.get_parent() == level._key_sprite and level._key_sparkles.global_position.is_equal_approx(level._key_sprite.global_position), "Sparkles follow the visible hanging fragment")
	_expect(not level._middle_key_sparkles.emitting and not level._third_piece_sparkles.emitting, "Inactive pieces do not sparkle prematurely")
	_expect(level._fan_highlight.get_parent() == level._left_fan_blades, "Fan halo is centered on the spinning blades")
	_expect(level._third_piece_highlight.get_parent() == level._key3_placeholder, "Last-piece halo targets the existing world piece")
	_expect(level._ui_key0.scale == Vector2(0.3, 0.3) and level._key_sprite.position.is_equal_approx(Vector2(1.0, 202.0)), "Compact HUD preserves authored gameplay sprite offset")
	await create_timer(0.2).timeout
	await _save("after-idle.png")
	await _wind(level, 3.0)
	_expect(level._crank_used and not level._dragging_crank, "Crank motion advances guidance and release clears drag over GUI")
	_expect(not level._crank_highlight.active and level._fan_highlight.active and level._center_highlight.active, "Winding highlights fan and moving catch target")
	_expect(level._middle_key_sparkles.emitting and level._release_hint.text.contains("Space"), "Winding enables target sparkles and release hint")
	_expect(is_equal_approx(level._key.global_position.y, 110.0), "Crank retains existing movement and clamp")
	await create_timer(0.15).timeout
	await _save("after-ready-to-release.png")
	_press_key(KEY_ESCAPE)
	_expect(paused and level._pause_menu_open and not level._dragging_crank, "Escape still pauses and clears held crank state")
	_press_key(KEY_ESCAPE)
	await process_frame
	await _wait_for_scene_fade()
	_expect(not paused and not level._pause_menu_open, "Escape resumes through the existing overlay")
	# Start the same pulse phase used to establish this baseline release.
	level._middle_fan_pulse_time = 0.0
	level._process(0.0)
	_press_key(KEY_SPACE)
	level.set_process(true)
	_expect(level._released and not level._key.freeze and level._rope_bodies.size() == 32, "Space retains authored release, physics and loose rope")
	_expect(not level._crank_highlight.active and not level._fan_highlight.active and level._center_highlight.active, "Flight guidance focuses on the catch target")
	_press_key(KEY_SPACE)
	_expect(level._rope_bodies.size() == 32, "Repeated Space does not duplicate release or rope")
	for tick: int in range(110):
		await physics_frame
		if level._key_snapped or level._missed:
			break
	_expect(level._key_snapped and not level._missed, "Real crank release catches the moving piece with unchanged physics")
	if level._key_snapped:
		await _check_assembly(level)
	paused = false
	level.queue_free()
	await process_frame
	await _wait_for_scene_fade()
	await _check_miss_and_retry()
	await _check_exit_and_retry_during_assembly()
	await _check_pause_actions()
	await create_timer(0.15).timeout
	print("Level 1 polish: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _check_assembly(level: LevelOne) -> void:
	var shaft_position: Vector2 = level._middle_key.global_position
	var fan_position: Vector2 = level._left_fan.position
	var sequence: Tween = level._assembly_tween
	_expect(sequence != null and not level._left_fan_active and not level._middle_fan_active, "Catch starts one assembly sequence and stops both fans")
	_expect(level._third_world_piece == level._key3_placeholder and level.find_children("Key2World", "Sprite2D", true, false).is_empty(), "Assembly reuses the visible last fragment without duplicating it")
	_expect(level._third_piece_highlight.active and level._third_piece_sparkles.emitting, "Last fragment highlights and sparkles only when it joins")
	_expect(level._ui_key2.self_modulate != Color.WHITE, "Third HUD fragment is not marked collected before joining")
	level._process(0.5)
	_expect(level._middle_key.global_position == shaft_position and level._left_fan.position == fan_position, "Caught target and fan no longer drift during assembly")
	var joining_hint: String = level._release_hint.text
	level._set_middle_fan_active(false)
	_expect(level._release_hint.text == joining_hint, "Fan state changes cannot overwrite assembly hint")
	level._celebrate_key_connection()
	_expect(level._assembly_tween == sequence, "Repeated contact cannot start duplicate assembly")
	await create_timer(0.3).timeout
	await _save("after-joining.png")
	for tick: int in range(50):
		if level._key_sprite.texture == level.FULL_KEY_TEXTURE:
			break
		await physics_frame
	var expected_center: Vector2 = shaft_position - level.KEY_SHAFT_ASSEMBLY_OFFSET
	_expect(level._key_sprite.texture == level.FULL_KEY_TEXTURE, "Three pieces become the complete key")
	_expect(level._key_sprite.global_position.distance_to(expected_center) < 3.0, "Complete-key swap preserves the assembly position instead of jumping")
	_expect(not level._middle_key.visible and not level._key3_placeholder.visible, "Joined loose sprites disappear together")
	_expect(level._ui_key2.self_modulate == Color.WHITE and level._keyhole_highlight.active, "Final collection reveals HUD fragment and highlights keyhole")
	_expect(not level._middle_key_sparkles.emitting and not level._third_piece_sparkles.emitting, "Hidden fragments stop emitting sparkles")
	_expect(level._release_hint.text.contains("lock"), "Delivery hint survives the fan pulse clock")
	await _save("after-assembled.png")
	for tick: int in range(90):
		if paused:
			break
		await physics_frame
	_expect(paused and level._ui.get_node_or_null("WinScreen") != null, "Win presentation completes and pauses without waiting on finished tweens")
	var expected_destination: Vector2 = level._keyhole.global_position - Vector2(level.FULL_KEY_TEXTURE.get_width() * 0.4 * 0.5 - 8.0, 0.0)
	_expect(level._key_sprite.global_position.distance_to(expected_destination) < 0.1, "Delivery aligns the key tip with the lock")
	_expect(_all_highlights_off(level) and not level._key_sparkles.emitting, "Completion clears gameplay guidance and continuous sparkle emitters")
	_expect(level._middle_key.global_position == shaft_position and level._left_fan.position == fan_position, "Assembly never resumes target bob or drags the fan with the completed key")
	await _save("after-win.png")


func _check_miss_and_retry() -> void:
	var level: LevelOne = _new_level()
	_press_key(KEY_SPACE)
	for tick: int in range(150):
		await physics_frame
		if level._missed:
			break
	_expect(level._missed and not paused and level._ui.get_node_or_null("MissScreen") == null and level._release_hint.text == "Missed. Press R to restart.", "Low release reaches the quiet restart hint without pausing")
	_expect(_all_highlights_off(level) and not level._key_sparkles.emitting and not level._middle_key_sparkles.emitting, "Miss stops misleading highlights and sparkles")
	_expect(not level._left_fan_active, "Miss stops the launch fan without pausing the scene")
	await _save("after-miss.png")
	level._retry_level()
	await _wait_restart()
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	var replacement: LevelOne = current_scene as LevelOne
	_expect(replacement != null and replacement != level and not replacement._released and not paused, "Curtain retry restores fresh gameplay without pausing")
	if replacement != null:
		_expect(replacement._crank_highlight.active and not replacement._center_highlight.active, "Retry restores initial guidance")
		replacement.queue_free()
	await process_frame
	await _wait_for_scene_fade()
func _begin_catch_fixture(level: LevelOne) -> void:
	level._release_key()
	level._key.freeze = true
	level._key.global_position += level._key1_endpoint.global_position - level._key0_endpoint.global_position
	level._key_snapped = true
	level._celebrate_key_connection()


func _check_exit_and_retry_during_assembly() -> void:
	var level: LevelOne = _new_level()
	_begin_catch_fixture(level)
	var sequence: Tween = level._assembly_tween
	await create_timer(0.2).timeout
	level._retry_level()
	await _wait_restart()
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	_expect(not sequence.is_valid(), "Retry cancels the in-flight assembly sequence")
	var replacement: LevelOne = current_scene as LevelOne
	await create_timer(0.8).timeout
	_expect(replacement != null and not replacement._key_snapped and replacement._ui.get_node_or_null("WinScreen") == null and not paused, "Old callbacks cannot complete or pause the replacement level")
	if replacement != null:
		_begin_catch_fixture(replacement)
		var exiting_sequence: Tween = replacement._assembly_tween
		replacement.queue_free()
		await process_frame
		await _wait_for_scene_fade()
		_expect(not exiting_sequence.is_valid(), "Scene exit cancels assembly without orphaned callbacks")
	await process_frame
	await _wait_for_scene_fade()
	_expect(not paused, "Exiting during assembly does not later pause the tree")


func _save(file_name: String) -> void:
	if not _capture:
		return
	await process_frame
	await _wait_for_scene_fade()
	await RenderingServer.frame_post_draw
	var folder: String = "res://.godot/level1_polish_qa"
	DirAccess.make_dir_recursive_absolute(folder)
	_expect(root.get_texture().get_image().save_png(folder.path_join(file_name)) == OK, "Saved " + file_name)


func _check_pause_actions() -> void:
	var level: LevelOne = _new_level()
	level._show_pause_menu()
	var menu: Node = level._get_menu_ui().get_node("PauseMenu")
	for button: Node in menu.find_children("*", "Button", true, false):
		_expect(button.text != "Return to Title", "Level 1 pause has no title button")
	level._resume_from_pause()
	level.queue_free()
	await process_frame
	await _wait_for_scene_fade()



func _wait_restart() -> void:
	for frame: int in range(480):
		if root.get_node_or_null("Level1RestartFade") == null:
			return
		await physics_frame
	_expect(false, "Curtain restart timed out")


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
