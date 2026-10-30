@tool
extends VBoxContainer

signal all_degrees_changed(degrees: float)
signal key_degrees_changed(key: Node, degrees: float)
signal restore_all_requested
signal restore_key_requested(key: Node)
signal select_key_requested(key: Node)

var _all_slider: HSlider
var _all_value: SpinBox
var _all_label: Label
var _rows_box: VBoxContainer
var _empty_hint: Label
var _scene_label: Label
var _restore_all: Button
var _rows: Dictionary = {}


func _ready() -> void:
	name = "WindingDebugPanel"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = Vector2(520, 230)
	add_theme_constant_override("separation", 8)
	_scene_label = Label.new()
	add_child(_scene_label)
	var all_controls: HBoxContainer = HBoxContainer.new()
	all_controls.add_theme_constant_override("separation", 8)
	add_child(all_controls)
	_all_label = Label.new()
	_all_label.text = "All Winding Keys"
	_all_label.custom_minimum_size.x = 190.0
	all_controls.add_child(_all_label)
	_all_slider = _slider("AllAngleSlider")
	all_controls.add_child(_all_slider)
	_all_value = _value("AllAngleValue")
	all_controls.add_child(_all_value)
	var apply: Button = Button.new()
	apply.name = "ApplyAll"
	apply.text = "Apply"
	apply.pressed.connect(func() -> void: all_degrees_changed.emit(_all_value.value))
	all_controls.add_child(apply)
	_restore_all = Button.new()
	_restore_all.text = "Restore All"
	_restore_all.pressed.connect(func() -> void: restore_all_requested.emit())
	all_controls.add_child(_restore_all)
	_all_slider.value_changed.connect(_on_all_changed)
	_all_slider.drag_started.connect(func() -> void: all_degrees_changed.emit(_all_slider.value))
	_all_value.value_changed.connect(_on_all_changed)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows_box)
	_empty_hint = Label.new()
	_empty_hint.text = "Open a scene with winding-key controllers."
	add_child(_empty_hint)
	var note: Label = Label.new()
	note.text = "0 DEG = start | 135 DEG = midpoint | 270 DEG = end. Preview ignores collision and is not saved."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)


func refresh(scene_root: Node, controllers: Array[Node], preview: RefCounted) -> void:
	if not is_node_ready():
		return
	_scene_label.text = "Editing: %s" % scene_root.name if is_instance_valid(scene_root) else "No open scene"
	var present: Dictionary = {}
	var any_preview: bool = false
	var mixed: bool = false
	var degrees: float = preview.get_degrees(controllers[0]) if not controllers.is_empty() else 0.0
	for controller: Node in controllers:
		var id: int = controller.get_instance_id()
		present[id] = true
		if not _rows.has(id):
			_add_row(controller)
		var row: Dictionary = _rows[id]
		var value: float = preview.get_degrees(controller)
		(row.title as Label).text = controller.name
		(row.title as Label).tooltip_text = str(controller.get_path())
		(row.slider as HSlider).set_value_no_signal(value)
		var spin: SpinBox = row.value
		if not spin.get_line_edit().has_focus():
			spin.set_value_no_signal(value)
		(row.restore as Button).disabled = not preview.is_previewing(controller)
		any_preview = any_preview or preview.is_previewing(controller)
		mixed = mixed or not is_equal_approx(value, degrees)
	for id: int in _rows.keys():
		if not present.has(id):
			_remove_row(id)
	_empty_hint.visible = controllers.is_empty()
	_all_label.text = "All Winding Keys (Mixed)" if mixed else "All Winding Keys"
	_all_slider.editable = not controllers.is_empty()
	_all_value.editable = not controllers.is_empty()
	_restore_all.disabled = not any_preview
	if not mixed and not _all_value.get_line_edit().has_focus():
		_all_slider.set_value_no_signal(degrees)
		_all_value.set_value_no_signal(degrees)


func _add_row(controller: Node) -> void:
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "Controller_%d" % controller.get_instance_id()
	controls.add_theme_constant_override("separation", 8)
	_rows_box.add_child(controls)
	var title: Label = Label.new()
	title.custom_minimum_size.x = 190.0
	controls.add_child(title)
	var slider: HSlider = _slider("AngleSlider")
	controls.add_child(slider)
	var value: SpinBox = _value("AngleValue")
	controls.add_child(value)
	var select: Button = Button.new()
	select.text = "Select"
	select.pressed.connect(func() -> void: select_key_requested.emit(controller))
	controls.add_child(select)
	var restore: Button = Button.new()
	restore.name = "RestoreButton"
	restore.text = "Restore"
	restore.pressed.connect(func() -> void: restore_key_requested.emit(controller))
	controls.add_child(restore)
	_rows[controller.get_instance_id()] = {
		"container": controls, "title": title, "slider": slider, "value": value, "restore": restore,
	}
	slider.value_changed.connect(func(degrees: float) -> void: key_degrees_changed.emit(controller, degrees))
	value.value_changed.connect(func(degrees: float) -> void: key_degrees_changed.emit(controller, degrees))
	slider.drag_started.connect(func() -> void: key_degrees_changed.emit(controller, slider.value))
	controller.tree_exiting.connect(_remove_row.bind(controller.get_instance_id()))


func _remove_row(id: int) -> void:
	if _rows.has(id):
		(_rows[id].container as Control).queue_free()
		_rows.erase(id)


func _on_all_changed(degrees: float) -> void:
	_all_slider.set_value_no_signal(degrees)
	_all_value.set_value_no_signal(degrees)
	all_degrees_changed.emit(degrees)


func _slider(node_name: String) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.max_value = WindingObjectController.MAX_WINDING_DEGREES
	slider.step = 0.1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 160.0
	return slider


func _value(node_name: String) -> SpinBox:
	var value: SpinBox = SpinBox.new()
	value.name = node_name
	value.max_value = WindingObjectController.MAX_WINDING_DEGREES
	value.step = 0.1
	value.suffix = "DEG"
	value.custom_minimum_size.x = 160.0
	return value
