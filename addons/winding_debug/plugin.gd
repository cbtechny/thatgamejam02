@tool
extends EditorPlugin

const PREVIEW_SCRIPT: Script = preload("editor_preview.gd")
const PANEL_SCRIPT: Script = preload("panel.gd")
const ROTATION_EDITOR_SCRIPT: Script = preload("path_rotation_editor.gd")

var _preview: RefCounted = PREVIEW_SCRIPT.new()
var _panel: VBoxContainer
var _dock: EditorDock
var _refresh_remaining: float = 0.0
var _rotation_editor: RefCounted = ROTATION_EDITOR_SCRIPT.new()
var _rotation_button: Button


func _enter_tree() -> void:
	name = "WindingDebugPlugin"
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	_rotation_button = Button.new()
	_rotation_button.text = "Edit Path Rotation"
	_rotation_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rotation_button.toggle_mode = true
	_rotation_button.tooltip_text = "Drag orange handles to rotate each path point. Shift: snap 15 degrees. Escape: cancel."
	_rotation_button.toggled.connect(_on_rotation_toggled)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _rotation_button)
	_rotation_button.hide()
	_panel = PANEL_SCRIPT.new() as VBoxContainer
	_dock = EditorDock.new()
	_dock.title = "Winding Debug"
	_dock.layout_key = "WindingDebug"
	_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	_dock.add_child(_panel)
	add_dock(_dock)
	_panel.all_degrees_changed.connect(preview_all)
	_panel.key_degrees_changed.connect(preview_key)
	_panel.restore_all_requested.connect(restore_all)
	_panel.restore_key_requested.connect(_restore_key)
	_panel.select_key_requested.connect(_select_key)
	_dock.closed.connect(restore_all)
	scene_changed.connect(_on_scene_changed)
	_on_scene_changed(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	_rotation_editor.edit(null)
	if is_instance_valid(_rotation_button):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _rotation_button)
		_rotation_button.queue_free()
	_preview.restore_all()
	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()
	_dock = null
	_panel = null


func _process(delta: float) -> void:
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_preview.refresh()
		_refresh_panel()
		_refresh_remaining = 0.15
		update_overlays()


func _handles(object: Object) -> bool:
	return object is MovableObject2D


func _edit(object: Object) -> void:
	_rotation_editor.edit(object as MovableObject2D)
	update_overlays()


func _make_visible(visible: bool) -> void:
	_rotation_button.visible = visible
	_rotation_editor.set_enabled(visible and _rotation_button.button_pressed)
	update_overlays()


func _on_rotation_toggled(enabled: bool) -> void:
	_rotation_editor.set_enabled(enabled)
	update_overlays()


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	_rotation_editor.draw(overlay)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var handled: bool = _rotation_editor.handle_input(event, get_undo_redo())
	if handled:
		update_overlays()
	return handled


func _build() -> bool:
	restore_all()
	return true


func preview_all(degrees: float) -> void:
	_preview.preview_all(degrees)
	_refresh_panel()


func preview_key(controller: Node, degrees: float) -> void:
	_preview.preview_key(controller, degrees)
	_refresh_panel()


func restore_all() -> void:
	_preview.restore_all()
	_refresh_panel()


func _restore_key(controller: Node) -> void:
	_preview.restore_key(controller)
	_refresh_panel()


func _select_key(controller: Node) -> void:
	if is_instance_valid(controller):
		EditorInterface.edit_node(controller)


func _on_scene_changed(scene_root: Node) -> void:
	_rotation_editor.edit(null)
	_preview.set_scene_root(scene_root)
	_refresh_panel()


func _refresh_panel() -> void:
	if is_instance_valid(_panel):
		_panel.refresh(EditorInterface.get_edited_scene_root(), _preview.get_controllers(), _preview)
