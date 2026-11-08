extends SceneTree
## Play the timed route and verify the rendered darkness at fixed room positions.

const Ocean = preload("res://dev/level_3_ocean/level_3_ocean.gd")
const BOX = preload("res://dev/level_3_ocean/level_3_ocean.tscn")
var _checks: int = 0
var _failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event, true)


func _run() -> void:
	if _capture:
		# Window managers may clamp --resolution to the desktop work area.
		root.size = Vector2i(1920, 1080)
		await process_frame
		await _wait_for_scene_fade()
	var box: Node2D = BOX.instantiate()
	root.add_child(box)
	box.set_process(false)
	var scene: Ocean = box.get("_room") as Ocean
	scene.set_process(false)
	var initial_slope: float = scene._beam_material.get_shader_parameter(&"beam_slope")
	_press(KEY_RIGHT)
	_press(KEY_SPACE)
	scene._process(0.5)
	_expect(scene._state == Ocean.State.RESTING and scene._elapsed_time == 0.0, "Entrance locks shots and the stage clock")
	box.call("_process", 3.0)
	_expect(not scene._presentation_locked and not scene._fire_button.disabled, "Entrance unlocks the crank and fan")

	var first_deck := scene._deck_position(Ocean.Platform.LOG_1)
	_press(KEY_RIGHT)
	_expect(scene._deck_position(Ocean.Platform.LOG_1).y < first_deck.y, "Crank adjusts the tide")
	_expect(scene._deck_position(Ocean.Platform.LOG_1).x == first_deck.x, "Crank leaves horizontal drift unchanged")
	_expect(scene._beam_material.get_shader_parameter(&"beam_slope") == initial_slope, "Crank leaves the lighthouse unchanged")
	scene._process(Ocean.SWEEP_PERIOD / 4.0)
	var outbound: float = scene._beam_material.get_shader_parameter(&"beam_slope")
	scene._process(Ocean.SWEEP_PERIOD / 2.0)
	var inbound: float = scene._beam_material.get_shader_parameter(&"beam_slope")
	scene._process(Ocean.SWEEP_PERIOD / 4.0)
	_expect(outbound > 0.0 and inbound < 0.0, "Lighthouse sweeps both directions on its own clock")
	_expect(is_equal_approx(scene._beam_material.get_shader_parameter(&"beam_slope"), initial_slope), "Beam completes a repeating sweep")
	scene.reset_level()

	if _capture:
		scene._process(Ocean.SWEEP_PERIOD * 0.04)
		var left := await _save_capture("lighthouse-left.png")
		scene._process(Ocean.SWEEP_PERIOD * 0.17 - scene._elapsed_time)
		var right := await _save_capture("lighthouse-right.png")
		var left_water := Vector2(70.0, 154.0)
		var right_water := Vector2(291.0, 154.0)
		_expect(_luminance(left, scene, left_water) > 0.12 and _luminance(left, scene, right_water) < 0.01, "Left sweep reveals water only on the left")
		_expect(_luminance(right, scene, left_water) < 0.01 and _luminance(right, scene, right_water) > 0.12, "Right sweep reveals water only on the right")
		_expect(_luminance(left, scene, scene._deck_at(Ocean.Platform.GOAL, 0.0)) > 0.05, "Night landing edge remains visible outside the beam")
		scene.reset_level()
		scene._process(Ocean.SWEEP_PERIOD * 0.105)
		await _save_capture("lighthouse-center.png")
		scene.reset_level()

	scene._process(3.0)
	_press(KEY_SPACE)
	scene._process(scene.hop_duration + 0.01)
	_expect(scene._state == Ocean.State.FALLING, "A mistimed launch still misses in the dark")
	scene._process(0.4)
	_expect(scene._state == Ocean.State.FAILED, "Miss requires a retry")
	_press(KEY_R)
	await _wait_for_scene_fade()
	_expect(scene._current_platform == Ocean.Platform.START and is_zero_approx(scene._elapsed_time), "Retry resets the route, boards and sweep")
	_expect(is_equal_approx(scene._beam_material.get_shader_parameter(&"beam_slope"), initial_slope), "Retry starts the lamp at its initial angle")

	var times: Array[float] = [0.35, 1.10, 4.45, 12.65, 16.80]
	var raft_heights: Array[float] = [136.0, 125.0, 125.0, 105.0, 103.0]
	for platform: int in range(times.size()):
		scene._set_crank_angle(asin((116.0 - raft_heights[platform]) / 20.0))
		scene._process(times[platform] - scene._elapsed_time)
		_press(KEY_SPACE)
		_expect(scene._state == Ocean.State.HOPPING and scene._platform_fans[platform].is_playing(), "Fan on launch platform %d drives the shot" % platform)
		scene._process(scene._flight_duration + 0.01)
		_expect(scene._current_platform == platform + 1, "Timed shot %d lands on the next platform" % (platform + 1))

	await process_frame

	await _wait_for_scene_fade()
	await create_timer(0.45).timeout
	_expect(scene._state == Ocean.State.COMPLETED and scene._campaign_menu.completed, "The five-hop route opens Continue")
	scene.reset_level()
	_expect(not paused and scene._current_platform == Ocean.Platform.START, "Retry restores play after completion")
	box.queue_free()
	await process_frame
	await _wait_for_scene_fade()
	await create_timer(0.15).timeout
	print("Lighthouse regression: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _save_capture(file_name: String) -> Image:
	await process_frame
	await _wait_for_scene_fade()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/level3_qa")
	var frame := root.get_texture().get_image()
	_expect(frame.save_png("res://.godot/level3_qa/" + file_name) == OK, "Saved " + file_name)
	return frame


func _luminance(frame: Image, scene: Ocean, point: Vector2) -> float:
	var pixel := Vector2i(scene.get_global_transform_with_canvas() * point)
	return frame.get_pixelv(pixel).get_luminance()


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
