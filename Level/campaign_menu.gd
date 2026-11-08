extends CanvasLayer

const UI_THEME = preload("res://Level/music_box_theme.gd")

var room: Node
var next_scene: String
var panel: Control
var completed := false
var switching := false
var information := false
var return_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if switching or (completed and not information):
			return
		if is_instance_valid(panel):
			if information:
				close_information()
			else:
				resume()
		elif is_instance_valid(room):
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
	panel.theme = UI_THEME.create()
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
	var retry_button := add_button(column, "Retry Stage", retry)
	var retry_prompt: Node = preload("res://Level/restart_prompt.gd").attach(retry_button)
	retry_prompt.set_active(room.get("_state") in [2, 4])
	add_release_controls(column)
	primary.grab_focus()

static func add_button(column: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = UI_THEME.BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 26)
	style_button(button)
	button.pressed.connect(action)
	column.add_child(button)
	return button

static func style_button(button: Button) -> void:
	button.theme = UI_THEME.create()
	button.focus_mode = Control.FOCUS_ALL

static func add_release_controls(column: Container) -> void:
	var session: Node = column.get_node("/root/ReleaseSession")
	var mute := Button.new()
	mute.set_script(preload("res://Level/mute_button.gd"))
	mute.name = "MuteButton"
	mute.custom_minimum_size = UI_THEME.BUTTON_SIZE
	mute.add_theme_font_size_override("font_size", 26)
	style_button(mute)
	mute.pressed.connect(session.toggle_mute)
	column.add_child(mute)
	var exit_button := add_button(column, "Exit Game", session.quit_game)
	exit_button.name = "ExitButton"

func show_information(heading: String, body: String, source: Control) -> void:
	if is_instance_valid(panel):
		return
	information = true
	return_focus = source
	panel = ColorRect.new()
	panel.theme = UI_THEME.create()
	(panel as ColorRect).color = Color(0.025, 0.035, 0.08, 0.98)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 70)
	panel.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margins.add_child(column)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 28)
	scroll.add_child(text)
	add_button(column, "Back", close_information).grab_focus()

func close_information() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		panel = null
	information = false
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func resume() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		panel = null
	if is_instance_valid(room):
		room.set("_dragging_crank", false)
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
	_change_scene.call_deferred(path)

func _change_scene(path: String) -> void:
	if get_node("/root/SceneFade").go(path) != OK:
		switching = false
		push_error("Unable to open scene: " + path)

func _exit_tree() -> void:
	if is_instance_valid(panel):
		get_tree().paused = false
