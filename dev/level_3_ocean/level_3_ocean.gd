extends Node2D
## Level 3: Ocean rules, two rocks and crank-driven light. All positions and reach checks use 360 x 200 units.

enum State { RESTING, HOPPING, STRANDED, COMPLETED }
enum Platform { START, LOG_1, LOG_2, ROCK_A, LOG_3, ROCK_B, GOAL }

const REFERENCE_SIZE: Vector2 = Vector2(360.0, 200.0)
const PLATFORM_X: Array[float] = [30.0, 90.0, 150.0, 190.0, 235.0, 275.0, 330.0]
const PLATFORM_NAMES: Array[String] = ["Start", "Log 1", "Log 2", "Rock A", "Log 3", "Rock B", "Goal"]
const CRANK_KNOB_LOCAL_POSITION: Vector2 = Vector2(576.0, 0.0)
const CRANK_HIT_RADIUS: float = 9.0
const FRAGMENT_OFFSET: Vector2 = Vector2(0.0, -7.5)
const AUDIO_SAMPLE_RATE: int = 22050
const UI_RESOLUTION: float = 6.0
const TITLE_SCENE_PATH: String = "res://Level/title_menu.tscn"

@export_group("Tide")
@export var initial_crank_angle: float = -PI * 0.5
@export_group("Hop")
@export_range(0.1, 2.0, 0.05) var hop_duration: float = 0.65
@export var max_hop_distance: float = 130.0
@export var min_height_difference: float = -26.0
@export var max_height_difference: float = 30.0
@export_group("Feedback")
@export_range(0.2, 5.0, 0.1) var feedback_duration: float = 1.5

@onready var _crank: Node2D = $Crank
@onready var _crank_handle: Node2D = $Crank/Handle
@onready var _fan_blades: AnimatedSprite2D = $Fan/Blades
@onready var _fragment: Sprite2D = $Fragment
@onready var _feedback: Label = $Feedback
@onready var _fire_button: Button = $FireButton

var _state: State = State.RESTING
var _current_platform: Platform = Platform.START
var _target_platform: int = -1
var _crank_angle: float = 0.0
var _elapsed_time: float = 0.0
var _hop_elapsed: float = 0.0
var _hop_start: Vector2 = Vector2.ZERO
var _hop_height: float = 0.0
var _feedback_remaining: float = 0.0
var _fan_remaining: float = 0.0
var _fan_active: bool = false
var _dragging_crank: bool = false
var _previous_crank_angle: float = 0.0
var _crank_angle_since_tick: float = 0.0
var _exiting: bool = false
var _presentation_locked: bool = false
var _sfx_players: Dictionary = {}
var _campaign_menu: CanvasLayer


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_prepare_controls()
	_setup_sfx()
	reset_level()
	_campaign_menu = preload("res://Level/campaign_menu.gd").new()
	_campaign_menu.room = self
	_campaign_menu.next_scene = "res://Level/ending.tscn"
	add_child(_campaign_menu)
	var navigation := preload("res://Level/night_navigation.gd").new()
	navigation.name = "NightNavigation"
	add_child(navigation)


func _prepare_controls() -> void:
	# Render text at display-sized resolution, while retaining reference-space
	# placement and input bounds under the uniformly scaled world.
	for child: Node in get_children():
		if child is Control:
			var control: Control = child as Control
			var reference_size: Vector2 = control.size
			var font_size: int = control.get_theme_font_size("font_size")
			control.add_theme_font_size_override("font_size", int(font_size * UI_RESOLUTION))
			control.scale = Vector2.ONE / UI_RESOLUTION
			control.size = reference_size * UI_RESOLUTION


func _fit_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if get_parent() is Control:
		viewport_size = (get_parent() as Control).size
	var factor: float = minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	scale = Vector2.ONE * factor
	position = (viewport_size - REFERENCE_SIZE * factor) * 0.5


func set_presentation_locked(locked: bool) -> void:
	_presentation_locked = locked
	if locked:
		_dragging_crank = false
	_fire_button.disabled = locked or _state == State.HOPPING or _state == State.COMPLETED
	($ResetButton as Button).disabled = locked


func _water_y(x: float) -> float:
	var cur: float = 0.5 + 0.5 * sin(_crank_angle)
	var water_base: float = 142.0 - 40.0 * cur
	return water_base + 4.0 * sin(0.035 * x - _elapsed_time * 2.0)


func _platform_anchor(platform: int) -> Vector2:
	var x: float = PLATFORM_X[platform]
	match platform:
		Platform.START:
			return Vector2(x, 150.0)
		Platform.ROCK_A, Platform.ROCK_B:
			return Vector2(x, 140.0)
		Platform.GOAL:
			return Vector2(x, 90.0)
	return Vector2(x, _water_y(x) - 6.0)


func _is_reachable(origin: Vector2, target: Vector2) -> bool:
	var difference: Vector2 = target - origin
	return difference.x > 0.0 and difference.x <= max_hop_distance \
		and difference.y >= min_height_difference and difference.y <= max_height_difference


func _find_target() -> int:
	var origin: Vector2 = _platform_anchor(_current_platform)
	for platform: int in range(_current_platform + 1, PLATFORM_X.size()):
		if _is_reachable(origin, _platform_anchor(platform)):
			return platform
	return -1


func fire_fan() -> void:
	if _exiting or _presentation_locked or _state == State.HOPPING or _state == State.COMPLETED:
		return
	_fan_remaining = 0.35
	_set_fan_active(true)
	_play_sfx("fan_start")
	if _state == State.STRANDED:
		return
	_target_platform = _find_target()
	if _target_platform < 0:
		_show_feedback("No platform within reach.")
		return
	_state = State.HOPPING
	_fan_remaining = hop_duration
	_hop_elapsed = 0.0
	_hop_start = _platform_anchor(_current_platform)
	_hop_height = 14.0 + (PLATFORM_X[_target_platform] - _hop_start.x) * 0.12
	_feedback.text = ""
	_feedback_remaining = 0.0
	_fire_button.disabled = true


func _process(delta: float) -> void:
	if _exiting:
		return
	_elapsed_time += delta
	if _feedback_remaining > 0.0:
		_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
		if _feedback_remaining == 0.0:
			_feedback.text = ""
	if _fan_remaining > 0.0:
		_fan_remaining = maxf(0.0, _fan_remaining - delta)
		if _fan_remaining == 0.0:
			_stop_fan()
	if _state == State.HOPPING:
		_hop_elapsed += delta
		var progress: float = clampf(_hop_elapsed / hop_duration, 0.0, 1.0)
		var destination: Vector2 = _platform_anchor(_target_platform)
		var anchor: Vector2 = _hop_start.lerp(destination, progress)
		anchor.y -= sin(progress * PI) * _hop_height
		_fragment.position = anchor + FRAGMENT_OFFSET
		if progress >= 1.0:
			_land()
	else:
		_fragment.position = _platform_anchor(_current_platform) + FRAGMENT_OFFSET
	_update_light()
	queue_redraw()


func _land() -> void:
	_fan_remaining = 0.0
	_stop_fan()
	_current_platform = _target_platform as Platform
	_target_platform = -1
	_state = State.RESTING
	_fire_button.disabled = _presentation_locked
	match _current_platform:
		Platform.ROCK_A, Platform.ROCK_B:
			_state = State.STRANDED
			_show_feedback("Stranded—reset to try again.", true)
			_play_sfx("miss")
		Platform.GOAL:
			_state = State.COMPLETED
			_fire_button.disabled = true
			_show_feedback("Delivered to the keyhole. Level complete!", true)
			_play_sfx("win")
			_dragging_crank = false
			_campaign_menu.show_menu.call_deferred(true)


func _show_feedback(message: String, persistent: bool = false) -> void:
	_feedback.text = message
	_feedback_remaining = 0.0 if persistent else feedback_duration


func reset_level() -> void:
	if is_instance_valid(_campaign_menu) and _campaign_menu.completed:
		_campaign_menu.resume()
		_campaign_menu.completed = false
	if _exiting:
		return
	_state = State.RESTING
	_current_platform = Platform.START
	_target_platform = -1
	_crank_angle = initial_crank_angle
	_crank_handle.rotation = _crank_angle
	_elapsed_time = 0.0
	_hop_elapsed = 0.0
	_hop_start = Vector2.ZERO
	_hop_height = 0.0
	_feedback_remaining = 0.0
	_feedback.text = ""
	_fan_remaining = 0.0
	_dragging_crank = false
	_previous_crank_angle = 0.0
	_crank_angle_since_tick = 0.0
	_fire_button.disabled = _presentation_locked
	_fragment.position = _platform_anchor(_current_platform) + FRAGMENT_OFFSET
	_fragment.rotation = 0.0
	_stop_fan()
	for player: AudioStreamPlayer in _sfx_players.values():
		player.stop()
	_update_light()
	queue_redraw()


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


func _input(event: InputEvent) -> void:
	# Release must be observed even when the pointer is over a GUI button.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging_crank = false


func _unhandled_input(event: InputEvent) -> void:
	if _exiting or _presentation_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				reset_level()
			KEY_SPACE:
				fire_fan()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var knob: Vector2 = to_local(_crank.to_global(CRANK_KNOB_LOCAL_POSITION.rotated(_crank_handle.rotation)))
		if pointer.distance_to(knob) <= CRANK_HIT_RADIUS:
			_dragging_crank = true
			_previous_crank_angle = (pointer - _crank.position).angle()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_crank:
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var offset: Vector2 = pointer - _crank.position
		if offset.length() < 3.0:
			return
		var angle: float = offset.angle()
		var angular_delta: float = wrapf(angle - _previous_crank_angle, -PI, PI)
		_previous_crank_angle = angle
		_crank_angle = wrapf(_crank_angle + angular_delta, -PI, PI)
		_crank_handle.rotation = _crank_angle
		_crank_angle_since_tick += absf(angular_delta)
		if _crank_angle_since_tick >= 0.34:
			_crank_angle_since_tick = fmod(_crank_angle_since_tick, 0.34)
			_play_sfx("crank")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging_crank = false


func _return_to_title() -> void:
	if _exiting:
		return
	_exiting = true
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _exit_tree() -> void:
	_exiting = true
	_dragging_crank = false
	_fan_active = false
	for player: AudioStreamPlayer in _sfx_players.values():
		player.stop()


func _draw() -> void:
	var water: PackedVector2Array = PackedVector2Array()
	for x: int in range(0, 361, 3):
		water.append(Vector2(float(x), _water_y(float(x))))
	var surface: PackedVector2Array = water.duplicate()
	water.append(Vector2(360.0, 169.0))
	water.append(Vector2(0.0, 169.0))
	draw_colored_polygon(water, Color("308c9b"))
	draw_polyline(surface, Color("9be1db"), 0.7, true)
	for platform: int in range(PLATFORM_X.size()):
		var anchor: Vector2 = _platform_anchor(platform)
		var floating: bool = platform in [Platform.LOG_1, Platform.LOG_2, Platform.LOG_3]
		var width: float = 28.0 if floating else (42.0 if platform == Platform.GOAL else 26.0)
		var height: float = 6.0 if floating else 169.0 - anchor.y
		var rect: Rect2 = Rect2(anchor - Vector2(width * 0.5, 0.0), Vector2(width, height))
		var color: Color = Color("d1a46a") if floating else Color("8996a2")
		if platform == Platform.GOAL:
			color = Color("d4c6a4")
		draw_rect(rect, color)
		draw_line(rect.position, rect.position + Vector2(width, 0.0), Color("f6e3b3"), 1.0, true)
		if floating:
			draw_line(rect.position + Vector2(3.0, 3.0), rect.end - Vector2(3.0, 3.0), Color("99734a"), 0.5)
	# A small keyhole remains a destination marker rather than a route hint.
	draw_circle(Vector2(330.0, 104.0), 3.0, Color("f7df99"))
	draw_circle(Vector2(330.0, 104.0), 1.5, Color("102b3b"))
	draw_rect(Rect2(329.0, 105.0, 2.0, 4.0), Color("102b3b"))


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


func _update_light() -> void:
	# Reference-space bounds; crank, tide and targeting stay unchanged.
	$SweepLight.position.x = lerpf(30.0, 330.0, 0.5 + 0.5 * sin(_crank_angle * 0.5))
