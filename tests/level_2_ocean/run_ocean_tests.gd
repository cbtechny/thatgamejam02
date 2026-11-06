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
	_expect(scene._feedback.text.is_empty(), "No instructions or feedback before a press")
	_expect(is_equal_approx(scene._crank_angle, -PI * 0.5), "Reset starts at low tide")
	await _save_capture("ocean-low-start.png")
	# Sweep a complete wave cycle at both tide extremes, independent of hop timing.
	for sample: int in range(181):
		scene._elapsed_time = float(sample) * PI / 180.0
		scene._crank_angle = -PI * 0.5
		scene._current_platform = Ocean.Platform.START
		_expect(scene._find_target() == Ocean.Platform.LOG_1, "Low start -> log 1, wave sample %d" % sample)
		scene._current_platform = Ocean.Platform.LOG_1
		_expect(scene._find_target() == Ocean.Platform.LOG_2, "Low log 1 -> log 2, wave sample %d" % sample)
		scene._current_platform = Ocean.Platform.LOG_2
		_expect(scene._find_target() == Ocean.Platform.ROCK, "Low log 2 -> first reachable rock, wave sample %d" % sample)
		scene._crank_angle = PI * 0.5
		_expect(scene._find_target() == Ocean.Platform.GOAL, "High log 2 -> goal, wave sample %d" % sample)
		scene._current_platform = Ocean.Platform.ROCK
		_expect(scene._find_target() == -1, "Rock cannot reach goal, wave sample %d" % sample)

	_expect(scene._is_reachable(Vector2.ZERO, Vector2(130.0, -26.0)), "Inclusive maximum distance and upward limit")
	_expect(scene._is_reachable(Vector2.ZERO, Vector2(130.0, 30.0)), "Inclusive downward limit")
	for target: Vector2 in [Vector2(0.0, 0.0), Vector2(-1.0, 0.0), Vector2(130.01, 0.0), Vector2(75.0, -26.01), Vector2(75.0, 30.01)]:
		_expect(not scene._is_reachable(Vector2.ZERO, target), "Reject out-of-range anchor %s" % target)

	scene.reset_level()
	scene.fire_fan()
	_expect(whirr.playing and scene._fan_active and scene._fan_blades.is_playing(), "Fire starts whirr and spinning blades together")
	_expect((scene._sfx_players["fan_start"] as AudioStreamPlayer).playing, "Fire also triggers existing startup burst")
	var first_target: int = scene._target_platform
	for press: int in range(10):
		scene.fire_fan()
	_expect(scene._target_platform == first_target and is_zero_approx(scene._hop_elapsed), "Repeated fire does not retarget or restart a hop")
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_1, "Animated start -> log 1")
	_expect(not whirr.playing and not scene._fan_active and not scene._fan_blades.is_playing(), "Landing stops fan whirr and blades together")
	var before_bob: Vector2 = scene._fragment.position
	var held_angle: float = scene._crank_angle
	scene._process(0.4)
	_expect(scene._fragment.position.is_equal_approx(scene._platform_anchor(Ocean.Platform.LOG_1) + Ocean.FRAGMENT_OFFSET), "Resting fragment follows the log anchor")
	_expect(not scene._fragment.position.is_equal_approx(before_bob), "Wave bob continues while crank holds")
	_expect(is_equal_approx(scene._crank_angle, held_angle), "Released crank does not rotate automatically")
	scene.fire_fan()
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_2, "Animated log 1 -> log 2")
	await _save_capture("ocean-low-log2.png")
	scene.fire_fan()
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.ROCK and scene._state == Ocean.State.STRANDED, "Low-tide landing is stranded on rock")
	_expect(scene._feedback.text == "Stranded—reset to try again.", "Rock shows requested persistent feedback")
	_expect((scene._sfx_players["miss"] as AudioStreamPlayer).playing and not whirr.playing, "Rock triggers Level 1 miss sound after stopping fan")
	scene._crank_angle = PI * 0.5
	scene.fire_fan()
	scene._process(2.0)
	_expect(scene._current_platform == Ocean.Platform.ROCK and scene._state == Ocean.State.STRANDED, "Raising tide and firing cannot escape rock")
	await _save_capture("ocean-stranded.png")

	scene.reset_level()
	for hop: int in range(2):
		scene.fire_fan()
		_finish_hop(scene)
	# Exercise the scene's input dispatch at its actual viewport transform.
	await _drag_to_high_tide(scene)
	await process_frame
	_expect(is_equal_approx(scene._crank_angle, PI * 0.5), "Mouse dragging raises tide through existing crank gesture")
	_expect((scene._sfx_players["crank"] as AudioStreamPlayer).playing, "Crank dragging triggers Level 1 ticks")
	_expect(not scene._dragging_crank, "Mouse release clears crank drag")
	scene._process(0.1)
	_expect(scene._fragment.position.is_equal_approx(scene._platform_anchor(Ocean.Platform.LOG_2) + Ocean.FRAGMENT_OFFSET), "Raising tide carries the resting fragment")
	await _save_capture("ocean-high-log2.png")
	_press_key(KEY_SPACE)
	await process_frame
	_expect(scene._state == Ocean.State.HOPPING and scene._target_platform == Ocean.Platform.GOAL, "Space fires the fan toward goal")
	_finish_hop(scene)
	_expect(scene._state == Ocean.State.COMPLETED and scene._current_platform == Ocean.Platform.GOAL, "High-tide route completes level")
	_expect((scene._sfx_players["win"] as AudioStreamPlayer).playing and not whirr.playing, "Completion triggers Level 1 win sound after stopping fan")
	var finished_position: Vector2 = scene._fragment.position
	scene.fire_fan()
	_expect(scene._fragment.position == finished_position and scene._target_platform == -1, "Completion ignores further fire")
	await _save_capture("ocean-complete.png")

	scene.reset_level()
	scene._crank_angle = PI * 0.5
	scene.fire_fan()
	_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.START, "No reachable platform keeps fragment at start")
	_expect(not scene._feedback.text.is_empty(), "Failed press provides feedback")
	_expect(whirr.playing, "Unreachable shot still gives the fan's action sound")
	scene._process(scene.feedback_duration + 0.01)
	_expect(scene._feedback.text.is_empty(), "Brief failure feedback expires")
	_expect(not whirr.playing and not scene._fan_active, "Unreachable-shot burst stops fan audio and animation")

	# Once selected, a log remains the destination even if the tide makes it unreachable.
	scene.reset_level()
	scene.fire_fan()
	scene._process(scene.hop_duration * 0.5)
	scene._crank_angle = PI * 0.5
	scene._process(scene.hop_duration * 0.25)
	var expected: Vector2 = scene._hop_start.lerp(scene._platform_anchor(Ocean.Platform.LOG_1), 0.75)
	expected.y -= sin(PI * 0.75) * scene._hop_height
	_expect(scene._fragment.position.is_equal_approx(expected + Ocean.FRAGMENT_OFFSET), "Mid-hop arc tracks moving locked landing anchor")
	_finish_hop(scene)
	_expect(scene._current_platform == Ocean.Platform.LOG_1, "Changing tide does not reselect locked target")
	_expect(scene._fragment.position.is_equal_approx(scene._platform_anchor(Ocean.Platform.LOG_1) + Ocean.FRAGMENT_OFFSET), "Hop lands exactly on moving anchor")

	for fraction: float in [0.0, 0.25, 0.75, 0.99]:
		scene.reset_level()
		scene.fire_fan()
		scene._process(scene.hop_duration * fraction)
		_press_key(KEY_R)
		await process_frame
		scene._process(2.0)
		_expect(scene._state == Ocean.State.RESTING and scene._current_platform == Ocean.Platform.START and scene._target_platform == -1, "Reset cancels hop at %.2f progress" % fraction)
		_expect(scene._feedback.text.is_empty() and not scene._fire_button.disabled and not scene._dragging_crank, "Reset clears feedback, button and input state")
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
	await process_frame
	_expect(not is_instance_valid(scene) and not is_instance_valid(presentation), "Scene exit during hop frees room and presentation without pending callbacks")
	_expect(whirr_reference.get_ref() == null, "Scene exit frees the looping fan player")
	await _check_buttons_and_navigation()
	await _check_level_one(expected_sounds)
	# The headless audio server releases stopped playback on its next mix tick.
	await create_timer(0.15).timeout
	print("Ocean regression: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


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
	_expect(presentation._box.scale.is_equal_approx(close_scale), "Reset preserves the final zoom in the real frame loop")
	await _save_capture("music-box-live-room.png")
	presentation.queue_free()
	await process_frame


func _click(scene: Ocean, reference_position: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_global_transform_with_canvas() * reference_position
	root.push_input(press, true)
	await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	root.push_input(release, true)
	await process_frame


func _check_buttons_and_navigation() -> void:
	var presentation: Presentation = OCEAN_SCENE.instantiate() as Presentation
	root.add_child(presentation)
	current_scene = presentation
	presentation.set_process(false)
	var scene: Ocean = presentation._room as Ocean
	scene.set_process(false)
	# Returning to title also works before the entrance finishes.
	await _click(scene, Vector2(317.0, 12.0))
	await process_frame
	_expect(not is_instance_valid(presentation), "Title exit cancels the entrance without delayed view changes")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	presentation = OCEAN_SCENE.instantiate() as Presentation
	root.add_child(presentation)
	current_scene = presentation
	presentation.set_process(false)
	presentation._process(presentation.establishing_hold + presentation.zoom_duration)
	scene = presentation._room as Ocean
	scene.set_process(false)
	await _click(scene, Vector2(249.0, 70.0))
	_expect(scene._state == Ocean.State.HOPPING, "Fan button activates the same hop as Space")
	await _click(scene, Vector2(320.0, 70.0))
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
	scene.fire_fan()
	await _click(scene, Vector2(317.0, 12.0))
	await process_frame
	_expect(not is_instance_valid(scene), "Return to Title safely exits during an active hop")
	_expect(current_scene != null and current_scene.find_child("PlayButton", true, false) != null, "Return to Title opens existing navigation")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _drag_to_high_tide(scene: Ocean) -> void:
	var transform: Transform2D = scene.get_global_transform_with_canvas()
	var center: Vector2 = scene._crank.position
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = transform * (center + Vector2(0.0, -18.0))
	root.push_input(press, true)
	await process_frame
	for angle: float in [-PI * 0.25, 0.0, PI * 0.25, PI * 0.5]:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = transform * (center + Vector2.from_angle(angle) * 18.0)
		root.push_input(motion, true)
		await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	# Release over a button, so GUI consumption cannot leave a stale drag.
	release.position = transform * Vector2(320.0, 70.0)
	root.push_input(release, true)


func _check_level_one(expected_sounds: Dictionary) -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_expect(main.find_child("PlayButton", true, false) != null, "Main still loads the existing title menu")
	main.queue_free()
	await process_frame
	var level: Node2D = (load("res://dev/Level 1 - Alt/level_1.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(level)
	await process_frame
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
	var start_y: float = key.global_position.y
	var crank: Node2D = level.get_node("Crank") as Node2D
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = crank.to_global(Vector2(576.0, 0.0))
	root.push_input(press, true)
	await process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = crank.to_global(Vector2.from_angle(0.2) * 576.0)
	root.push_input(motion, true)
	await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	root.push_input(release, true)
	await process_frame
	_expect(key.global_position.y < start_y, "Level 1 crank still moves tethered fragment")
	_press_key(KEY_SPACE)
	await process_frame
	_expect(level.get("_released") and not key.freeze, "Level 1 Space still releases fragment")
	_expect((level.get_node("LeftFan/Blades") as AnimatedSprite2D).is_playing(), "Level 1 fan animation still activates")
	_expect(level.get("_rope_bodies").size() == 32, "Level 1 still creates its swinging rope")
	await _save_capture("level1-release.png")
	level.queue_free()
	await process_frame


func _save_capture(file_name: String) -> void:
	if not _capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var folder: String = "res://.godot/ocean_qa"
	DirAccess.make_dir_recursive_absolute(folder)
	var result: Error = root.get_texture().get_image().save_png(folder.path_join(file_name))
	_expect(result == OK, "Saved rendered capture " + file_name)
