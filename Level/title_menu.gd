extends Control

const CURTAIN_ANIMATION: StringName = &"curtain"

@onready var _curtain_players: Array[AnimationPlayer] = [
	$Curtain/AnimationPlayer,
	$RightCurtainAnchor/Curtain/AnimationPlayer,
]
@onready var _right_curtain_anchor: Node2D = $RightCurtainAnchor
@onready var _play_button: Button = $ContentMargins/MainBdy/ButtonContainer/PlayButton

var _curtain_playing := false
var _curtains_remaining := 0

func _ready() -> void:
	# Play once in the menu while keeping the authored scene's looping preview.
	for player in _curtain_players:
		var library := player.get_animation_library(&"").duplicate(true) as AnimationLibrary
		library.get_animation(CURTAIN_ANIMATION).loop_mode = Animation.LOOP_NONE
		player.remove_animation_library(&"")
		player.add_animation_library(&"", library)
		player.animation_finished.connect(_on_curtain_animation_finished)
		player.play(CURTAIN_ANIMATION)
		player.seek(0.0, true)
		player.pause()
	resized.connect(_update_right_curtain_anchor)
	_update_right_curtain_anchor()

func _update_right_curtain_anchor() -> void:
	_right_curtain_anchor.position.x = size.x

func _on_play_button_pressed() -> void:
	if _curtain_playing:
		return
	_curtain_playing = true
	_curtains_remaining = _curtain_players.size()
	_play_button.disabled = true
	for player in _curtain_players:
		player.play(CURTAIN_ANIMATION)
		player.seek(0.0, true)

func _on_curtain_animation_finished(animation_name: StringName) -> void:
	if animation_name != CURTAIN_ANIMATION:
		return
	_curtains_remaining -= 1
	if _curtains_remaining > 0:
		return
	_curtain_playing = false
	_play_button.disabled = false
