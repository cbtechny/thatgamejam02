extends SceneTree
## Collection uses successful landings; movement regression stays in ocean suites.
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func photograph(label: String) -> void:
	if capture:
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/fragments-" + label + ".png")

func land_at(room: Node, platform: int, miss: bool = false) -> void:
	room._touchdown_time = room._elapsed_time
	room._current_platform = platform - 1
	room._fragment.position = room._deck_at(platform, room._touchdown_time) + room.FRAGMENT_OFFSET
	if miss:
		room._fragment.position.x += 1000.0
	room._land()

func run() -> void:
	for number: int in [2, 3]:
		paused = false
		change_scene_to_file("res://dev/level_%d_ocean/level_%d_ocean.tscn" % [number, number])
		await process_frame
		await process_frame
		var stage: Node = current_scene
		stage.set_process(false)
		var room: Node = stage._room
		room.set_process(false)
		var collection: Node = room._key_collection
		var middle: int = 2 if number == 2 else 3
		var goal: int = room._platform_names.size() - 1
		check(collection.middle_platform == middle, "Middle piece uses Pier/Breakwater")
		check(collection.collected == [true, false, false], "Only the traveling piece starts filled")
		check(collection.icons[0].self_modulate == Color.WHITE and collection.icons[1].self_modulate == collection.DIM, "UI matches collected/dim state")
		check(collection.z_index > 10, "World pickups render above lighthouse mask")
		check(collection.get_node("KeyHUD").layer < room._campaign_menu.layer, "Menus cover key HUD")
		var initial: Vector2 = collection.pickup_position(1)
		room._process(0.5)
		check(collection.pickup_position(1).is_equal_approx(initial), "Entrance freezes bob and sparkle clock")
		stage._process(3.0)
		room._process(0.5)
		check(not collection.pickup_position(1).is_equal_approx(initial), "Unlocked pickups bob")
		room.set_process(true)
		room._campaign_menu.show_menu(false)
		var clock: float = collection._time
		await create_timer(0.06).timeout
		check(is_equal_approx(clock, collection._time), "Pause freezes bob and sparkle clock")
		room._campaign_menu.resume()
		room.set_process(false)
		await process_frame
		room.reset_level()
		for extent: Vector2i in [Vector2i(1920,1080), Vector2i(1280,720)]:
			root.size = extent
			await photograph("level%d-%d" % [number, extent.x])
			for icon: Sprite2D in collection.icons:
				check(root.get_visible_rect().encloses(icon.get_global_transform_with_canvas() * icon.get_rect()), "HUD icon fits viewport")
		land_at(room, middle, true)
		check(not collection.collected[1], "Missed middle landing awards nothing")
		room.reset_level()
		land_at(room, 1)
		check(collection.collected == [true, false, false], "Other platforms award nothing")
		land_at(room, middle)
		check(collection.collected == [true, true, false], "Successful middle landing collects second piece")
		check(collection.icons[1].self_modulate == Color.WHITE, "Second UI icon fills")
		land_at(room, middle)
		check(collection.collected == [true, true, false], "Repeated landing is idempotent")
		await photograph("level%d-middle" % number)
		land_at(room, goal, true)
		check(not collection.collected[2], "Missed goal landing awards nothing")
		land_at(room, goal)
		check(collection.collected == [true, true, true], "Goal collects third piece before completion menu")
		check(room._state == room.State.COMPLETED, "Existing completion still runs")
		await process_frame
		check(room._campaign_menu.completed and paused, "Existing completion menu opens")
		await photograph("level%d-complete" % number)
		room.reset_level()
		check(collection.collected == [true, false, false] and not paused, "Reset restores both pickups and unpauses completion")
		check(collection.icons[1].self_modulate == collection.DIM and collection.icons[2].self_modulate == collection.DIM, "Reset dims both UI icons")
		land_at(room, middle)
		room._campaign_menu.show_menu(false)
		room._campaign_menu.retry()
		await process_frame
		await process_frame
		check(current_scene != stage and current_scene._room._key_collection.collected == [true, false, false], "Retry creates fresh collection state")
	paused = false
	current_scene.free()
	await process_frame
	print("Ocean fragments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
