@tool
extends RefCounted
## Editor-only bindings and transient poses; no gameplay controller state is used.

const CONTROLLER_SCRIPT: String = "res://Level/objects/winding_object_controller.gd"
const TIMELINE_SCRIPT: String = "res://dev/winder_test_1_time_scroll/music_box_timeline.gd"

var _scene_root: Node
var _degrees: Dictionary = {}
var _components: Dictionary = {}


func set_scene_root(scene_root: Node) -> void:
	if is_instance_valid(_scene_root) and _scene_root == scene_root:
		return
	restore_all()
	_scene_root = scene_root


func get_controllers() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in _scene_nodes():
		if _has_script(node, CONTROLLER_SCRIPT):
			result.append(node)
	return result


func get_degrees(controller: Node) -> float:
	return float(_degrees.get(controller.get_instance_id(), 0.0)) if is_instance_valid(controller) else 0.0


func is_previewing(controller: Node) -> bool:
	return is_instance_valid(controller) and _degrees.has(controller.get_instance_id())


func preview_all(degrees: float) -> void:
	for controller: Node in get_controllers():
		_degrees[controller.get_instance_id()] = clampf(degrees, 0.0, WindingObjectController.MAX_WINDING_DEGREES)
	refresh()


func preview_key(controller: Node, degrees: float) -> void:
	if not get_controllers().has(controller):
		return
	_degrees[controller.get_instance_id()] = clampf(degrees, 0.0, WindingObjectController.MAX_WINDING_DEGREES)
	refresh()


func restore_key(controller: Node) -> void:
	if is_instance_valid(controller):
		_degrees.erase(controller.get_instance_id())
	refresh()


func restore_all() -> void:
	for reference: WeakRef in _components.values():
		var component: Object = reference.get_ref()
		if is_instance_valid(component):
			component.clear_editor_preview()
	_components.clear()
	_degrees.clear()


func refresh() -> void:
	var controllers: Array[Node] = get_controllers()
	var ids: Dictionary = {}
	for controller: Node in controllers:
		ids[controller.get_instance_id()] = true
	for id: int in _degrees.keys():
		if not ids.has(id):
			_degrees.erase(id)
	var wanted: Dictionary = {}
	for node: Node in _scene_nodes():
		if node is MovableObject2D:
			var key: Node = (node as MovableObject2D).winding_key
			_preview_component(node, key, wanted)
		elif _has_script(node, TIMELINE_SCRIPT):
			var key: Node = node.get("object_controller") as Node
			var input: Node = node.get_node_or_null("MusicBox/WinderTwoBlade/WinderHitArea")
			if input is WinderDrag:
				_preview_component(input, key, wanted)
	for id: int in _components.keys():
		if wanted.has(id):
			continue
		var component: Object = (_components[id] as WeakRef).get_ref()
		if is_instance_valid(component):
			component.clear_editor_preview()
		_components.erase(id)


func _preview_component(component: Node, key: Node, wanted: Dictionary) -> void:
	if not is_instance_valid(key) or not _degrees.has(key.get_instance_id()):
		return
	var id: int = component.get_instance_id()
	wanted[id] = true
	_components[id] = weakref(component)
	component.set_editor_preview_degrees(_degrees[key.get_instance_id()])


func _scene_nodes() -> Array[Node]:
	var result: Array[Node] = []
	if not is_instance_valid(_scene_root):
		return result
	result.append(_scene_root)
	var index: int = 0
	while index < result.size():
		result.append_array(result[index].get_children())
		index += 1
	return result


func _has_script(node: Node, script_path: String) -> bool:
	var script: Script = node.get_script() as Script
	while script != null:
		if script.resource_path == script_path:
			return true
		script = script.get_base_script()
	return false
