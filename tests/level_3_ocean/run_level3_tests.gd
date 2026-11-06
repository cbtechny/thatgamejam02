extends SceneTree
## Check the two traps, complete route, unchanged rules and actual rendered light.

const L3 = preload("res://dev/level_3_ocean/level_3_ocean.gd")
const L2 = preload("res://dev/level_2_ocean/level_2_ocean.gd")
const ROOM = preload("res://dev/level_3_ocean/ocean_room.tscn")
const BOX = preload("res://dev/level_3_ocean/level_3_ocean.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene: L3 = ROOM.instantiate() as L3
	root.add_child(scene)
	scene.set_process(false)
	var old: L2 = (load("res://dev/level_2_ocean/ocean_room.tscn") as PackedScene).instantiate() as L2
	root.add_child(old)
	old.set_process(false)
	old.hide()
	_expect(scene.max_hop_distance == old.max_hop_distance and scene.hop_duration == old.hop_duration and scene.min_height_difference == old.min_height_difference and scene.max_height_difference == old.max_height_difference, "Original hop settings preserved")
	for sample: int in range(181):
		scene._elapsed_time = float(sample) * TAU / 180.0
		old._elapsed_time = scene._elapsed_time
		for angle: float in [-PI * 0.5, PI * 0.5]:
			scene._crank_angle = angle
			old._crank_angle = angle
			_expect(is_equal_approx(scene._water_y(235.0), old._water_y(235.0)), "Unchanged water formula")
			scene._current_platform = L3.Platform.LOG_2
			_expect(scene._find_target() == (L3.Platform.ROCK_A if angle < 0.0 else L3.Platform.LOG_3), "First rock or third log across full wave cycle")
			scene._current_platform = L3.Platform.LOG_3
			_expect(scene._find_target() == (L3.Platform.ROCK_B if angle < 0.0 else L3.Platform.GOAL), "Second rock or high goal across full wave cycle")
	old.queue_free()
	await process_frame
	scene.reset_level()
	for target: int in [L3.Platform.LOG_1, L3.Platform.LOG_2, L3.Platform.LOG_3, L3.Platform.GOAL]:
		if target == L3.Platform.LOG_3:
			scene._crank_angle = PI * 0.5
		scene.fire_fan()
		_expect(scene._target_platform == target, "Complete route selects expected next platform")
		scene.fire_fan()
		scene._process(scene.hop_duration + 0.01)
		_expect(scene._current_platform == target, "Hop lands on locked target")
	_expect(scene._state == L3.State.COMPLETED, "Goal completes level")
	for rock: int in [L3.Platform.ROCK_A, L3.Platform.ROCK_B]:
		scene.reset_level()
		scene._current_platform = L3.Platform.LOG_2 if rock == L3.Platform.ROCK_A else L3.Platform.LOG_3
		scene.fire_fan()
		scene._process(scene.hop_duration + 0.01)
		_expect(scene._current_platform == rock and scene._state == L3.State.STRANDED, "Each low rock strands the fragment")
		scene.fire_fan()
		_expect(scene._state == L3.State.STRANDED, "Fan cannot escape a dead end")
	_expect((scene.get_node("Fragment") as Sprite2D).material == null, "Fragment retains default lit material")
	for branch: String in ["Crank", "Fan"]:
		for sprite: Node in scene.get_node(branch).find_children("*", "CanvasItem", true, false):
			_expect((sprite as CanvasItem).material == null, "Shared sprites retain default lit materials")
	_expect((scene.get_node("Darkness") as CanvasModulate).color.is_equal_approx(Color(0.05, 0.06, 0.12)), "Requested ambient darkness")
	for angle: float in [-PI, 0.0, PI]:
		scene._crank_angle = angle
		scene._process(0.0)
		_expect(is_equal_approx((scene.get_node("SweepLight") as PointLight2D).position.x, lerpf(30.0, 330.0, 0.5 + 0.5 * sin(angle * 0.5))), "Sweep follows exact half-angle sine")
	scene.reset_level()
	scene.fire_fan()
	scene._process(scene.hop_duration * 0.5)
	_expect((scene.get_node("Fragment/FragmentLight") as PointLight2D).global_position.is_equal_approx(scene._fragment.global_position), "Key light follows during a hop")
	scene.reset_level()
	_expect(is_equal_approx((scene.get_node("SweepLight") as PointLight2D).position.x, lerpf(30.0, 330.0, 0.5 + 0.5 * sin(scene.initial_crank_angle * 0.5))), "Reset restores light immediately")
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		for angle: float in [-PI, 0.0, PI]:
			scene._crank_angle = angle
			scene._process(0.0)
			await _capture("room-%d.png" % int(rad_to_deg(angle)))
		# With the sweep far away, the key's own light must illuminate the key.
		var lit: Image = root.get_texture().get_image()
		scene.get_node("Fragment/FragmentLight").hide()
		await _capture("key-light-off.png")
		var dark: Image = root.get_texture().get_image()
		var center: Vector2i = Vector2i(scene._fragment.global_position)
		var improvement: float = 0.0
		for y: int in range(center.y - 15, center.y + 16):
			for x: int in range(center.x - 15, center.x + 16):
				improvement = maxf(improvement, lit.get_pixel(x, y).get_luminance() - dark.get_pixel(x, y).get_luminance())
		_expect(improvement > 0.1, "Rendered key light illuminates fragment away from sweep")
	scene.queue_free()
	await process_frame
	var box: Node2D = BOX.instantiate() as Node2D
	root.add_child(box)
	box.set_process(false)
	box.call("_process", 3.0)
	_expect(not bool(box.get("_room").get("_presentation_locked")), "Duplicated music-box entrance unlocks Level3")
	await _capture("level3-music-box.png")
	box.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Level3: %d passed, %d failed." % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func _capture(file_name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/level3_qa")
	_expect(root.get_texture().get_image().save_png("res://.godot/level3_qa/" + file_name) == OK, "Saved " + file_name)
