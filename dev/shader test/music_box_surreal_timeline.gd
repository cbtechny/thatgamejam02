extends Node2D

const PROGRESS_PER_REVOLUTION: float = 0.75
const BACKGROUND_START_X: float = 6328.125
const BACKGROUND_TRAVEL_X: float = 10736.25
const WINDER_REVERSE_RADIANS_PER_SECOND: float = TAU
const WINDER_FORWARD_PLAYBACK_SPEED_SCALE: float = 0.25
const WINDER_REST_ROTATION: float = 1.5707964
const SHADER_TRANSITION_RATE: float = 2.5

enum PlaybackPhase { REST, WINDING, FORWARD, RETURN }

@onready var _progress_bar: ProgressBar = $HUD/ProgressBar
@onready var _background: Sprite2D = $DayNightBackground
@onready var _winder_area: Area2D = $MusicBox/WinderTwoBlade/WinderHitArea
@onready var _forward_player: AudioStreamPlayer = $TGMTheme
@onready var _backward_player: AudioStreamPlayer = $BackwardsLoop
@onready var _crank_player: AudioStreamPlayer = $CrankSound
@onready var _winder: Sprite2D = $MusicBox/WinderTwoBlade
@onready var _shader_material: ShaderMaterial = $SurrealMarbledBackground.material as ShaderMaterial

var _phase: PlaybackPhase = PlaybackPhase.REST
var _phase_before_winding: PlaybackPhase = PlaybackPhase.REST
var _coin_balance: float = 0.0
var _background_progress: float = 0.0
var _wound_during_drag: bool = false
var _progress_fill: StyleBoxFlat
var _shader_time: float = 0.0
var _shader_motion_multiplier: float = 1.0
var _shader_motion_intensity: float = 0.0
var _shader_return_blend: float = 0.0
var _shader_forward_blend: float = 0.0
var _shader_idle_speed: float = 0.035
var _shader_forward_speed_multiplier: float = 5.0


func _ready() -> void:
	# Capture the material's base speed before the playback phase drives it.
	_shader_idle_speed = float(_shader_material.get_shader_parameter("motion_speed"))
	_shader_forward_speed_multiplier = float(_shader_material.get_shader_parameter("forward_speed_scale"))
	_update_shader_response(0.0)

	var fill_style: StyleBox = _progress_bar.get_theme_stylebox("fill")
	_progress_fill = fill_style.duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override("fill", _progress_fill)

	var source_loop: AudioStreamOggVorbis = _backward_player.stream as AudioStreamOggVorbis
	if source_loop != null:
		var looped_stream: AudioStreamOggVorbis = source_loop.duplicate() as AudioStreamOggVorbis
		looped_stream.loop = true
		_backward_player.stream = looped_stream

	var crank_stream: AudioStreamOggVorbis = _crank_player.stream as AudioStreamOggVorbis
	if crank_stream != null:
		var looped_crank_stream: AudioStreamOggVorbis = crank_stream.duplicate() as AudioStreamOggVorbis
		looped_crank_stream.loop = true
		_crank_player.stream = looped_crank_stream

	_winder_area.winding_started.connect(_on_winding_started)
	_winder_area.crank_delta.connect(_on_crank_delta)
	_winder_area.winding_released.connect(_on_winding_released)
	_forward_player.finished.connect(_on_forward_finished)

	_set_coin_balance(0.0)
	_set_background_progress(0.0)


func _process(delta: float) -> void:
	_update_shader_response(delta)
	_update_winder_animation(delta)
	var duration: float = _forward_duration()
	if duration <= 0.0:
		_update_progress_color()
		return

	match _phase:
		PlaybackPhase.FORWARD:
			if _forward_player.playing and not _forward_player.stream_paused:
				_set_coin_balance(_coin_balance - delta / duration)
				_set_background_progress(_background_progress + delta / duration)
				if _coin_balance <= 0.0:
					_begin_return()
		PlaybackPhase.RETURN:
			if _background_progress > 0.0:
				_set_background_progress(_background_progress - delta / duration)
			if _background_progress <= 0.0:
				_finish_return()

	_update_progress_color()


func _update_shader_response(delta: float) -> void:
	# Forward and return both animate quickly; winding eases back to blue idle.
	var is_playing_motion: bool = _phase == PlaybackPhase.FORWARD or _phase == PlaybackPhase.RETURN
	var target_motion_multiplier: float = _shader_forward_speed_multiplier if is_playing_motion else 1.0
	var target_motion_intensity: float = 1.0 if is_playing_motion else 0.0
	var target_return_blend: float = 1.0 if _phase == PlaybackPhase.RETURN else 0.0
	var target_forward_blend: float = 1.0 if _phase == PlaybackPhase.FORWARD else 0.0
	var transition_weight: float = 1.0 - exp(-SHADER_TRANSITION_RATE * delta)
	_shader_motion_multiplier = lerpf(_shader_motion_multiplier, target_motion_multiplier, transition_weight)
	_shader_motion_intensity = lerpf(_shader_motion_intensity, target_motion_intensity, transition_weight)
	_shader_return_blend = lerpf(_shader_return_blend, target_return_blend, transition_weight)
	_shader_forward_blend = lerpf(_shader_forward_blend, target_forward_blend, transition_weight)
	_shader_time += delta * _shader_idle_speed * _shader_motion_multiplier
	_shader_material.set_shader_parameter("motion_speed", _shader_idle_speed * _shader_motion_multiplier)
	_shader_material.set_shader_parameter("animation_time", _shader_time)
	_shader_material.set_shader_parameter("motion_intensity", _shader_motion_intensity)
	_shader_material.set_shader_parameter("return_blend", _shader_return_blend)
	_shader_material.set_shader_parameter("forward_blend", _shader_forward_blend)


func _on_winding_started() -> void:
	_phase_before_winding = _phase
	_wound_during_drag = false

	if _phase_before_winding == PlaybackPhase.FORWARD:
		_forward_player.stream_paused = true
	elif _phase_before_winding == PlaybackPhase.RETURN:
		_backward_player.stream_paused = true
		_crank_player.stream_paused = true

	_phase = PlaybackPhase.WINDING
	_update_progress_color()


func _on_crank_delta(revolutions: float) -> void:
	if _phase != PlaybackPhase.WINDING or is_zero_approx(revolutions):
		return

	_crank_player.stream_paused = false
	if not _crank_player.playing:
		_crank_player.play()

	var previous_balance: float = _coin_balance
	_set_coin_balance(_coin_balance + revolutions * PROGRESS_PER_REVOLUTION)
	if not is_equal_approx(_coin_balance, previous_balance):
		_wound_during_drag = true


func _on_winding_released() -> void:
	if _phase != PlaybackPhase.WINDING:
		return

	if not _wound_during_drag:
		_resume_previous_phase()
		return

	match _phase_before_winding:
		PlaybackPhase.FORWARD:
			if _coin_balance > 0.0:
				_resume_forward_playback()
			else:
				_begin_return()
		PlaybackPhase.RETURN:
			if _coin_balance > 0.0:
				_start_forward_playback()
			else:
				_resume_return()
		PlaybackPhase.REST:
			if _coin_balance > 0.0:
				_start_forward_playback()
			else:
				_phase = PlaybackPhase.REST
				_backward_player.stream_paused = false
				_backward_player.stop()
				_reset_reverse_feedback()

	_update_progress_color()


func _resume_previous_phase() -> void:
	match _phase_before_winding:
		PlaybackPhase.FORWARD:
			_resume_forward_playback()
		PlaybackPhase.RETURN:
			_resume_return()
		PlaybackPhase.REST:
			_phase = PlaybackPhase.REST
			_forward_player.stop()
			_backward_player.stream_paused = false
			_backward_player.stop()
			_reset_reverse_feedback()


func _start_forward_playback() -> void:
	if _forward_duration() <= 0.0 or _coin_balance <= 0.0:
		_begin_return()
		return

	_phase = PlaybackPhase.FORWARD
	_reset_reverse_feedback()
	_backward_player.stream_paused = false
	_backward_player.stop()
	_forward_player.stream_paused = false
	_forward_player.play(0.0)


func _resume_forward_playback() -> void:
	_phase = PlaybackPhase.FORWARD
	_reset_reverse_feedback()
	_backward_player.stream_paused = false
	_backward_player.stop()
	_forward_player.stream_paused = false


func _begin_return() -> void:
	_forward_player.stop()
	_backward_player.stream_paused = false
	_phase = PlaybackPhase.RETURN
	_start_reverse_feedback()
	if _backward_player.stream != null and not _backward_player.playing:
		_backward_player.play()


func _resume_return() -> void:
	_phase = PlaybackPhase.RETURN
	_forward_player.stop()
	_backward_player.stream_paused = false
	_crank_player.stream_paused = false
	_start_reverse_feedback()


func _finish_return() -> void:
	_set_background_progress(0.0)
	_phase = PlaybackPhase.REST
	_forward_player.stop()
	_backward_player.stream_paused = false
	_backward_player.stop()
	_reset_reverse_feedback()


func _on_forward_finished() -> void:
	if _phase == PlaybackPhase.FORWARD:
		if _coin_balance > 0.0:
			_forward_player.play(0.0)
		else:
			_begin_return()


func _forward_duration() -> float:
	if _forward_player.stream == null:
		return 0.0
	return _forward_player.stream.get_length()


func _set_coin_balance(value: float) -> void:
	_coin_balance = clampf(value, 0.0, 1.0)
	_progress_bar.value = _coin_balance * 100.0


func _set_background_progress(value: float) -> void:
	_background_progress = clampf(value, 0.0, 1.0)
	_background.position.x = BACKGROUND_START_X - BACKGROUND_TRAVEL_X * _background_progress


func _update_progress_color() -> void:
	if _phase == PlaybackPhase.RETURN:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
		_progress_fill.bg_color = Color(0.72, 0.02, 0.03, 1.0).lerp(Color(1.0, 0.22, 0.22, 1.0), pulse)
	else:
		_progress_fill.bg_color = Color(0.10, 0.72, 0.20, 1.0)


func _start_reverse_feedback() -> void:
	_winder.rotation = WINDER_REST_ROTATION
	_crank_player.stream_paused = false
	if not _crank_player.playing:
		_crank_player.play()

func _reset_reverse_feedback() -> void:
	_crank_player.stream_paused = false
	_crank_player.stop()
	_winder.rotation = WINDER_REST_ROTATION

func _update_winder_animation(delta: float) -> void:
	match _phase:
		PlaybackPhase.FORWARD:
			if not _forward_player.playing or _forward_player.stream_paused:
				return
			_winder.rotation -= WINDER_REVERSE_RADIANS_PER_SECOND * WINDER_FORWARD_PLAYBACK_SPEED_SCALE * delta
			_ensure_crank_sound_playing()
		PlaybackPhase.RETURN:
			_winder.rotation -= WINDER_REVERSE_RADIANS_PER_SECOND * delta
			_ensure_crank_sound_playing()


func _ensure_crank_sound_playing() -> void:
	_crank_player.stream_paused = false
	if not _crank_player.playing:
		_crank_player.play()
