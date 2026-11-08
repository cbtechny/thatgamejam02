extends SceneTree
## Release behavior: real menu input, session audio, pause, retry and missed landings.

var checks: int = 0
var failures: int = 0
var session: Node
var music_id: int

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func open_scene(path: String) -> void:
	paused = false
	check(change_scene_to_file(path) == OK, "Load " + path)
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	check(session.music.get_instance_id() == music_id, "Scene change retains one music player")
	check(root.find_children("JamTheme", "AudioStreamPlayer", true, false).size() == 1, "Only one theme player exists")

func press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await _wait_for_scene_fade()
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/release-%s.png" % label)

func run() -> void:
	session = root.get_node("ReleaseSession")
	music_id = session.music.get_instance_id()
	check(session.music.playing, "Theme recording starts")
	check(is_equal_approx(session.music.pitch_scale, 1.0), "Theme plays at original speed")
	await open_scene("res://Main.tscn")
	var title: Control = current_scene.get_node("TitleMenu")
	press_escape()
	check(not paused, "Escape on title does not open a gameplay menu")
	await click(title.get_node("ContentMargins/MainBdy/ButtonContainer/RulesButton"))
	check(is_instance_valid(title._information_menu.panel), "How to Play opens with mouse")
	press_escape()
	await process_frame
	await _wait_for_scene_fade()
	check(not is_instance_valid(title._information_menu.panel), "Escape closes help")
	check(root.gui_get_focus_owner() == title.get_node("ContentMargins/MainBdy/ButtonContainer/RulesButton"), "Closing help restores button focus")
	await click(title.get_node("ContentMargins/MainBdy/ButtonContainer2/TeamButton"))
	await capture("credits")
	press_escape()
	await process_frame
	await _wait_for_scene_fade()
	for extent: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = extent
		await process_frame
		await _wait_for_scene_fade()
		await capture("title-%d" % extent.x)
		for button: Node in title.find_children("*", "Button", true, false):
			check(root.get_visible_rect().encloses(button.get_global_rect()), "Title button fits %s: %s" % [extent, button.text])
	var mute: Button = title.find_child("MuteButton", true, false)
	await click(mute)
	check(session.muted and AudioServer.is_bus_mute(0) and mute.text == "Unmute", "Mute updates Master bus and caption")
	await open_scene("res://Level/level_1_music_box.tscn")
	var stage: Node = current_scene
	stage._process(2.3)
	var room: Node = stage._room
	room._dragging_crank = true
	room._show_pause_menu()
	await process_frame
	await _wait_for_scene_fade()
	check(paused and not room._dragging_crank and session.music.stream_paused, "Pause clears drag and suspends music")
	mute = stage.find_child("MuteButton", true, false)
	check(mute.text == "Unmute", "Mute persists into gameplay")
	await click(mute)
	check(not session.muted and not AudioServer.is_bus_mute(0), "Unmute works while paused")
	room._resume_from_pause()
	await process_frame
	await _wait_for_scene_fade()
	check(not paused and not session.music.stream_paused, "Resume restores music")
	room._release_key()
	press_escape()
	await process_frame
	await _wait_for_scene_fade()
	check(paused and room._pause_menu_open, "Level 1 can pause during released-key movement")
	await capture("level1-flight-paused")
	room._retry_level()
	room._retry_level()
	await wait_restart()
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	check(not paused and not current_scene._room._released and not current_scene._room._dragging_crank, "Repeated Retry produces fresh, unpaused Level 1")
	for number: int in [2, 3]:
		await open_scene("res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number])
		stage = current_scene
		stage._process(2.3)
		room = stage._room
		room.fire_fan()
		room._dragging_crank = true
		press_escape()
		await process_frame
		await _wait_for_scene_fade()
		check(paused and not room._dragging_crank, "Ocean pause cancels held crank")
		var elapsed: float = room._elapsed_time
		var hop: float = room._hop_elapsed
		await process_frame
		await _wait_for_scene_fade()
		check(room._elapsed_time == elapsed and room._hop_elapsed == hop, "Pause freezes tide and hop")
		room._campaign_menu.resume()
		await process_frame
		await _wait_for_scene_fade()
		if number == 3:
			var navigation: Node2D = room.get_node("NightNavigation")
			check((navigation.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "Night markers use unshaded material")
			check(navigation.z_index > room.get_node("NightMask").z_index, "Navigation renders above the lighthouse mask")
		room.reset_level()
		# A mistimed shot misses the drifting deck in both redesigned rooms.
		room.set_process(false)
		room._process(3.0 if number == 3 else 1.35)
		room.fire_fan()
		room._process(room._flight_duration + 0.01)
		room._process(0.4)
		check(room._state == 2 and not room._fragment.visible, "Mistimed shot misses the ferry")
		room._campaign_menu.show_menu(false)
		await process_frame
		await _wait_for_scene_fade()
		await capture("level%d-missed-pause" % number)
		room._campaign_menu.retry()
		room._campaign_menu.retry()
		await process_frame
		await _wait_for_scene_fade()
		await process_frame
		await _wait_for_scene_fade()
		room = current_scene._room
		check(not paused and room._current_platform == 0 and not room._dragging_crank, "Retry restores shore and clears state")
		check(not room._fan_active, "Retry stops old fan loop")
	await open_scene("res://Level/ending.tscn")
	var credits: Button = current_scene.find_child("CreditsButton", true, false)
	await click(credits)
	var menu: Node = current_scene.get_child(current_scene.get_child_count() - 1)
	check(is_instance_valid(menu.panel), "Full credits opens from ending")
	press_escape()
	await process_frame
	await _wait_for_scene_fade()
	check(not is_instance_valid(menu.panel), "Escape closes ending credits")
	await capture("ending")
	menu.go("res://Level/level_1_music_box.tscn")
	await process_frame
	await _wait_for_scene_fade()
	await process_frame
	await _wait_for_scene_fade()
	check(not paused and current_scene._room._presentation_locked, "Replay starts fresh entrance")
	await open_scene("res://Main.tscn")
	check(session.mute_changed.get_connections().size() == 1, "Old menu mute connections are released")
	print("Release regression: %d checks, %d failures" % [checks, failures])
	session.music.stop()
	session.music.stream = null
	current_scene.free()
	await create_timer(0.15).timeout
	quit(1 if failures else 0)

func wait_restart() -> void:
	for frame: int in range(480):
		if root.get_node_or_null("Level1RestartFade") == null:
			return
		await physics_frame
	check(false, "Curtain restart timed out")


func _wait_for_scene_fade() -> void:
	var fade: Node = root.get_node_or_null("SceneFade")
	while is_instance_valid(fade) and fade.busy:
		await process_frame
