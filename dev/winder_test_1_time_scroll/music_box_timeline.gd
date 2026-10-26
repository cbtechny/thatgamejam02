extends Node2D

const PROGRESS_PER_REVOLUTION: float = 0.75
const LOW_PROGRESS_THRESHOLD: float = 0.35
const BACKGROUND_START_X: float = 6328.125
const BACKGROUND_TRAVEL_X: float = 10736.25
const BACKGROUND_HEIGHT_SCALE: float = 1.0546875

enum PlaybackPhase { REST, WINDING, FORWARD, REVERSE_IDLE }

@onready var _progress_bar: ProgressBar = $HUD/ProgressBar
@onready var _background: Sprite2D = $DayNightBackground
@onready var _winder_area: Area2D = $MusicBox/WinderTwoBlade/WinderHitArea
@onready var _forward_player: AudioStreamPlayer = $TGMTheme
@onready var _backward_player: AudioStreamPlayer = $BackwardsLoop

var _phase: PlaybackPhase = PlaybackPhase.REST
var _phase_before_winding: PlaybackPhase = PlaybackPhase.REST
var _timeline_progress: float = 0.0
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

	_set_timeline_progress(0.0)


func _process(_delta: float) -> void:
	if _phase == PlaybackPhase.FORWARD:
		var duration: float = _forward_duration()
		if duration > 0.0 and _forward_player.playing:
			_set_timeline_progress(1.0 - _forward_player.get_playback_position() / duration)

	_update_progress_color()


func _on_winding_started() -> void:
	_phase_before_winding = _phase
	_wound_during_drag = false

	if _phase == PlaybackPhase.FORWARD:
		var duration: float = _forward_duration()
		if duration > 0.0:
			_set_timeline_progress(1.0 - _forward_player.get_playback_position() / duration)
		_forward_player.stop()

	_backward_player.stream_paused = true
	_phase = PlaybackPhase.WINDING
	_update_progress_color()


func _on_crank_delta(revolutions: float) -> void:
	if _phase != PlaybackPhase.WINDING or is_zero_approx(revolutions):
		return

	var previous_progress: float = _timeline_progress
	_set_timeline_progress(_timeline_progress + revolutions * PROGRESS_PER_REVOLUTION)
	if not is_equal_approx(_timeline_progress, previous_progress):
		_wound_during_drag = true


func _on_winding_released() -> void:
	if _phase != PlaybackPhase.WINDING:
		return

	if not _wound_during_drag:
		_resume_previous_phase()
		return

	if _timeline_progress > 0.0:
		_start_forward_playback()
	else:
		_begin_reverse_idle()


func _resume_previous_phase() -> void:
	match _phase_before_winding:
		PlaybackPhase.FORWARD:
			_start_forward_playback()
		PlaybackPhase.REVERSE_IDLE:
			_phase = PlaybackPhase.REVERSE_IDLE
			_backward_player.stream_paused = false
			_forward_player.stop()
			_backward_player.stop()
		PlaybackPhase.REST:
			_phase = PlaybackPhase.REST
			_backward_player.stream_paused = false
			_backward_player.stop()


func _start_forward_playback() -> void:
	var duration: float = _forward_duration()
	if duration <= 0.0 or _timeline_progress <= 0.0:
		_begin_reverse_idle()
		return

	_phase = PlaybackPhase.FORWARD
	_backward_player.stop()
	_backward_player.stream_paused = false
	_forward_player.play((1.0 - _timeline_progress) * duration)


func _begin_reverse_idle() -> void:
	_forward_player.stop()
	_phase = PlaybackPhase.REVERSE_IDLE
	_set_timeline_progress(0.0)
	_backward_player.stream_paused = false
	_backward_player.stop()


func _on_forward_finished() -> void:
	if _phase == PlaybackPhase.FORWARD:
		_begin_reverse_idle()


func _forward_duration() -> float:
	if _forward_player.stream == null:
		return 0.0
	return _forward_player.stream.get_length()


func _set_timeline_progress(value: float) -> void:
	_timeline_progress = clampf(value, 0.0, 1.0)
	_progress_bar.value = _timeline_progress * 100.0
	if _phase != PlaybackPhase.WINDING:
		_background.position.x = BACKGROUND_START_X - BACKGROUND_TRAVEL_X * _timeline_progress


func _update_progress_color() -> void:
	if _phase == PlaybackPhase.REVERSE_IDLE:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
		_progress_fill.bg_color = Color(0.72, 0.02, 0.03, 1.0).lerp(Color(1.0, 0.22, 0.22, 1.0), pulse)
	else:
		_progress_fill.bg_color = Color(0.10, 0.72, 0.20, 1.0)
