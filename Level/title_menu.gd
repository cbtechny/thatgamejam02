extends Control

const CURTAIN_ANIMATION: StringName = &"curtain"
const LEVEL_ONE_PATH: String = "res://Level/level_1_music_box.tscn"

@onready var _curtain_players: Array[AnimationPlayer] = [
	$Curtain/AnimationPlayer,
	$RightCurtainAnchor/Curtain/AnimationPlayer,
]
@onready var _right_curtain_anchor: Node2D = $RightCurtainAnchor
@onready var _play_button: Button = $ContentMargins/MainBdy/ButtonContainer/PlayButton

var _curtain_playing := false
var _curtains_remaining := 0

func _ready() -> void:
	# Keep the authored looping preview intact; this menu plays it once on demand.
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
	_play_button.focus_mode = Control.FOCUS_ALL
	_play_button.grab_focus()
	for button: Button in find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_ALL
		_apply_focus_style(button)

func _update_right_curtain_anchor() -> void:
	_right_curtain_anchor.position.x = size.x

func _apply_focus_style(button: Button) -> void:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.95, 0.72, 0.3, 0.18)
	focus.border_color = Color(1.0, 0.82, 0.42, 1.0)
	focus.set_border_width_all(5)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)

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
	if animation_name != CURTAIN_ANIMATION or not _curtain_playing:
		return
	_curtains_remaining -= 1
	if _curtains_remaining > 0:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_ONE_PATH)
