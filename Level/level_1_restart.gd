extends CanvasLayer
## Level 1 only: cover the screen, replace the puzzle, then reveal it.

signal phase_finished

const CURTAIN: PackedScene = preload("res://dev/title/curtain.tscn")
const RIGHT_TEXTURE: Texture2D = preload("res://Art/Textures/T_CurtainRight.png")
var reset_puzzle: Callable
var level_owner: Node
var _players: Array[AnimationPlayer] = []
var _stage: Node2D
var _remaining: int = 0

func _ready() -> void:
	name = "Level1RestartCurtains"
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	_stage = Node2D.new()
	add_child(_stage)
	var left := CURTAIN.instantiate()
	_stage.add_child(left)
	var right_anchor := Node2D.new()
	right_anchor.position.x = 1920.0
	right_anchor.scale.x = -1.0
	_stage.add_child(right_anchor)
	var right := CURTAIN.instantiate()
	right.get_node("Polygon2D").texture = RIGHT_TEXTURE
	right_anchor.add_child(right)
	for curtain: Node in [left, right]:
		var player: AnimationPlayer = curtain.get_node("AnimationPlayer")
		var library := player.get_animation_library(&"").duplicate(true) as AnimationLibrary
		library.get_animation(&"curtain").loop_mode = Animation.LOOP_NONE
		player.remove_animation_library(&"")
		player.add_animation_library(&"", library)
		player.animation_finished.connect(_on_finished)
		player.play(&"curtain")
		player.seek(player.get_animation(&"curtain").length, true)
		player.pause()
		_players.append(player)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_run.call_deferred()

func _fit() -> void:
	_stage.scale = get_viewport().get_visible_rect().size / Vector2(1920, 1080)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(level_owner) or get_tree().current_scene != level_owner:
		queue_free()

func _play(closing: bool) -> void:
	_remaining = _players.size()
	for player: AnimationPlayer in _players:
		if closing:
			player.play_backwards(&"curtain")
			player.seek(player.get_animation(&"curtain").length, true)
		else:
			player.play(&"curtain")
			player.seek(0.0, true)
	await phase_finished

func _on_finished(animation: StringName) -> void:
	if animation == &"curtain":
		_remaining -= 1
		if _remaining == 0:
			phase_finished.emit()

func _run() -> void:
	await _play(true)
	if not is_instance_valid(level_owner) or not reset_puzzle.is_valid():
		queue_free()
		return
	level_owner = reset_puzzle.call()
	reset_puzzle = Callable()
	if not is_instance_valid(level_owner):
		queue_free()
		return
	await _play(false)
	var puzzle: Node = level_owner._room if level_owner.has_method("_replace_puzzle_for_restart") else level_owner
	puzzle._transitioning = false
	puzzle.set_presentation_locked(false)
	queue_free()
