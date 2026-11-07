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
var _information_menu: CanvasLayer

func _ready() -> void:
	get_tree().paused = false
	var backdrop: Control = preload("res://Level/living_backdrop.tscn").instantiate()
	backdrop.z_index = -10
	add_child(backdrop)
	move_child(backdrop, 0)
	theme = preload("res://Level/music_box_theme.gd").create()
	_information_menu = preload("res://Level/campaign_menu.gd").new()
	add_child(_information_menu)
	var session: Node = get_node("/root/ReleaseSession")
	var rules: Button = $ContentMargins/MainBdy/ButtonContainer/RulesButton
	rules.pressed.connect(func(): _information_menu.show_information("How to play", session.CONTROLS, rules))
	var credits: Button = $ContentMargins/MainBdy/ButtonContainer2/TeamButton
	credits.text = "Credits"
	credits.pressed.connect(func(): _information_menu.show_information("Credits", session.CREDITS, credits))
	var controls := HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls.add_theme_constant_override("separation", 24)
	$ContentMargins/MainBdy.add_child(controls)
	_information_menu.add_release_controls(controls)
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
	button.theme = theme

func _on_play_button_pressed() -> void:
	if _curtain_playing:
		return
	_curtain_playing = true
	_curtains_remaining = _curtain_players.size()
	_play_button.disabled = true
	$ContentMargins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button: Button in $ContentMargins.find_children("*", "Button", true, false):
		button.disabled = true
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
	get_node("/root/SceneFade").go(LEVEL_ONE_PATH)
