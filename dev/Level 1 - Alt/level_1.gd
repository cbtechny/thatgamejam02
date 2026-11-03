extends Node2D
## Crank, release, fan-lift, and loose-rope prototype for Level 1.

const CRANK_KNOB_LOCAL_POSITION: Vector2 = Vector2(576.0, 0.0)
const CRANK_HIT_RADIUS: float = 100.0
const KEY_PIXELS_PER_RADIAN: float = 100.0
const KEY_MIN_Y: float = 110.0
const KEY_MAX_Y: float = 560.0
const ROPE_SEGMENT_COUNT: int = 32
const ROPE_TEXTURE_WIDTH: float = 50.0
const ROPE_SEGMENT_RADIUS: float = 12.5
const LEFT_FAN_PUSH_MULTIPLIER: float = 2.4
const LEFT_FAN_DAMPING: float = 0.12
const KEY_ENDPOINT_HIT_RADIUS: float = 21.0
const KEY_ENDPOINT_ASSIST_RADIUS: float = 96.0
const KEY_ENDPOINT_ASSIST_ACCELERATION: float = 520.0
const KEY_MAX_FLIGHT_SPEED: float = 900.0
const MIDDLE_KEY_TRAVEL: float = 105.0
const MIDDLE_FAN_PULSE_PERIOD: float = 2.0
const AUDIO_SAMPLE_RATE: int = 22050
const FULL_KEY_TEXTURE: Texture2D = preload("res://Art/Textures/Resources/Key/key_full.tres")
const CURTAIN_SCENE: PackedScene = preload("res://dev/title/curtain.tscn")
const MENU_OVERLAY_SCRIPT: Script = preload("res://dev/Level 1 - Alt/menu_overlay.gd")
const TITLE_SCENE_PATH: String = "res://Level/title_menu.tscn"
signal title_transition_finished

@onready var _key: RigidBody2D = $Key0 as RigidBody2D
@onready var _key_sprite: Sprite2D = $Key0/Sprite2D as Sprite2D
@onready var _crank: Node2D = $Crank as Node2D
@onready var _crank_handle: Node2D = $Crank/Handle as Node2D
@onready var _rope_line: Line2D = $Rope/RopeLine as Line2D
@onready var _middle_fan_blades: AnimatedSprite2D = $MiddleFan/Blades as AnimatedSprite2D
@onready var _left_fan_blades: AnimatedSprite2D = $LeftFan/Blades as AnimatedSprite2D
@onready var _middle_key: Sprite2D = $Key1 as Sprite2D
@onready var _left_fan: Node2D = $LeftFan as Node2D
@onready var _release_hint: Label = $UI/ReleaseHint as Label
@onready var _ui_key0: Sprite2D = $UI/Key0 as Sprite2D
@onready var _ui_key1: Sprite2D = $UI/Key1 as Sprite2D
@onready var _ui_key2: Sprite2D = $UI/Key2 as Sprite2D
@onready var _ui: CanvasLayer = $UI as CanvasLayer
@onready var _keyhole: Sprite2D = $UI/KeyHole as Sprite2D
@onready var _key3_placeholder: Sprite2D = $UI/Key3 as Sprite2D

var _dragging_crank: bool = false
var _released: bool = false
var _left_fan_active: bool = false
var _previous_crank_angle: float = 0.0
var _rope_anchor: Vector2
var _rope_length: float = 0.0
var _rope_rest_points: PackedVector2Array = PackedVector2Array()
var _rope_bodies: Array[RigidBody2D] = []
var _middle_fan_active: bool = false
var _middle_fan_pulse_time: float = 0.0
var _key_snapped: bool = false
var _missed: bool = false
var _key_start_y: float = 0.0
var _left_fan_start_y: float = 0.0
var _middle_key_start_y: float = 0.0
var _crank_highlight: HighlightPulse
var _fan_highlight: HighlightPulse
var _center_highlight: HighlightPulse
var _keyhole_highlight: HighlightPulse
var _third_piece_highlight: HighlightPulse
var _flash_overlay: ColorRect
var _third_world_piece: Sprite2D
var _key0_endpoint: Area2D
var _key1_endpoint: Area2D
var _sfx_players: Dictionary = {}
var _crank_angle_since_tick: float = 0.0
var _pause_menu_open: bool = false
var _transitioning: bool = false
var _title_transition_curtains_remaining: int = 0


func _ready() -> void:
	_rope_rest_points = _rope_line.points.duplicate()
	_rope_length = _get_authored_rope_length()
	_rope_anchor = _rope_line.to_global(_rope_line.points[0])
	_key.freeze = true
	_key.linear_velocity = Vector2.ZERO
	_middle_fan_blades.stop()
	_set_left_fan_active(false)
	_configure_rope_line()
	_key_start_y = _key.global_position.y
	_left_fan_start_y = _left_fan.position.y
	_middle_key_start_y = _middle_key.position.y
	_create_endpoint_hitboxes()
	_crank_highlight = _add_highlight($Crank/Handle/CrankKnob2 as Node2D, 150.0)
	_fan_highlight = _add_highlight(_left_fan, 150.0)
	_center_highlight = _add_highlight(_middle_key, 150.0)
	_keyhole_highlight = _add_highlight(_keyhole, 220.0)
	_third_piece_highlight = _add_highlight(_ui_key2, 150.0)
	_center_highlight.set_active(false)
	_keyhole_highlight.set_active(false)
	_third_piece_highlight.set_active(false)
	_add_key_particles(_key)
	_add_key_particles(_middle_key)
	_create_flash_overlay()
	_setup_sfx()
	_update_tethered_rope()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not _released and not _transitioning and not _pause_menu_open:
			_show_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if _released or _transitioning or _pause_menu_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var knob_position: Vector2 = _crank.to_global(CRANK_KNOB_LOCAL_POSITION.rotated(_crank_handle.rotation))
			if event.position.distance_to(knob_position) <= CRANK_HIT_RADIUS:
				_dragging_crank = true
				_crank_highlight.set_active(false)
				_previous_crank_angle = (event.position - _crank.global_position).angle()
				get_viewport().set_input_as_handled()
		elif _dragging_crank:
			_dragging_crank = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_crank:
		var angle: float = (event.position - _crank.global_position).angle()
		var angular_delta: float = wrapf(angle - _previous_crank_angle, -PI, PI)
		_previous_crank_angle = angle
		_crank_handle.rotation += angular_delta
		_maybe_play_crank_tick(angular_delta)
		var key_position: Vector2 = _key.global_position
		key_position.y = clampf(
			key_position.y - angular_delta * KEY_PIXELS_PER_RADIAN,
			KEY_MIN_Y,
			KEY_MAX_Y
		)
		_key.global_position = key_position
		_key.force_update_transform()
		_update_tethered_rope()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_release_key()
		get_viewport().set_input_as_handled()



func _physics_process(_delta: float) -> void:
	if _released:
		if _left_fan_active and not _key_snapped and not _missed:
			if _key_is_out_of_bounds():
				_show_miss_screen()
				return
			if _endpoints_touch():
				_key.linear_velocity = Vector2.ZERO
				_key.angular_velocity = 0.0
				_key.freeze = true
				_key_snapped = true
				_celebrate_key_connection()
			else:
				var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
				_apply_endpoint_assist()
				var fan_force: Vector2 = Vector2(1.0, -0.42) * gravity * _key.mass * LEFT_FAN_PUSH_MULTIPLIER
				fan_force -= _key.linear_velocity * LEFT_FAN_DAMPING * _key.mass
				_key.apply_central_force(fan_force)
				_key.linear_velocity = _key.linear_velocity.limit_length(KEY_MAX_FLIGHT_SPEED)
		_update_swinging_rope()
	else:
		_update_tethered_rope()


func _key_is_out_of_bounds() -> bool:
	var bounds: Rect2 = get_viewport_rect().grow(20.0)
	return not bounds.has_point(_key.global_position)


func _show_pause_menu() -> void:
	_pause_menu_open = true
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "PauseMenu"
	backdrop.color = Color(0.025, 0.035, 0.08, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.set_script(MENU_OVERLAY_SCRIPT)
	backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.connect("resume_requested", _resume_from_pause)
	_ui.add_child(backdrop)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -190.0
	panel.offset_top = -140.0
	panel.offset_right = 190.0
	panel.offset_bottom = 140.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	backdrop.add_child(panel)
	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	panel.add_child(title)
	var resume_button: Button = Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(300.0, 64.0)
	resume_button.pressed.connect(_resume_from_pause)
	panel.add_child(resume_button)
	var retry_button: Button = Button.new()
	retry_button.text = "Retry"
	retry_button.custom_minimum_size = Vector2(300.0, 64.0)
	retry_button.pressed.connect(_retry_level)
	panel.add_child(retry_button)
	var title_button: Button = Button.new()
	title_button.text = "Return to Title"
	title_button.custom_minimum_size = Vector2(300.0, 64.0)
	title_button.pressed.connect(_return_to_title)
	panel.add_child(title_button)
	_style_menu_buttons([resume_button, retry_button, title_button])
	resume_button.call_deferred("grab_focus")
	get_tree().paused = true


func _resume_from_pause() -> void:
	if not _pause_menu_open:
		return
	_pause_menu_open = false
	get_tree().paused = false
	var backdrop: Node = _ui.get_node_or_null("PauseMenu")
	if backdrop != null:
		backdrop.queue_free()


func _show_miss_screen() -> void:
	_missed = true
	_play_sfx("miss")
	_key.freeze = true
	_set_left_fan_active(false)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "MissScreen"
	backdrop.color = Color(0.025, 0.035, 0.08, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(backdrop)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -190.0
	panel.offset_top = -105.0
	panel.offset_right = 190.0
	panel.offset_bottom = 105.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	backdrop.add_child(panel)
	var title: Label = Label.new()
	title.text = "MISSED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	panel.add_child(title)
	_add_terminal_menu_buttons(panel)
	_set_terminal_menu_focus(backdrop)
	_release_hint.text = "The key missed the target"
	get_tree().paused = true


func _add_terminal_menu_buttons(panel: VBoxContainer) -> void:
	var retry_button: Button = Button.new()
	retry_button.text = "Retry"
	retry_button.custom_minimum_size = Vector2(300.0, 64.0)
	retry_button.pressed.connect(_retry_level)
	panel.add_child(retry_button)
	var title_button: Button = Button.new()
	title_button.text = "Return to Title"
	title_button.custom_minimum_size = Vector2(300.0, 64.0)
	title_button.pressed.connect(_return_to_title)
	panel.add_child(title_button)
	_style_menu_buttons([retry_button, title_button])
	retry_button.call_deferred("grab_focus")


func _set_terminal_menu_focus(backdrop: Control) -> void:
	backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP


func _style_menu_buttons(buttons: Array[Button]) -> void:
	for button: Button in buttons:
		button.focus_mode = Control.FOCUS_ALL
		var focus: StyleBoxFlat = StyleBoxFlat.new()
		focus.bg_color = Color(0.95, 0.72, 0.3, 0.2)
		focus.border_color = Color(1.0, 0.82, 0.42, 1.0)
		focus.set_border_width_all(4)
		focus.set_corner_radius_all(6)
		button.add_theme_stylebox_override("focus", focus)


func _retry_level() -> void:
	_transitioning = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_title() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().paused = true
	var left_curtain: Node2D = CURTAIN_SCENE.instantiate() as Node2D
	left_curtain.z_index = 100
	_ui.add_child(left_curtain)
	var right_anchor: Node2D = Node2D.new()
	right_anchor.name = "RightCurtainAnchor"
	right_anchor.position.x = get_viewport_rect().size.x
	right_anchor.scale = Vector2(-1.0, 1.0)
	right_anchor.z_index = 100
	_ui.add_child(right_anchor)
	var right_curtain: Node2D = CURTAIN_SCENE.instantiate() as Node2D
	right_anchor.add_child(right_curtain)
	var players: Array[AnimationPlayer] = [
		left_curtain.get_node("AnimationPlayer") as AnimationPlayer,
		right_curtain.get_node("AnimationPlayer") as AnimationPlayer,
	]
	_title_transition_curtains_remaining = players.size()
	for player: AnimationPlayer in players:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		var library: AnimationLibrary = player.get_animation_library(&"").duplicate(true) as AnimationLibrary
		library.get_animation(&"curtain").loop_mode = Animation.LOOP_NONE
		player.remove_animation_library(&"")
		player.add_animation_library(&"", library)
		player.animation_finished.connect(_on_title_curtain_finished)
		player.play(&"curtain")
		player.seek(0.0, true)
	await title_transition_finished
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _on_title_curtain_finished(animation_name: StringName) -> void:
	if animation_name != &"curtain":
		return
	_title_transition_curtains_remaining -= 1
	if _title_transition_curtains_remaining == 0:
		title_transition_finished.emit()

func _process(delta: float) -> void:
	_left_fan.position.y = _left_fan_start_y + (_key.global_position.y - _key_start_y)
	_middle_fan_pulse_time = fmod(_middle_fan_pulse_time + delta, MIDDLE_FAN_PULSE_PERIOD)
	var pulse_phase: float = _middle_fan_pulse_time / MIDDLE_FAN_PULSE_PERIOD * TAU
	var fan_should_be_active: bool = cos(pulse_phase) > 0.0
	if fan_should_be_active != _middle_fan_active:
		_set_middle_fan_active(fan_should_be_active)
	_middle_key.position.y = _middle_key_start_y - sin(pulse_phase) * MIDDLE_KEY_TRAVEL


func _release_key() -> void:
	if _released:
		return
	_released = true
	_dragging_crank = false
	_crank_highlight.set_active(false)
	_fan_highlight.set_active(false)
	_center_highlight.set_active(true)
	_set_left_fan_active(true)
	_play_sfx("fan_start")
	_key.freeze = false
	_key.linear_velocity = Vector2.ZERO
	_key.angular_velocity = 0.0
	_build_swinging_rope()


func _set_left_fan_active(active: bool) -> void:
	_left_fan_active = active
	if active:
		_left_fan_blades.play("spin")
	else:
		_left_fan_blades.stop()
	_set_fan_whirr_active("left_fan_whirr", active)


func _create_endpoint_hitboxes() -> void:
	_key0_endpoint = _make_endpoint_area("Key0End", Vector2(
		_key_sprite.texture.get_width() * 0.5,
		0.0
	))
	_key1_endpoint = _make_endpoint_area("Key1End", Vector2(-_middle_key.texture.get_width() * 0.5, 0.0))
	_key_sprite.add_child(_key0_endpoint)
	_middle_key.add_child(_key1_endpoint)


func _make_endpoint_area(node_name: String, local_position: Vector2) -> Area2D:
	var area: Area2D = Area2D.new()
	area.name = node_name
	area.position = local_position
	area.collision_layer = 4
	area.collision_mask = 4
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = KEY_ENDPOINT_HIT_RADIUS
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	return area


func _endpoints_touch() -> bool:
	var key0_radius: float = KEY_ENDPOINT_HIT_RADIUS * _key0_endpoint.global_transform.x.length()
	var key1_radius: float = KEY_ENDPOINT_HIT_RADIUS * _key1_endpoint.global_transform.x.length()
	return _key0_endpoint.global_position.distance_to(_key1_endpoint.global_position) <= key0_radius + key1_radius


func _apply_endpoint_assist() -> void:
	var offset: Vector2 = _key1_endpoint.global_position - _key0_endpoint.global_position
	var distance: float = offset.length()
	var contact_distance: float = (
		KEY_ENDPOINT_HIT_RADIUS * _key0_endpoint.global_transform.x.length()
		+ KEY_ENDPOINT_HIT_RADIUS * _key1_endpoint.global_transform.x.length()
	)
	if distance >= KEY_ENDPOINT_ASSIST_RADIUS or distance <= contact_distance:
		return
	var influence: float = 1.0 - inverse_lerp(contact_distance, KEY_ENDPOINT_ASSIST_RADIUS, distance)
	var assist_force: Vector2 = offset.normalized() * KEY_ENDPOINT_ASSIST_ACCELERATION * influence * _key.mass
	_key.apply_central_force(assist_force)


func _set_middle_fan_active(active: bool) -> void:
	_middle_fan_active = active
	if active:
		_middle_fan_blades.play("spin")
	else:
		_middle_fan_blades.stop()
	_set_fan_whirr_active("middle_fan_whirr", active)
	_release_hint.text = "Middle fan pulses automatically: %s" % ("on" if active else "off")


func _celebrate_key_connection() -> void:
	_center_highlight.set_active(false)
	_third_piece_highlight.set_active(true)
	_flash_screen()
	_play_sfx("key_join")
	_emit_key_burst(_key.global_position)
	_emit_key_burst(_middle_key.global_position)
	for icon: Sprite2D in [_ui_key0, _ui_key1]:
		var original_scale: Vector2 = icon.scale
		_reveal_ui_fragment(icon)
		var pulse: Tween = create_tween()
		pulse.tween_property(icon, "scale", original_scale * 1.18, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(icon, "scale", original_scale, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animate_final_assembly()


func _animate_final_assembly() -> void:
	_reveal_ui_fragment(_ui_key2)
	_third_world_piece = Sprite2D.new()
	_third_world_piece.name = "Key2World"
	_third_world_piece.texture = _ui_key2.texture
	_third_world_piece.scale = Vector2(0.4, 0.4)
	_third_world_piece.modulate = Color.WHITE
	add_child(_third_world_piece)
	_third_world_piece.global_position = _ui_key2.global_position
	_add_key_particles(_third_world_piece)
	var third_piece_gap: float = (
		_middle_key.texture.get_width() * _middle_key.scale.x * 0.5
		+ _third_world_piece.texture.get_width() * _third_world_piece.scale.x * 0.5
	)
	var third_piece_target: Vector2 = _middle_key.global_position + Vector2(third_piece_gap, 0.0)
	var join_tween: Tween = create_tween().set_parallel(true)
	join_tween.tween_property(_third_world_piece, "global_position", third_piece_target, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await join_tween.finished
	_emit_key_burst(_third_world_piece.global_position)
	_flash_screen()
	_play_sfx("key_join")
	_third_piece_highlight.set_active(false)
	_keyhole_highlight.set_active(true)
	_key_sprite.texture = FULL_KEY_TEXTURE
	_key3_placeholder.hide()
	_key_sprite.position = Vector2.ZERO
	_key_sprite.scale = Vector2(0.4, 0.4)
	_middle_key.hide()
	_third_world_piece.hide()
	_release_hint.text = "Key assembled — moving to the keyhole"
	var wiggle: Tween = create_tween()
	for index: int in range(2):
		wiggle.tween_property(_key_sprite, "rotation", -0.07, 0.09)
		wiggle.tween_property(_key_sprite, "rotation", 0.07, 0.18)
	wiggle.tween_property(_key_sprite, "rotation", 0.0, 0.09)
	await wiggle.finished
	var group_motion: Vector2 = _keyhole.global_position - _key.global_position
	var finish_tween: Tween = create_tween()
	finish_tween.tween_property(_key, "global_position", _key.global_position + group_motion, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await finish_tween.finished
	_flash_screen()
	_play_sfx("win")
	_keyhole_highlight.set_active(false)
	_show_win_screen()
	var win_pulses: Array[Tween] = []
	for icon: Sprite2D in [_ui_key0, _ui_key1, _ui_key2]:
		_reveal_ui_fragment(icon)
		var win_pulse: Tween = create_tween()
		win_pulse.tween_property(icon, "scale", icon.scale * 1.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		win_pulse.tween_property(icon, "scale", icon.scale, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		win_pulses.append(win_pulse)
	for win_pulse: Tween in win_pulses:
		await win_pulse.finished
	get_tree().paused = true

func _reveal_ui_fragment(icon: Sprite2D) -> void:
	icon.show()
	icon.modulate = Color.WHITE
	icon.self_modulate = Color.WHITE


func _show_win_screen() -> void:
	_release_hint.text = "WIN!"
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "WinScreen"
	backdrop.color = Color(0.025, 0.035, 0.08, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(backdrop)
	_ui.move_child(backdrop, 0)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -270.0
	panel.offset_top = -150.0
	panel.offset_right = 270.0
	panel.offset_bottom = 150.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	backdrop.add_child(panel)
	var label: Label = Label.new()
	label.text = "KEY COMPLETE!\nYou found the way home."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	panel.add_child(label)
	_add_terminal_menu_buttons(panel)
	_set_terminal_menu_focus(backdrop)

func _setup_sfx() -> void:
	_register_sfx("crank", "click", 0.075)
	_register_sfx("fan_start", "fan", 0.42)
	_register_sfx("left_fan_whirr", "mechanical_whirr", 1.2)
	_register_sfx("middle_fan_whirr", "mechanical_whirr", 1.2)
	_register_sfx("key_join", "join", 0.78)
	_register_sfx("miss", "miss", 0.48)
	_register_sfx("win", "win", 1.35)
	_set_fan_whirr_active("left_fan_whirr", _left_fan_active)
	_set_fan_whirr_active("middle_fan_whirr", _middle_fan_active)


func _register_sfx(player_name: String, sound_kind: String, duration: float) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "SFX_" + player_name
	player.volume_db = -16.0 if player_name == "crank" else (-14.0 if sound_kind == "mechanical_whirr" else -10.0)
	player.stream = _make_sfx_stream(sound_kind, duration)
	if sound_kind == "mechanical_whirr":
		var whirr_stream: AudioStreamWAV = player.stream as AudioStreamWAV
		whirr_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		whirr_stream.loop_begin = 0
		whirr_stream.loop_end = int(duration * AUDIO_SAMPLE_RATE)
	add_child(player)
	_sfx_players[player_name] = player


func _make_sfx_stream(sound_kind: String, duration: float) -> AudioStreamWAV:
	var sample_count: int = int(duration * AUDIO_SAMPLE_RATE)
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase: float = 0.0
	for sample_index: int in range(sample_count):
		var progress: float = float(sample_index) / float(sample_count)
		var frequency: float = 440.0
		var envelope: float = 0.0
		var signal_value: float = 0.0
		match sound_kind:
			"click":
				frequency = lerpf(1500.0, 420.0, progress)
				envelope = exp(-progress * 20.0)
				signal_value = sin(phase * TAU) * 0.75 + sin(phase * TAU * 1.73) * 0.25
			"fan":
				frequency = lerpf(180.0, 420.0, progress)
				envelope = sin(progress * PI) * 0.48
				var airy_noise: float = sin(float(sample_index) * 12.9898) * cos(float(sample_index) * 78.233)
				signal_value = sin(phase * TAU) * 0.7 + airy_noise * 0.3
			"mechanical_whirr":
				frequency = 120.0
				envelope = 0.48 + sin(progress * TAU * 8.0) * 0.045
				var rotor_pulse: float = sin(phase * TAU * 2.0)
				var bearing_tone: float = sin(phase * TAU * 3.0)
				var blade_harmonic: float = sin(phase * TAU * 5.0)
				signal_value = sin(phase * TAU) * 0.48 + rotor_pulse * 0.26 + bearing_tone * 0.16 + blade_harmonic * 0.1
			"join":
				frequency = 659.25 if progress < 0.34 else (880.0 if progress < 0.67 else 1174.66)
				envelope = minf(1.0, progress * 30.0) * (1.0 - progress) * 0.72
				signal_value = sin(phase * TAU) * 0.85 + sin(phase * TAU * 2.01) * 0.15
			"miss":
				frequency = lerpf(330.0, 125.0, progress)
				envelope = (1.0 - progress) * (1.0 - progress) * 0.68
				signal_value = sin(phase * TAU)
			"win":
				frequency = 523.25 if progress < 0.25 else (659.25 if progress < 0.5 else (783.99 if progress < 0.75 else 1046.5))
				envelope = minf(1.0, progress * 24.0) * (1.0 - progress * 0.72) * 0.62
				signal_value = sin(phase * TAU) * 0.8 + sin(phase * TAU * 2.0) * 0.2
		var pcm_sample: int = int(clampf(signal_value * envelope, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(sample_index * 2, pcm_sample)
		phase = fmod(phase + frequency / float(AUDIO_SAMPLE_RATE), 1.0)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _maybe_play_crank_tick(angular_delta: float) -> void:
	_crank_angle_since_tick += absf(angular_delta)
	if _crank_angle_since_tick >= 0.34:
		_crank_angle_since_tick = fmod(_crank_angle_since_tick, 0.34)
		_play_sfx("crank")


func _play_sfx(player_name: String) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(player_name) as AudioStreamPlayer
	if player == null:
		return
	player.stop()
	player.play()


func _set_fan_whirr_active(player_name: String, active: bool) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(player_name) as AudioStreamPlayer
	if player == null:
		return
	if active and not player.playing:
		player.play()
	elif not active and player.playing:
		player.stop()


func _add_highlight(target: Node2D, glow_radius: float) -> HighlightPulse:
	var highlight: HighlightPulse = HighlightPulse.new()
	highlight.radius = glow_radius
	highlight.z_index = -1
	target.add_child(highlight)
	return highlight


func _add_key_particles(target: Node2D) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "KeySparkles"
	particles.amount = 12
	particles.lifetime = 1.3
	particles.explosiveness = 0.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(35.0, 14.0)
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 7.0
	particles.initial_velocity_max = 24.0
	particles.gravity = Vector2(0.0, -5.0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = Color(1.0, 0.88, 0.56, 0.72)
	particles.texture = _make_sparkle_texture()
	target.add_child(particles)
	particles.position = Vector2.ZERO
	particles.emitting = true


func _make_sparkle_texture() -> Texture2D:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in range(16):
		for x: int in range(16):
			var distance: float = Vector2(x - 7.5, y - 7.5).length() / 7.5
			var alpha: float = clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _emit_key_burst(world_position: Vector2) -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.name = "KeyConnectionBurst"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 36
	burst.lifetime = 0.65
	burst.explosiveness = 1.0
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 65.0
	burst.initial_velocity_max = 180.0
	burst.gravity = Vector2.ZERO
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color.WHITE
	burst.texture = _make_sparkle_texture()
	_ui.add_child(burst)
	burst.global_position = world_position
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


func _create_flash_overlay() -> void:
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "SuccessFlash"
	_flash_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_flash_overlay)


func _flash_screen() -> void:
	var flash: Tween = create_tween()
	flash.tween_property(_flash_overlay, "color:a", 0.42, 0.06)
	flash.tween_property(_flash_overlay, "color:a", 0.0, 0.28)


func _update_tethered_rope() -> void:
	if _released:
		return
	var points: PackedVector2Array = _rope_rest_points.duplicate()
	if not points.is_empty():
		points[-1] = _rope_line.to_local(_key_sprite.global_position)
	_rope_line.points = points


func _build_swinging_rope() -> void:
	_configure_rope_line()
	var path_points: PackedVector2Array = _get_world_rope_points(_rope_line.points)
	_rope_length = _polyline_length(path_points)
	if path_points.size() < 2 or _rope_length <= 1.0:
		return
	var anchor_body: StaticBody2D = StaticBody2D.new()
	anchor_body.name = "SwingingRopeAnchor"
	anchor_body.collision_layer = 0
	anchor_body.collision_mask = 0
	add_child(anchor_body)
	anchor_body.global_position = _rope_anchor

	var previous_body: PhysicsBody2D = anchor_body
	var segment_length: float = _rope_length / float(ROPE_SEGMENT_COUNT)
	for index: int in range(ROPE_SEGMENT_COUNT):
		var body: RigidBody2D = RigidBody2D.new()
		body.name = "SwingingRopeSegment%02d" % index
		body.mass = 0.15
		body.gravity_scale = 1.0
		body.collision_layer = 0
		body.collision_mask = 0
		body.can_sleep = false
		var shape: CapsuleShape2D = CapsuleShape2D.new()
		shape.radius = ROPE_SEGMENT_RADIUS
		shape.height = segment_length + ROPE_SEGMENT_RADIUS * 2.0
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		var segment_start: Vector2 = _sample_polyline(path_points, segment_length * float(index))
		var segment_end: Vector2 = _sample_polyline(path_points, segment_length * float(index + 1))
		var segment_center: float = segment_length * (float(index) + 0.5)
		var before: Vector2 = _sample_polyline(path_points, maxf(segment_center - 1.0, 0.0))
		var after: Vector2 = _sample_polyline(path_points, minf(segment_center + 1.0, _rope_length))
		body.global_position = (segment_start + segment_end) * 0.5
		body.global_rotation = (after - before).angle() - PI * 0.5
		_rope_bodies.append(body)

		var joint: PinJoint2D = PinJoint2D.new()
		joint.name = "SwingingRopeJoint%02d" % index
		joint.disable_collision = true
		add_child(joint)
		joint.global_position = _sample_polyline(path_points, segment_length * float(index))
		joint.node_a = joint.get_path_to(previous_body)
		joint.node_b = joint.get_path_to(body)
		previous_body = body

	_update_swinging_rope()


func _update_swinging_rope() -> void:
	if _rope_bodies.is_empty():
		return
	var points: PackedVector2Array = PackedVector2Array()
	points.append(_rope_line.to_local(_rope_anchor))
	for body: RigidBody2D in _rope_bodies:
		points.append(_rope_line.to_local(body.global_position))
	var segment_length: float = _rope_length / float(ROPE_SEGMENT_COUNT)
	var last_body: RigidBody2D = _rope_bodies[-1]
	points.append(_rope_line.to_local(last_body.to_global(Vector2.DOWN * segment_length * 0.5)))
	_rope_line.points = points


func _configure_rope_line() -> void:
	_rope_line.width = ROPE_TEXTURE_WIDTH
	_rope_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_rope_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_rope_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope_line.end_cap_mode = Line2D.LINE_CAP_ROUND


func _get_authored_rope_length() -> float:
	return _polyline_length(_get_world_rope_points(_rope_line.points))


func _get_world_rope_points(local_points: PackedVector2Array) -> PackedVector2Array:
	var world_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_points:
		world_points.append(_rope_line.to_global(point))
	return world_points


func _polyline_length(points: PackedVector2Array) -> float:
	var length: float = 0.0
	for index: int in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return maxf(length, 1.0)


func _sample_polyline(points: PackedVector2Array, distance: float) -> Vector2:
	var remaining: float = clampf(distance, 0.0, _rope_length)
	for index: int in range(1, points.size()):
		var segment_length: float = points[index - 1].distance_to(points[index])
		if remaining <= segment_length:
			return points[index - 1].lerp(points[index], remaining / maxf(segment_length, 0.001))
		remaining -= segment_length
	return points[-1]
