extends CanvasLayer

var room: Node
var next_scene: String
var panel: Control
var completed := false
var switching := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if completed or switching:
			return
		if is_instance_valid(panel):
			resume()
		else:
			show_menu(false)

func show_menu(won: bool) -> void:
	if won and room.get("_state") != 3:
		return
	if is_instance_valid(panel) or switching:
		return
	completed = won
	room.call("_release_crank")
	get_tree().paused = true
	panel = ColorRect.new()
	(panel as ColorRect).color = Color(0.025, 0.035, 0.08, 0.9)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "DELIVERED TO THE KEYHOLE" if won else "PAUSED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	column.add_child(heading)
	var primary := add_button(column, "Continue" if won else "Resume", advance if won else resume)
	add_button(column, "Retry stage", retry)
	add_button(column, "Return to title", func(): go("res://Level/title_menu.tscn"))
	primary.grab_focus()

func add_button(column: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(420, 62)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	column.add_child(button)
	return button

func resume() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		panel = null
	get_tree().paused = false

func retry() -> void:
	go(get_tree().current_scene.scene_file_path)

func advance() -> void:
	go(next_scene)

func go(path: String) -> void:
	if switching:
		return
	switching = true
	get_tree().paused = false
	if get_tree().change_scene_to_file(path) != OK:
		switching = false
		push_error("Unable to open scene: " + path)

func _exit_tree() -> void:
	if is_instance_valid(panel):
		get_tree().paused = false
