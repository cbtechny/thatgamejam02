@tool
extends EditorPlugin
## Enabled only in the isolated project made by validate_editor_debug.ps1.

var _checks: int = 0
var _failures: int = 0
var _deadline: int = 0
var _plugin: EditorPlugin


func _enter_tree() -> void:
	_deadline = Time.get_ticks_msec() + 40000
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _deadline > 0 and Time.get_ticks_msec() > _deadline:
		_deadline = 0
		push_error("Editor winding debug validation timed out.")
		get_tree().quit(1)


func _run() -> void:
	await _frames(8)
	_plugin = get_tree().root.find_child("WindingDebugPlugin", true, false) as EditorPlugin
	_expect(_plugin != null, "The editor loads the Winding Debug plugin")
	if _plugin == null:
		_finish()
		return
	_expect(Engine.is_editor_hint() and not EditorInterface.is_playing_scene(), "Validation runs in edit mode without starting the game")
	_expect(not ProjectSettings.has_setting("autoload/WindingDebug"), "There is no runtime debug autoload")
	EditorInterface.open_scene_from_path("res://Main.tscn")
	await _wait_scene("res://Main.tscn")
	await _frames(8)
	var root: Node = EditorInterface.get_edited_scene_root()
	var timeline: Node = root.get_node("MusicBoxPrototype")
	var key: Node = timeline.get_node("WindingKey1")
	var shaft: MovableObject2D = timeline.get_node("MovableObjects/KeyFragmentShaft") as MovableObject2D
	var bow: MovableObject2D = timeline.get_node("MovableObjects/KeyFragmentBow") as MovableObject2D
	var teeth: MovableObject2D = timeline.get_node("MovableObjects/KeyFragmentTeeth") as MovableObject2D
	var wheel: Node2D = timeline.get_node("MusicBox/WinderTwoBlade") as Node2D
	var wheel_rest: float = wheel.rotation
	var panel: Control = _plugin.get("_panel") as Control
	var preview: RefCounted = _plugin.get("_preview")
	(_plugin.get("_dock") as EditorDock).make_visible()
	_expect(preview.get_controllers().size() == 1, "The panel discovers a controller inside an instanced scene")
	var all_slider: HSlider = panel.find_child("AllAngleSlider", true, false) as HSlider
	all_slider.value = 135.0
	await _frames(4)
	_expect((shaft.get_node("Body") as Node2D).position.distance_to(Vector2(0, 44)) < 0.01, "The editor slider immediately previews the path midpoint")
	_expect((bow.get_node("Body") as Node2D).position.distance_to(bow.points[0]) > 1.0 and (teeth.get_node("Body") as Node2D).position.distance_to(teeth.points[0]) > 1.0, "All three bound object previews move in edit mode")
	_expect(absf(wheel.rotation - wheel_rest - deg_to_rad(135.0)) < 0.001, "The authored winding key rotates with the editor preview")
	_plugin.preview_all(400.0)
	_expect((shaft.get_node("Body") as Node2D).position.distance_to(shaft.points[-1]) < 0.01, "Editor values above 270 clamp to the path endpoint")
	_plugin.preview_all(-20.0)
	_expect((shaft.get_node("Body") as Node2D).position.distance_to(shaft.points[0]) < 0.01, "Editor values below zero clamp to the start")
	var value: SpinBox = panel.find_child("AllAngleValue", true, false) as SpinBox
	value.value = 67.5
	_expect(absf((shaft.get_node("Body") as Node2D).position.y - 22.0) < 0.01, "Numeric editor input supports decimal degrees")
	_plugin.restore_all()
	_expect(absf(wheel.rotation - wheel_rest) < 0.001 and (shaft.get_node("Body") as Node2D).position == shaft.points[0], "Restore All restores the authored wheel and object start")
	EditorInterface.save_scene_as("res://Main.tscn", false)
	await _frames(3)
	var original_main: String = FileAccess.get_file_as_string("res://Main.tscn")
	_plugin.preview_all(135.0)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as("res://Main.tscn", false)
	await _frames(3)
	_expect(not EditorInterface.get_unsaved_scenes().has("res://Main.tscn"), "The editor saves successfully while preview is active")
	_expect(FileAccess.get_file_as_string("res://Main.tscn") == original_main, "Saving does not bake preview transforms into the scene")
	_expect(absf((shaft.get_node("Body") as Node2D).position.y - 44.0) < 0.01 and absf(wheel.rotation - wheel_rest - deg_to_rad(135.0)) < 0.001, "Preview resumes after the scene is saved")
	if DisplayServer.get_name() != "headless":
		await _capture(root)
	EditorInterface.open_scene_from_path("res://dev/movable_object_test/movable_object_test.tscn")
	await _wait_scene("res://dev/movable_object_test/movable_object_test.tscn")
	await _frames(6)
	_expect((shaft.get_node("Body") as Node2D).position == shaft.points[0] and absf(wheel.rotation - wheel_rest) < 0.001, "Switching scene tabs clears previews from the previous scene")
	var sandbox: Node = EditorInterface.get_edited_scene_root()
	var first: Node = sandbox.get_node("WindingKey1")
	var second: Node = sandbox.get_node("WindingKey2")
	var fragment: MovableObject2D = sandbox.get_node("KeyFragmentBow") as MovableObject2D
	var decoration: MovableObject2D = sandbox.get_node("Decoration") as MovableObject2D
	_expect(preview.get_controllers().size() == 2, "The editor panel follows the active scene and discovers both keys")
	_plugin.preview_key(first, 202.5)
	_expect((fragment.get_node("Body") as Node2D).global_position.x > 1000.0 and (decoration.get_node("Body") as Node2D).position == decoration.points[0], "A per-key editor preview changes only its bindings and ignores barriers")
	_plugin.preview_all(135.0)
	_expect(absf((decoration.get_node("Body") as Node2D).position.x - 510.0) < 0.01, "The global editor value drives the second key group too")
	preview.restore_key(first)
	_expect((fragment.get_node("Body") as Node2D).position == fragment.points[0] and absf((decoration.get_node("Body") as Node2D).position.x - 510.0) < 0.01, "Restoring one editor group preserves the other preview")
	var original_points: PackedVector2Array = decoration.points.duplicate()
	decoration.points = PackedVector2Array([Vector2.ZERO, Vector2(600, 0)])
	await _frames(3)
	_expect(absf((decoration.get_node("Body") as Node2D).position.x - 300.0) < 0.01, "Editing line points updates an active preview without running the game")
	decoration.points = original_points
	var original_scale: Vector2 = decoration.scale
	decoration.scale = Vector2(2, 1)
	await _frames(3)
	_expect(absf((decoration.get_node("Body") as Node2D).global_position.x - decoration.to_global(Vector2(510, 0)).x) < 0.01, "Preview follows authored node transforms")
	decoration.scale = original_scale
	await _check_rotation_editing(decoration, second)
	_plugin.preview_all(135.0)
	var old_plugin: WeakRef = weakref(_plugin)
	EditorInterface.set_plugin_enabled("winding_debug", false)
	await _frames(4)
	_expect((decoration.get_node("Body") as Node2D).position == decoration.points[0], "Disabling the editor plugin restores all preview poses")
	_expect(not is_instance_valid(old_plugin.get_ref()), "Disabling the plugin removes its editor UI and instance")
	EditorInterface.set_plugin_enabled("winding_debug", true)
	await _frames(4)
	_plugin = get_tree().root.find_child("WindingDebugPlugin", true, false) as EditorPlugin
	_expect(_plugin != null, "The editor plugin can be enabled again")
	if _plugin != null:
		_plugin.preview_all(135.0)
		_expect(_plugin._build() and (decoration.get_node("Body") as Node2D).position == decoration.points[0], "Starting play restores preview poses before gameplay begins")
	await _check_direct_scene_saves()
	_expect(not EditorInterface.is_playing_scene(), "All editor preview checks completed without starting gameplay")
	_finish()


func _check_direct_scene_saves() -> void:
	var path: String = "res://Level/objects/movable_object.tscn"
	EditorInterface.open_scene_from_path(path)
	await _wait_scene(path)
	await _frames(3)
	var object: MovableObject2D = EditorInterface.get_edited_scene_root() as MovableObject2D
	object.set("point_0_rotation", 25.0)
	object.set("point_1_rotation", 115.0)
	object.set("point_2_rotation", 205.0)
	EditorInterface.save_scene_as(path, false)
	var authored: String = FileAccess.get_file_as_string(path)
	var saved: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reloaded: MovableObject2D = saved.instantiate() as MovableObject2D
	_expect(absf(reloaded.get_point_rotation_degrees(0) - 25.0) < 0.01 and absf(reloaded.get_point_rotation_degrees(2) - 205.0) < 0.01, "Authored point rotations survive saving and reloading a scene")
	reloaded.free()
	object.set_editor_preview_degrees(135.0)
	var preview_position: Vector2 = (object.get_node("Body") as Node2D).position
	var preview_rotation: float = (object.get_node("Body") as Node2D).rotation
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(path, false)
	await _frames(2)
	_expect(FileAccess.get_file_as_string(path) == authored, "Saving the directly edited movable scene does not serialize its preview pose")
	_expect((object.get_node("Body") as Node2D).position.distance_to(preview_position) < 0.01 and absf((object.get_node("Body") as Node2D).rotation - preview_rotation) < 0.001, "The direct movable scene keeps its position and rotation preview after saving")
	object.clear_editor_preview()
	path = "res://dev/winder_test_1_time_scroll/music_box_visuals_with_winder.tscn"
	EditorInterface.open_scene_from_path(path)
	await _wait_scene(path)
	await _frames(3)
	var root: Node = EditorInterface.get_edited_scene_root()
	var wheel: Node2D = root.get_node("WinderTwoBlade") as Node2D
	var input: WinderDrag = wheel.get_node("WinderHitArea") as WinderDrag
	EditorInterface.save_scene_as(path, false)
	authored = FileAccess.get_file_as_string(path)
	input.set_editor_preview_degrees(135.0)
	var rotation: float = wheel.rotation
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(path, false)
	await _frames(2)
	_expect(FileAccess.get_file_as_string(path) == authored, "Saving the directly edited artwork scene does not serialize preview rotation")
	_expect(absf(wheel.rotation - rotation) < 0.001, "The direct artwork scene keeps its preview rotation after saving")
	input.clear_editor_preview()


func _check_rotation_editing(object: MovableObject2D, key: Node) -> void:
	var rotations: PackedFloat32Array = object.point_rotations_degrees.duplicate()
	var body: Node2D = object.get_node("Body") as Node2D
	object.set("point_0_rotation", 0.0)
	object.set("point_1_rotation", 180.0)
	_plugin.preview_key(key, 135.0)
	_expect(absf(body.rotation - PI * 0.5) < 0.001, "Winding Debug previews interpolated point rotations in edit mode")
	EditorInterface.edit_node(object)
	await _frames(5)
	var button: Button = _plugin.get("_rotation_button") as Button
	_expect(button.visible, "Selecting a movable exposes the Edit Path Rotation toolbar button")
	button.button_pressed = true
	var editor: RefCounted = _plugin.get("_rotation_editor")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = editor._handle_position(1)
	_expect(_plugin._forward_canvas_gui_input(press), "The viewport rotation handle accepts a drag independently from line position handles")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = editor._canvas_transform() * (object.points[1] + Vector2(0, -80))
	_plugin._forward_canvas_gui_input(motion)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	_plugin._forward_canvas_gui_input(release)
	_expect(absf(object.get_point_rotation_degrees(1) - 270.0) < 0.01 and absf(body.rotation - PI * 0.75) < 0.001, "Dragging a point handle edits its angle and updates the active object preview")
	var undo: EditorUndoRedoManager = _plugin.get_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(object))
	history.undo()
	_expect(absf(object.get_point_rotation_degrees(1) - 180.0) < 0.01 and absf(body.rotation - PI * 0.5) < 0.001, "Undo restores the authored point angle and preview together")
	history.redo()
	_expect(absf(object.get_point_rotation_degrees(1) - 270.0) < 0.01, "Redo reapplies the point rotation drag")
	press.position = editor._handle_position(1)
	_plugin._forward_canvas_gui_input(press)
	motion.position = editor._canvas_transform() * (object.points[1] + Vector2(80, 0))
	_plugin._forward_canvas_gui_input(motion)
	var cancel: InputEventKey = InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	_plugin._forward_canvas_gui_input(cancel)
	_expect(absf(object.get_point_rotation_degrees(1) - 270.0) < 0.01, "Escape cancels a point rotation drag")
	if DisplayServer.get_name() != "headless":
		await _capture_path_rotation(object)
	var points_before: PackedVector2Array = object.points.duplicate()
	object.add_point(Vector2(1200, 0))
	await _frames(3)
	var has_rotation_field: bool = false
	for property: Dictionary in object.get_property_list():
		if property.name == "point_2_rotation" and property.usage & PROPERTY_USAGE_EDITOR:
			has_rotation_field = true
	_expect(has_rotation_field and is_zero_approx(object.get_point_rotation_degrees(2)), "New line points expose a rotation field with a safe zero default")
	object.points = points_before
	EditorInterface.mark_scene_as_unsaved()
	var scene_path: String = EditorInterface.get_edited_scene_root().scene_file_path
	EditorInterface.save_scene_as(scene_path, false)
	var saved: PackedScene = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reloaded: Node = saved.instantiate()
	var saved_object: MovableObject2D = reloaded.get_node("Decoration") as MovableObject2D
	_expect(absf(saved_object.get_point_rotation_degrees(1) - 270.0) < 0.01 and (saved_object.get_node("Body") as Node2D).rotation == 0.0, "An instanced movable saves authored point angles without baking its debug pose")
	reloaded.free()
	object.point_rotations_degrees = rotations
	button.button_pressed = false
	_plugin.restore_all()


func _capture_path_rotation(object: MovableObject2D) -> void:
	EditorInterface.set_main_screen_editor("2D")
	await _frames(3)
	var viewport_control: Control = EditorInterface.get_editor_viewport_2d().get_parent() as Control
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = viewport_control.get_global_rect().get_center()
	click.global_position = click.position
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(object)
	EditorInterface.edit_node(object)
	await _frames(5)
	(_plugin.get("_rotation_button") as Button).button_pressed = true
	var focus: InputEventKey = InputEventKey.new()
	focus.keycode = KEY_F
	focus.physical_keycode = KEY_F
	focus.pressed = true
	Input.parse_input_event(focus)
	Input.flush_buffered_events()
	focus = focus.duplicate() as InputEventKey
	focus.pressed = false
	Input.parse_input_event(focus)
	Input.flush_buffered_events()
	await _frames(5)
	var rotation_editor: RefCounted = _plugin.get("_rotation_editor")
	_expect(rotation_editor.get("_object") == object and rotation_editor.get("_enabled"), "The selected path keeps its rotation handles active in the actual 2D viewport")
	EditorInterface.get_inspector().expand_revertable()
	await _frames(3)
	var original_points: PackedVector2Array = object.points.duplicate()
	var origin: Vector2 = viewport_control.get_global_rect().position
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = origin + rotation_editor._handle_position(1)
	press.global_position = press.position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await _frames(2)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.shift_pressed = true
	motion.position = origin + rotation_editor._canvas_transform() * (object.points[1] + Vector2.from_angle(deg_to_rad(283.0)) * 80.0)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _frames(2)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	release.global_position = motion.global_position
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(3)
	_expect(absf(object.get_point_rotation_degrees(1) - 285.0) < 0.01 and object.points == original_points, "Real editor mouse events rotate the visible handle with Shift snapping without moving the point")
	var undo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo.get_history_undo_redo(undo.get_object_history_id(object)).undo()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var error: Error = EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("res://editor-path-rotation.png")
	_expect(error == OK, "The per-point rotation editor screenshot was captured")


func _capture(root: Node) -> void:
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1920, 1080)
	EditorInterface.set_main_screen_editor("2D")
	await _frames(4)
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	var viewport_control: Control = viewport.get_parent() as Control
	if viewport_control != null:
		var position: Vector2 = viewport_control.get_global_rect().get_center()
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = position
		click.global_position = position
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = position
		click.global_position = position
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(root.get_node("MusicBoxPrototype/MusicBox"))
	var focus: InputEventKey = InputEventKey.new()
	focus.keycode = KEY_F
	focus.physical_keycode = KEY_F
	focus.pressed = true
	Input.parse_input_event(focus)
	Input.flush_buffered_events()
	focus = InputEventKey.new()
	focus.keycode = KEY_F
	focus.physical_keycode = KEY_F
	Input.parse_input_event(focus)
	Input.flush_buffered_events()
	await _frames(4)
	await RenderingServer.frame_post_draw
	var error: Error = EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("res://editor-winding-debug.png")
	_expect(error == OK, "The editor preview screenshot was captured")


func _wait_scene(path: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var root: Node = EditorInterface.get_edited_scene_root()
		if root != null and root.scene_file_path == path:
			return
		await get_tree().process_frame
	_expect(false, "The editor opened scene " + path)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	_deadline = 0
	if is_instance_valid(_plugin):
		_plugin.restore_all()
	print("Editor winding debug checks: %d passed, %d failed." % [_checks - _failures, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
