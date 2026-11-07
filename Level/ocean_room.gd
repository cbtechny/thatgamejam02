extends Node2D
## Shared tide controls, fan flight, guidance and campaign lifecycle.

enum State { RESTING, HOPPING, FAILED, COMPLETED, FALLING }

const PLANK_TEXTURE: Texture2D = preload("res://Art/Textures/T_OceanPlank.png")
const STONE_TEXTURE: Texture2D = preload("res://Art/Textures/T_OceanStone.png")
const REFERENCE_SIZE := Vector2(360.0, 200.0)
const CRANK_KNOB_LOCAL_POSITION := Vector2(576.0, 0.0)
const CRANK_HIT_RADIUS: float = 9.0
const FRAGMENT_OFFSET := Vector2(0.0, -7.5)
const HOP_HEIGHT: float = 20.0
const KEY_CRANK_STEP: float = 0.12
const AUDIO_SAMPLE_RATE: int = 22050
const UI_RESOLUTION: float = 6.0
const TITLE_SCENE_PATH: String = "res://Level/title_menu.tscn"
const UI_THEME = preload("res://Level/music_box_theme.gd")
const INK := UI_THEME.INK
const GOLD := UI_THEME.GOLD

@export_range(0.1, 2.0, 0.05) var hop_duration: float = 0.55

@onready var _crank: Node2D = $Crank
@onready var _crank_handle: Node2D = $Crank/Handle
@onready var _fan_blades: AnimatedSprite2D = $Fan/Blades
@onready var _fragment: Sprite2D = $Fragment
@onready var _feedback: Label = $Feedback
@onready var _fire_button: Button = $FireButton

var _stage_play_area := Rect2()
var _scenery_bounds := Rect2(Vector2.ZERO, REFERENCE_SIZE)
var initial_crank_angle: float = -PI * 0.5
var _platform_names: PackedStringArray
var _floating_platforms: PackedInt32Array
var _next_scene: String
var _guide: Node2D
var _label_backing: StyleBoxFlat
var _target_backing: StyleBoxFlat
var _state: State = State.RESTING
var _current_platform: int = 0
var _target_platform: int = -1
var _crank_angle: float = 0.0
var _elapsed_time: float = 0.0
var _hop_elapsed: float = 0.0
var _flight_duration: float = 0.0
var _hop_start := Vector2.ZERO
var _hop_end := Vector2.ZERO
var _fall_y: float = 0.0
var _fan_active: bool = false
var _dragging_crank: bool = false
var _previous_crank_angle: float = 0.0
var _crank_angle_since_tick: float = 0.0
var _exiting: bool = false
var _presentation_locked: bool = false
var _sfx_players: Dictionary = {}
var _campaign_menu: CanvasLayer
var _reset_prompt: Node
var _key_collection: Node2D
var _middle_fragment_platform: int = -1


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_prepare_controls()
	_guide = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_guide.material = unlit
	_guide.draw.connect(_draw_guide)
	add_child(_guide)
	_label_backing = _make_label_backing(GOLD.darkened(0.3))
	_target_backing = _make_label_backing(GOLD)
	_setup_sfx()
	_reset_prompt = preload("res://Level/restart_prompt.gd").attach($ResetButton, 1.5)
	_campaign_menu = preload("res://Level/campaign_menu.gd").new()
	_campaign_menu.room = self
	_campaign_menu.next_scene = _next_scene
	add_child(_campaign_menu)
	_key_collection = preload("res://Level/ocean_key_collection.gd").new()
	_key_collection.name = "KeyCollection"
	_key_collection.middle_platform = _middle_fragment_platform
	add_child(_key_collection)
	reset_level()


func _prepare_controls() -> void:
	var room_theme: Theme = UI_THEME.create(1.5)
	# Rasterize at display scale, preserving the reference-space input bounds.
	for child: Node in get_children():
		if child is Control:
			var control: Control = child as Control
			var reference_size: Vector2 = control.size
			var font_size: int = control.get_theme_font_size("font_size")
			control.theme = room_theme
			if control is Button:
				control.focus_mode = Control.FOCUS_ALL
			control.add_theme_font_size_override("font_size", int(font_size * UI_RESOLUTION))
			control.scale = Vector2.ONE / UI_RESOLUTION
			control.size = reference_size * UI_RESOLUTION


func set_stage_layout(play_area: Rect2) -> void:
	_stage_play_area = play_area
	_fit_viewport()


func _fit_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if get_parent() is Control:
		viewport_size = (get_parent() as Control).size
	var play_area := Rect2(Vector2.ZERO, viewport_size) if not _stage_play_area.has_area() else _stage_play_area
	var factor: float = minf(play_area.size.x / REFERENCE_SIZE.x, play_area.size.y / REFERENCE_SIZE.y)
	scale = Vector2.ONE * factor
	position = play_area.position + (play_area.size - REFERENCE_SIZE * factor) * 0.5
	_scenery_bounds = transform.affine_inverse() * Rect2(Vector2.ZERO, viewport_size)
	_update_scenery_bounds()
	queue_redraw()


func _update_scenery_bounds() -> void:
	pass

func set_presentation_locked(locked: bool) -> void:
	_presentation_locked = locked
	if locked:
		_release_crank()
	_update_guidance()
	($ResetButton as Button).disabled = locked


func _water_level() -> float:
	return 122.0 - 20.0 * sin(_crank_angle)


func _wave(x: float) -> float:
	return 2.5 * sin(0.035 * x - _elapsed_time * 2.0)


func _water_y(x: float) -> float:
	return _water_level() + _wave(x)


func _platform_anchor(platform: int) -> Vector2:
	var anchor := _deck_position(platform)
	if platform in _floating_platforms:
		anchor.y += _wave(anchor.x)
	return anchor


func _deck_position(_platform: int) -> Vector2:
	return Vector2.ZERO


func _can_launch() -> bool:
	return true


func _prepare_launch() -> void:
	pass


func _resolve_landing() -> int:
	return _target_platform


func _on_landing() -> void:
	_key_collection.collect_on_landing(_current_platform)


func _reset_mechanisms() -> void:
	pass


func _update_mechanisms() -> void:
	pass


func _hint() -> String:
	return ""


func _failure_hint() -> String:
	return "Missed the landing. Press R to try again."


func fire_fan() -> void:
	if _fire_button.disabled:
		return
	_hop_elapsed = 0.0
	_flight_duration = hop_duration
	_hop_start = _fragment.position
	_prepare_launch()
	_state = State.HOPPING
	_set_fan_active(true)
	_play_sfx("fan_start")
	_update_guidance()


func _hop_point(progress: float) -> Vector2:
	var point := _hop_start.lerp(_hop_end, progress)
	point.y -= sin(progress * PI) * HOP_HEIGHT
	return point


func _process(delta: float) -> void:
	if _exiting or _presentation_locked:
		return
	_elapsed_time += delta
	match _state:
		State.HOPPING:
			_hop_elapsed += delta
			var flight_time := minf(_hop_elapsed, _flight_duration)
			_fragment.position = _hop_point(flight_time / hop_duration)
			if _hop_elapsed >= _flight_duration:
				_land()
		State.FALLING:
			_hop_elapsed += delta
			var progress := clampf(_hop_elapsed / 0.38, 0.0, 1.0)
			_fragment.position.y = lerpf(_hop_end.y, _fall_y, progress * progress)
			_fragment.rotation = progress * PI
			if progress >= 1.0:
				_fragment.hide()
				_state = State.FAILED
				_update_guidance()
		State.RESTING, State.COMPLETED:
			_fragment.position = _platform_anchor(_current_platform) + FRAGMENT_OFFSET
	_key_collection.refresh()
	queue_redraw()
	_guide.queue_redraw()


func _land() -> void:
	_stop_fan()
	var landing := _resolve_landing()
	_target_platform = -1
	if landing < 0:
		_state = State.FALLING
		_hop_elapsed = 0.0
		_hop_end = _fragment.position
		_fall_y = maxf(_hop_end.y + 24.0, _water_y(_hop_end.x) + 10.0)
		_play_sfx("miss")
	else:
		_current_platform = landing
		_fragment.position = _platform_anchor(landing) + FRAGMENT_OFFSET
		_state = State.RESTING
		_on_landing()
		if landing == _platform_names.size() - 1:
			_state = State.COMPLETED
			_play_sfx("win")
			_campaign_menu.show_menu.call_deferred(true)
	_update_guidance()


func _update_guidance() -> void:
	_update_mechanisms()
	_fire_button.disabled = _presentation_locked or _state != State.RESTING or not _can_launch()
	if _presentation_locked:
		_feedback.text = ""
	else:
		match _state:
			State.COMPLETED:
				_feedback.text = "Delivered to the keyhole!"
			State.FAILED, State.FALLING:
				_feedback.text = _failure_hint()
			State.HOPPING:
				_feedback.text = "In flight…"
			_:
				_feedback.text = _hint()
	_reset_prompt.set_active(not _presentation_locked and _state in [State.FAILED, State.FALLING])
	_guide.queue_redraw()


func reset_level() -> void:
	if _exiting:
		return
	if _campaign_menu.completed:
		_campaign_menu.resume()
		_campaign_menu.completed = false
	_state = State.RESTING
	_current_platform = 0
	_target_platform = -1
	_elapsed_time = 0.0
	_hop_elapsed = 0.0
	_hop_start = Vector2.ZERO
	_hop_end = Vector2.ZERO
	_dragging_crank = false
	_previous_crank_angle = 0.0
	_crank_angle_since_tick = 0.0
	_reset_mechanisms()
	_set_crank_angle(initial_crank_angle)
	_fragment.rotation = 0.0
	_fragment.show()
	_key_collection.reset()
	_stop_fan()
	for player: AudioStreamPlayer in _sfx_players.values():
		player.stop()


func _stop_fan() -> void:
	_set_fan_active(false)


func _set_fan_active(active: bool) -> void:
	_fan_active = active
	if active:
		_fan_blades.play(&"spin")
	else:
		_fan_blades.stop()
		_fan_blades.animation = &"idle"
		_fan_blades.frame = 0
	_set_fan_whirr_active("fan_whirr", active)


func _set_crank_angle(angle: float) -> void:
	_crank_angle = _constrain_crank_angle(angle)
	_crank_handle.rotation = _crank_angle
	if _state == State.RESTING:
		_fragment.position = _platform_anchor(_current_platform) + FRAGMENT_OFFSET
	_update_guidance()
	queue_redraw()


func _constrain_crank_angle(angle: float) -> float:
	return wrapf(angle, -PI, PI)


func _release_crank() -> void:
	if _dragging_crank:
		_dragging_crank = false
		_update_guidance()


func _input(event: InputEvent) -> void:
	# Release must also work over a GUI control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_crank()


func _unhandled_input(event: InputEvent) -> void:
	if _exiting or _presentation_locked:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if not event.echo:
					reset_level()
			KEY_SPACE:
				if not event.echo:
					fire_fan()
			KEY_LEFT, KEY_RIGHT:
				if _state == State.RESTING and not _dragging_crank:
					var step: float = KEY_CRANK_STEP if event.keycode == KEY_RIGHT else -KEY_CRANK_STEP
					_set_crank_angle(_crank_angle + step)
					_play_sfx("crank")
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _state != State.RESTING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var knob: Vector2 = to_local(_crank.to_global(CRANK_KNOB_LOCAL_POSITION.rotated(_crank_handle.rotation)))
		if pointer.distance_to(knob) <= CRANK_HIT_RADIUS:
			_dragging_crank = true
			_previous_crank_angle = (pointer - _crank.position).angle()
			_update_guidance()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_crank:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var offset: Vector2 = pointer - _crank.position
		if offset.length() < 3.0:
			return
		var angle: float = offset.angle()
		var angular_delta: float = wrapf(angle - _previous_crank_angle, -PI, PI)
		_previous_crank_angle = angle
		_set_crank_angle(_crank_angle + angular_delta)
		_crank_angle_since_tick += absf(angular_delta)
		if _crank_angle_since_tick >= 0.34:
			_crank_angle_since_tick = fmod(_crank_angle_since_tick, 0.34)
			_play_sfx("crank")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_crank()


func _return_to_title() -> void:
	if _exiting:
		return
	_exiting = true
	get_node("/root/SceneFade").go(TITLE_SCENE_PATH)


func _exit_tree() -> void:
	_exiting = true
	_dragging_crank = false
	_fan_active = false
	for player: AudioStreamPlayer in _sfx_players.values():
		player.stop()


func _draw() -> void:
	var water := PackedVector2Array()
	var segments := ceili(_scenery_bounds.size.x / 3.0)
	for index: int in range(segments + 1):
		var x := lerpf(_scenery_bounds.position.x, _scenery_bounds.end.x, float(index) / segments)
		water.append(Vector2(x, _water_y(x)))
	var surface: PackedVector2Array = water.duplicate()
	# Continue beneath the frame lip so no antialiased seam is exposed.
	var floor_y := _scenery_bounds.end.y + 1.0
	water.append(Vector2(_scenery_bounds.end.x, floor_y))
	water.append(Vector2(_scenery_bounds.position.x, floor_y))
	draw_colored_polygon(water, Color("308c9b"))
	draw_polyline(surface, Color("9be1db"), 0.7, true)
	for platform: int in range(_platform_names.size()):
		if not _platform_visible(platform):
			continue
		var anchor := _platform_anchor(platform)
		var floating: bool = platform in _floating_platforms
		var width: float = 26.0 if floating else 28.0
		var height: float = 6.0 if floating else floor_y - anchor.y
		var rect := Rect2(anchor - Vector2(width * 0.5, 0.0), Vector2(width, height))
		draw_texture_rect(PLANK_TEXTURE if floating else STONE_TEXTURE, rect, false)


func _platform_visible(_platform: int) -> bool:
	return true


func _draw_guide() -> void:
	pass


func _draw_caption(center: Vector2, caption: String, selected: bool = false, canvas: Node2D = null) -> void:
	if canvas == null:
		canvas = _guide
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x / UI_RESOLUTION
	var color: Color = GOLD if selected else UI_THEME.CREAM
	var backing: StyleBoxFlat = _target_backing if selected else _label_backing
	canvas.draw_style_box(backing, Rect2(center - Vector2(width * 0.5 + 3.5, 5.0), Vector2(width + 7.0, 10.0)))
	canvas.draw_set_transform(center + Vector2(-width * 0.5, 2.0), 0.0, Vector2.ONE / UI_RESOLUTION)
	canvas.draw_string(font, Vector2.ZERO, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_keyhole(platform: int) -> void:
	var center := _platform_anchor(platform) + Vector2(0.0, 24.0)
	_guide.draw_circle(center, 3.3, GOLD, true, -1.0, true)
	_guide.draw_circle(center, 1.4, INK, true, -1.0, true)
	_guide.draw_rect(Rect2(center + Vector2(-0.8, 0.0), Vector2(1.6, 2.5)), INK)


func _make_label_backing(color: Color) -> StyleBoxFlat:
	var backing: StyleBoxFlat = UI_THEME.plaque(color, 0.25)
	backing.set_corner_radius_all(2)
	return backing


func _setup_sfx() -> void:
	# Reuse Level 1's synthesized click/fan/whirr/miss/win feedback without coupling
	# this scene to its rope, physics, highlights, or delayed assembly sequence.
	_register_sfx("crank", "click", 0.075)
	_register_sfx("fan_start", "fan", 0.42)
	_register_sfx("fan_whirr", "mechanical_whirr", 1.2)
	_register_sfx("miss", "miss", 0.48)
	_register_sfx("win", "win", 1.35)


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


func _play_sfx(player_name: String) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(player_name) as AudioStreamPlayer
	if player != null:
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
			"miss":
				frequency = lerpf(330.0, 125.0, progress)
				envelope = (1.0 - progress) * (1.0 - progress) * 0.68
				signal_value = sin(phase * TAU)
			"win":
				frequency = 523.25 if progress < 0.25 else (659.25 if progress < 0.5 else (783.99 if progress < 0.75 else 1046.5))
				envelope = minf(1.0, progress * 24.0) * (1.0 - progress * 0.72) * 0.62
				signal_value = sin(phase * TAU) * 0.8 + sin(phase * TAU * 2.0) * 0.2
		pcm.encode_s16(sample_index * 2, int(clampf(signal_value * envelope, -1.0, 1.0) * 32767.0))
		phase = fmod(phase + frequency / float(AUDIO_SAMPLE_RATE), 1.0)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream
