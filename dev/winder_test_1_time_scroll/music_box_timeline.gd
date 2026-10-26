extends Node2D

const PROGRESS_PER_REVOLUTION: float = 0.75
const BACKGROUND_START_X: float = 6328.125
const BACKGROUND_TRAVEL_X: float = 10736.25

enum PlaybackPhase { REST, WINDING, FORWARD, RETURN }

@onready var _progress_bar: ProgressBar = $HUD/ProgressBar
@onready var _background: Sprite2D = $DayNightBackground
@onready var _winder_area: Area2D = $MusicBox/WinderTwoBlade/WinderHitArea
@onready var _forward_player: AudioStreamPlayer = $TGMTheme
@onready var _backward_player: AudioStreamPlayer = $BackwardsLoop

var _phase: PlaybackPhase = PlaybackPhase.REST
var _phase_before_winding: PlaybackPhase = PlaybackPhase.REST
var _coin_balance: float = 0.0
var _background_progress: float = 0.0
var _wound_during_drag: bool = false
var _progress_fill: StyleBoxFlat


func _ready() -> void:
	var fill_style: StyleBox = _progress_bar.get_theme_stylebox("fill")
	_progress_fill = fill_style.duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override("fill", _progress_fill)

	var source_loop: AudioStreamOggVorbis = _backward_player.stream as AudioStreamOggVorbis
	if source_loop != null:
		var looped_stream: AudioStreamOggVorbis = source_loop.duplicate() as AudioStreamOggVorbis
		looped_stream.loop = true
		_backward_player.stream = looped_stream

	_winder_area.winding_started.connect(_on_winding_started)
	_winder_area.crank_delta.connect(_on_crank_delta)
	_winder_area.winding_released.connect(_on_winding_released)
	_forward_player.finished.connect(_on_forward_finished)

	_set_coin_balance(0.0)
	_set_background_progress(0.0)


func _process(delta: float) -> void:
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


func _on_winding_started() -> void:
	_phase_before_winding = _phase
	_wound_during_drag = false

	if _phase_before_winding == PlaybackPhase.FORWARD:
		_forward_player.stream_paused = true
	elif _phase_before_winding == PlaybackPhase.RETURN:
		_backward_player.stream_paused = true

	_phase = PlaybackPhase.WINDING
	_update_progress_color()


func _on_crank_delta(revolutions: float) -> void:
	if _phase != PlaybackPhase.WINDING or is_zero_approx(revolutions):
		return

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


func _start_forward_playback() -> void:
	if _forward_duration() <= 0.0 or _coin_balance <= 0.0:
		_begin_return()
		return

	_phase = PlaybackPhase.FORWARD
	_backward_player.stream_paused = false
	_backward_player.stop()
	_forward_player.stream_paused = false
	_forward_player.play(0.0)


func _resume_forward_playback() -> void:
	_phase = PlaybackPhase.FORWARD
	_backward_player.stream_paused = false
	_backward_player.stop()
	_forward_player.stream_paused = false


func _begin_return() -> void:
	_forward_player.stop()
	_backward_player.stream_paused = false
	_phase = PlaybackPhase.RETURN
	if _backward_player.stream != null and not _backward_player.playing:
		_backward_player.play()


func _resume_return() -> void:
	_phase = PlaybackPhase.RETURN
	_forward_player.stop()
	_backward_player.stream_paused = false


func _finish_return() -> void:
	_set_background_progress(0.0)
	_phase = PlaybackPhase.REST
	_forward_player.stop()
	_backward_player.stream_paused = false
	_backward_player.stop()


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
