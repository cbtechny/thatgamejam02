extends SceneTree
## Headless behavior regression; -- --capture also saves rendered input checks.

const Ocean = preload("res://dev/level_2_ocean/level_2_ocean.gd")
const Presentation = preload("res://dev/level_2_ocean/ocean_music_box.gd")
const OCEAN_SCENE: PackedScene = preload("res://dev/level_2_ocean/level_2_ocean.tscn")

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


func _finish_hop(scene: Ocean) -> void:
	scene._process(scene.hop_duration + 0.01)


func _run() -> void:
	await _check_live_entrance()
	var presentation: Presentation = OCEAN_SCENE.instantiate() as Presentation
	root.add_child(presentation)
	presentation.set_process(false)
	var scene: Ocean = presentation._room as Ocean
	scene.set_process(false)
	var expected_sounds: Dictionary = _sound_snapshot(scene)
	var whirr: AudioStreamPlayer = scene._sfx_players["fan_whirr"] as AudioStreamPlayer
	_expect(scene._presentation_locked and scene._fire_button.disabled, "Establishing view locks gameplay input")
	scene.fire_fan()
	_press_key(KEY_SPACE)
	_expect(scene._state == Ocean.State.RESTING, "Fire cannot start a hop during the entrance")
	_expect(not whirr.playing and not scene._fan_active, "Music-box entrance does not trigger fan audio")
	var wide_scale: Vector2 = presentation._box.scale
	await _save_capture("music-box-establishing.png")
	presentation._process(presentation.establishing_hold + presentation.zoom_duration * 0.5)
	_expect(presentation._box.scale.x > wide_scale.x and scene._presentation_locked, "Entrance smoothly zooms toward room while input remains locked")
	await _save_capture("music-box-zoom-midpoint.png")
	presentation._process(presentation.zoom_duration)
	_expect(presentation._entrance_finished and not scene._presentation_locked and not scene._fire_button.disabled, "Completed entrance unlocks playable room")
	_expect((scene.get_parent() as Control).clip_contents, "Room is clipped inside the music-box opening")
	var room_view: Rect2 = Rect2(scene.global_position, Ocean.REFERENCE_SIZE * scene.get_global_transform().get_scale())
	_expect(root.get_visible_rect().encloses(room_view), "Complete playable room remains inside the viewport")
	for viewport_size: Vector2 in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(1080.0, 1080.0)]:
		presentation._apply_layout(viewport_size)
		room_view = Rect2(scene.global_position, Ocean.REFERENCE_SIZE * scene.get_global_transform().get_scale())
		_expect(Rect2(Vector2.ZERO, viewport_size).encloses(room_view), "Zoomed room fits resized viewport %s" % viewport_size)
	presentation._fit_viewport()
	_expect(is_equal_approx(scene._water_level(), 142.0), "Reset starts at low water")
	_expect(scene._platform_fans.size() == Ocean.Platform.GOAL, "Each launch platform has a fan")
	_expect_platform_fans(scene, -1)
	await _save_capture("day-waiting-at-shore.png")

	# A non-cardinal mouse release must preserve the exact angle and the board X tracks.
	var initial_x: float = scene._deck_position(Ocean.Platform.LOG_1).x
	await _drag_crank(scene, -0.41)
	_expect(is_equal_approx(scene._crank_angle, -0.41), "Mouse release does not snap the crank")
	_expect(is_equal_approx(initial_x, scene._deck_position(Ocean.Platform.LOG_1).x), "Turning the crank changes only board height")
	_expect(scene._water_level() < 142.0 and not scene._dragging_crank, "Tide changes continuously and mouse releases over GUI")
	_expect_platform_fans(scene, -1)
	for platform: int in [Ocean.Platform.LOG_1, Ocean.Platform.LOG_2]:
		var start := scene._deck_at(platform, 0.0)
		var period: float = 5.4 if platform == Ocean.Platform.LOG_1 else 6.2
		_expect(is_equal_approx(scene._deck_at(platform, period).x, start.x), "Board returns along its fixed loop")
		_expect(not is_equal_approx(scene._deck_at(platform, period * 0.5).x, start.x), "The loop keeps moving with a stationary crank")

	# Even a board aligned at takeoff can move out of the landing area in flight.
	scene.reset_level()
	scene._process(1.35)
	_expect(absf(scene._deck_position(Ocean.Platform.LOG_1).x - 104.0) < 1.0, "Board aligns at takeoff")
	_press_key(KEY_SPACE)
	var end: Vector2 = scene._hop_end
	_press_key(KEY_SPACE)
	_press_key(KEY_RIGHT)
	_expect(scene._hop_end == end and is_zero_approx(scene._hop_elapsed), "Repeated fire and crank input cannot move the committed shot")
	_expect(whirr.playing and scene._fan_blades.is_playing(), "Fire starts sound and fan together")
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.FALLING, "Board that leaves before touchdown causes a fall")
	await _save_capture("day-missed-ferry.png")
	scene._process(0.4)
	_press_key(KEY_SPACE)
	_expect(scene._state == Ocean.State.FAILED and not scene._fragment.visible and not whirr.playing, "Miss ends the run and disables the fan")
	_press_key(KEY_R)
	await _wait_for_scene_fade()
	_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.START and scene._fragment.visible, "Retry brings the fragment back to shore")

	scene._set_crank_angle(PI * 0.5)
	scene._process(0.8)
	_press_key(KEY_SPACE)
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.FALLING, "Aligned board at the wrong height still misses")
	scene.reset_level()

	_expect(not scene._fire_button.disabled, "Shore remains launchable at the starting tide")
	scene._process(0.8)
	_press_key(KEY_SPACE)
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_1, "Low tide still reaches Ferry I")
	_expect(scene._fire_button.disabled and scene._feedback.text.begins_with("Raise the tide"), "Pier explains the low-tide height requirement before launch")
	await _save_capture("day-pier-low-tide-guidance.png")
	_press_key(KEY_SPACE)
	_expect(scene._state == Ocean.State.RESTING, "An unreachable Pier shot does not waste the run")
	scene._set_crank_angle(asin(-0.72))
	_expect(not scene._fire_button.disabled, "Raising the tide enables the Pier shot")
	scene._process(4.8 - scene._elapsed_time)
	_press_key(KEY_SPACE)
	_expect(scene._flight_duration < scene.hop_duration, "Pier catches a valid descending shot before the arc endpoint")
	var contact := scene._hop_point(scene._flight_duration / scene.hop_duration)
	var target := scene._deck_position(Ocean.Platform.ROCK) + scene.FRAGMENT_OFFSET
	_expect(absf(contact.x - target.x) <= scene.LANDING_X and absf(contact.y - target.y) <= scene.LANDING_Y, "Early Pier contact obeys the existing landing tolerances")
	_expect(absf(contact.y - target.y) < 0.01, "Pier contact meets the deck surface without a vertical snap")
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.ROCK and not scene._fan_active, "Pier contact lands once and stops the launch fan")
	await _save_capture("day-pier-contact.png")
	scene.reset_level()
	scene._process(0.8)
	_press_key(KEY_SPACE)
	_finish_hop(scene)
	scene._set_crank_angle(PI * 0.5)
	scene._process(4.8 - scene._elapsed_time)
	_press_key(KEY_SPACE)
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.HOPPING, "A shot above the pier keeps descending after the fan arc")
	await _save_capture("day-high-shot-descending.png")
	scene._process(0.4)
	_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.ROCK, "A high shot lands when it drops onto the pier")

	scene._set_crank_angle(-PI * 0.5)
	scene._process(9.75 - scene._elapsed_time)
	_press_key(KEY_SPACE)
	var deck_at_arc_end := scene._deck_at(Ocean.Platform.LOG_2, scene._elapsed_time + scene.hop_duration)
	_expect(absf(deck_at_arc_end.x - scene._hop_end.x) <= Ocean.LANDING_X, "The ferry is below the key at the end of the initial arc")
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.HOPPING, "The key keeps falling toward the lower ferry")
	scene._process(0.5)
	_expect(scene._state == Ocean.State.FALLING, "A ferry that moves away during the extra descent still causes a miss")
	scene.reset_level()

	# Play the full route with fixed launch times, including two different moorings.
	scene._process(0.8)
	await _save_capture("day-first-shot.png")
	_press_key(KEY_SPACE)
	_expect_platform_fans(scene, Ocean.Platform.START)
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_1, "Lead the first ferry successfully")
	_expect_platform_fans(scene, -1)
	scene._set_crank_angle(asin(-0.35))
	scene._process(4.8 - scene._elapsed_time)
	_press_key(KEY_SPACE)
	_expect_platform_fans(scene, Ocean.Platform.LOG_1)
	scene._process(0.10)
	await _save_capture("day-ferry-fan-burst.png")
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.ROCK, "Jump from the moving ferry to the pier")
	scene._set_crank_angle(asin(0.85))
	scene._process(7.45 - scene._elapsed_time)
	await _save_capture("day-pier-shot.png")
	_press_key(KEY_SPACE)
	_expect_platform_fans(scene, Ocean.Platform.ROCK)
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_2, "Catch the second ferry at the higher tide")
	scene._set_crank_angle(asin(0.95))
	scene._process(10.8 - scene._elapsed_time)
	_press_key(KEY_SPACE)
	_expect_platform_fans(scene, Ocean.Platform.LOG_2)
	scene._process(scene._flight_duration + 0.01)
	_expect(scene._state == Ocean.State.COMPLETED and scene._current_platform == Ocean.Platform.GOAL, "Complete all four timed shots")
	await process_frame
	await _wait_for_scene_fade()
	await create_timer(0.45).timeout
	_expect(scene._campaign_menu.completed and paused, "Goal opens Continue")
	scene.reset_level()
	_expect(not paused, "Reset after success restores normal gameplay")


	for fraction: float in [0.0, 0.25, 0.75, 0.99]:
		scene.reset_level()
		scene.fire_fan()
		scene._process(scene.hop_duration * fraction)
		_press_key(KEY_R)
		await process_frame
		await _wait_for_scene_fade()
		scene._process(2.0)
		_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.START and scene._target_platform == -1, "Reset cancels hop at %.2f progress" % fraction)
		_expect(not scene._fire_button.disabled and not scene._dragging_crank, "Reset clears feedback, button and input state")
		_expect(is_equal_approx(scene._crank_angle, scene.initial_crank_angle) and is_zero_approx(scene._hop_elapsed), "Reset restores tide and animation state")
		_expect(not scene._fan_blades.is_playing(), "Reset stops fan animation")
		var all_stopped: bool = true
		for player: AudioStreamPlayer in scene._sfx_players.values():
			all_stopped = all_stopped and not player.playing
		_expect(all_stopped and not scene._fan_active, "Reset stops all sound triggers during a hop")
	scene.reset_level()
	scene.fire_fan()
	var whirr_reference: WeakRef = weakref(whirr)
	presentation.queue_free()
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	_expect(not is_instance_valid(scene) and not is_instance_valid(presentation), "Scene exit during hop frees room and presentation without pending callbacks")
	_expect(whirr_reference.get_ref() == null, "Scene exit frees the looping fan player")
	await _check_buttons_and_navigation()
	await _check_level_one(expected_sounds)
	# The headless audio server releases stopped playback on its next mix tick.
	await create_timer(0.15).timeout
	print("Ocean regression: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _expect_platform_fans(scene: Ocean, active_platform: int) -> void:
	for platform: int in range(scene._platform_fans.size()):
		var blades: AnimatedSprite2D = scene._platform_fans[platform]
		var expected := scene._platform_anchor(platform) + Ocean.FAN_OFFSET
		_expect(scene.to_local(blades.global_position).is_equal_approx(expected), "Fan %d stays mounted on its platform" % platform)
		_expect(blades.is_playing() == (platform == active_platform), "Only the launch platform's fan spins")


func _press_key(keycode: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventKey = InputEventKey.new()
	release.keycode = keycode
	root.push_input(release, true)


func _sound_snapshot(scene: Ocean) -> Dictionary:
	var sounds: Dictionary = {}
	for sound_name: String in ["crank", "fan_start", "fan_whirr", "miss", "win"]:
		var player: AudioStreamPlayer = scene._sfx_players[sound_name] as AudioStreamPlayer
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		sounds[sound_name] = {
			"data": stream.data,
			"volume": player.volume_db,
			"loop_mode": stream.loop_mode,
			"loop_begin": stream.loop_begin,
			"loop_end": stream.loop_end,
			"mix_rate": stream.mix_rate,
			"format": stream.format,
		}
	return sounds


func _check_live_entrance() -> void:
	# Let the real frame loop run the full entrance, as a direct F6 launch does.
	var presentation: Presentation = OCEAN_SCENE.instantiate() as Presentation
	root.add_child(presentation)
	var wide_scale: float = presentation._box.scale.x
	await create_timer(presentation.establishing_hold + presentation.zoom_duration * 0.5).timeout
	_expect(presentation._box.scale.x > wide_scale and presentation._room._presentation_locked, "Real frame loop animates the entrance while input stays locked")
	await create_timer(presentation.zoom_duration * 0.5 + 0.1).timeout
	_expect(presentation._entrance_finished and not presentation._room._presentation_locked, "Real frame loop completes entrance and unlocks room")
	var close_scale: Vector2 = presentation._box.scale
	presentation._room.reset_level()
	await process_frame
	await _wait_for_scene_fade()
	_expect(presentation._box.scale.is_equal_approx(close_scale), "Reset preserves the final zoom in the real frame loop")
	await _save_capture("music-box-live-room.png")
	presentation.queue_free()
	await process_frame
	await _wait_for_scene_fade()
func _click(button: Button) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _button_center(button)
	root.push_input(press, true)
	await process_frame
	await _wait_for_scene_fade()
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	root.push_input(release, true)
	await process_frame
	await _wait_for_scene_fade()
func _check_buttons_and_navigation() -> void:
	var presentation: Presentation = OCEAN_SCENE.instantiate() as Presentation
	root.add_child(presentation)
	current_scene = presentation
	presentation.set_process(false)
	var scene: Ocean = presentation._room as Ocean
	scene.set_process(false)
	_expect(scene.get_node_or_null("TitleButton") == null, "The room has no title button")
	presentation._process(presentation.establishing_hold + presentation.zoom_duration)
	await _click(scene._fire_button)
	_expect(scene._state == Ocean.State.HOPPING, "Fan button activates the same hop as Space")
	await _click(scene._reset_button)
	_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.START, "Reset button cancels an active hop")
	_expect(presentation._entrance_finished and not scene._presentation_locked, "Puzzle reset keeps the player inside the room")
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_SPACE
	echo.pressed = true
	echo.echo = true
	root.push_input(echo, true)
	_expect(scene._state == Ocean.State.RESTING, "Keyboard repeat does not fire")
	scene._dragging_crank = true
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not scene._dragging_crank, "Losing application focus cancels crank drag")
	presentation.queue_free()
	await process_frame
	await _wait_for_scene_fade()
func _drag_crank(scene: Ocean, finish_angle: float) -> void:
	var transform: Transform2D = scene.get_global_transform_with_canvas()
	var center: Vector2 = scene._crank.position
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = transform * (center + Vector2(0.0, -18.0))
	root.push_input(press, true)
	await process_frame
	await _wait_for_scene_fade()
	for angle: float in [-PI * 0.25, finish_angle]:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = transform * (center + Vector2.from_angle(angle) * 18.0)
		root.push_input(motion, true)
		await process_frame
		await _wait_for_scene_fade()
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	# Release over a button, so GUI consumption cannot leave a stale drag.
	release.position = _button_center(scene._reset_button)
	root.push_input(release, true)


func _check_level_one(expected_sounds: Dictionary) -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_scene_fade()
	_expect(main.find_child("PlayButton", true, false) != null, "Main still loads the existing title menu")
	main.queue_free()
	await process_frame
	await _wait_for_scene_fade()
	var level: Node2D = (load("res://dev/Level 1 - Alt/level_1.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(level)
	await process_frame
	await _wait_for_scene_fade()
	var level_sounds: Dictionary = level.get("_sfx_players")
	for sound_name: String in expected_sounds:
		var level_name: String = "left_fan_whirr" if sound_name == "fan_whirr" else sound_name
		var player: AudioStreamPlayer = level_sounds[level_name] as AudioStreamPlayer
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		var expected: Dictionary = expected_sounds[sound_name]
		_expect(stream.data == expected["data"], "Ocean uses identical Level 1 PCM sound: " + sound_name)
		_expect(is_equal_approx(player.volume_db, expected["volume"]), "Ocean matches Level 1 sound volume: " + sound_name)
		_expect(stream.loop_mode == expected["loop_mode"] and stream.loop_begin == expected["loop_begin"] and stream.loop_end == expected["loop_end"] and stream.mix_rate == expected["mix_rate"] and stream.format == expected["format"], "Ocean matches Level 1 loop and playback configuration: " + sound_name)
	_expect(not level.get("_released"), "Level 1 loads with its fragment tethered")
	var key: RigidBody2D = level.get_node("Key0") as RigidBody2D
	await physics_frame
	var start_y: float = key.global_position.y
	var crank: Node2D = level.get_node("Crank") as Node2D
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = crank.to_global(Vector2(576.0, 0.0))
	root.push_input(press, true)
	await process_frame
	await _wait_for_scene_fade()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = crank.to_global(Vector2.from_angle(0.2) * 576.0)
	root.push_input(motion, true)
	await process_frame
	await _wait_for_scene_fade()
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	root.push_input(release, true)
	await process_frame
	await _wait_for_scene_fade()
	_expect(key.global_position.y < start_y, "Level 1 crank still moves tethered fragment")
	_press_key(KEY_SPACE)
	await process_frame
	await _wait_for_scene_fade()
	_expect(level.get("_released") and not key.freeze, "Level 1 Space still releases fragment")
	_expect((level.get_node("LeftFan/Blades") as AnimatedSprite2D).is_playing(), "Level 1 fan animation still activates")
	_expect(level.get("_rope_bodies").size() == 32, "Level 1 still creates its swinging rope")
	await _save_capture("level1-release.png")
	level.queue_free()
	await process_frame
	await _wait_for_scene_fade()
func _save_capture(file_name: String) -> void:
	if not _capture:
		return
	await process_frame
	await _wait_for_scene_fade()
	await RenderingServer.frame_post_draw
	var folder: String = "res://.godot/ocean_qa"
	DirAccess.make_dir_recursive_absolute(folder)
	var result: Error = root.get_texture().get_image().save_png(folder.path_join(file_name))
	_expect(result == OK, "Saved rendered capture " + file_name)


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame


func _button_center(button: Button) -> Vector2:
	return button.get_global_transform_with_canvas() * (button.size * 0.5)
