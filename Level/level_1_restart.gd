extends CanvasLayer
## Fast restart using the shared black fade; preserve the finished entrance.
var reset_puzzle: Callable
var level_owner: Node

func _ready() -> void:
	name = "Level1RestartFade"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	if not is_instance_valid(level_owner) or not reset_puzzle.is_valid():
		queue_free()
		return
	level_owner = await get_node("/root/SceneFade").reset_under_black(reset_puzzle)
	reset_puzzle = Callable()
	if is_instance_valid(level_owner):
		var puzzle: Node = level_owner._room if level_owner.has_method("_replace_puzzle_for_restart") else level_owner
		puzzle._transitioning = false
		puzzle.set_presentation_locked(false)
	queue_free()
