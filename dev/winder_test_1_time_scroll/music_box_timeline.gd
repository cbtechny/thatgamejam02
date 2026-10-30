class_name MusicBoxTimeline
extends Node2D
## Audio and visual presentation for the winding controller's fixed physics clock.

const BACKGROUND_START_X: float = 6328.125
const BACKGROUND_TRAVEL_X: float = 10736.25

enum PlaybackPhase { REST, WINDING, FORWARD, HOLD, RETURN, COOLDOWN }

@export var object_controller: WindingObjectController

@onready var _progress_bar: ProgressBar = $HUD/ProgressBar
@onready var _background: Sprite2D = $DayNightBackground
@onready var _winder_area: WinderDrag = $MusicBox/WinderTwoBlade/WinderHitArea
@onready var _forward_player: AudioStreamPlayer = $TGMTheme
@onready var _backward_player: AudioStreamPlayer = $BackwardsLoop
@onready var _crank_player: AudioStreamPlayer = $CrankSound
@onready var _hint: Label = $HUD/Hint

var _phase: PlaybackPhase = PlaybackPhase.REST
var _background_progress: float = 0.0
var _progress_fill: StyleBoxFlat
var _background_return_active: bool = false
var _background_return_start: float = 0.0
var _rest_elapsed: float = 0.0


func _ready() -> void:
	_progress_fill = _progress_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override("fill", _progress_fill)
	_configure_loop(_backward_player)
	_configure_loop(_crank_player)
	_set_background_progress(0.0)
	if not is_instance_valid(object_controller):
		_winder_area.set_input_enabled(false)
		push_error("Assign Object Controller on the music-box timeline.")
		return

	_winder_area.winding_started.connect(_on_winding_started)
	_winder_area.crank_delta.connect(_on_crank_delta)
	_winder_area.winding_released.connect(_on_winding_released)
	_forward_player.finished.connect(_on_forward_finished)
	object_controller.phase_changed.connect(_on_phase_changed)
	object_controller.winding_amount_changed.connect(_on_winding_amount_changed)
	object_controller.motion_advanced.connect(_on_motion_advanced)
	object_controller.rest_advanced.connect(_on_rest_advanced)
	object_controller.reset_requested.connect(_on_reset_requested)
	_on_winding_amount_changed(object_controller.get_wound_fraction())
	_on_phase_changed(object_controller.phase)


func _process(_delta: float) -> void:
	_update_progress_color()
	_update_hint()


func _on_winding_started() -> void:
	if not object_controller.begin_winding():
		_winder_area.set_input_enabled(false)


func _on_crank_delta(_revolutions: float) -> void:
	if object_controller.phase != WindingObjectController.MotionPhase.WINDING:
		return
	object_controller.set_winding_amount(_winder_area.get_winding_fraction())
	_ensure_crank_sound_playing()


func _on_winding_released() -> void:
	object_controller.release_winding()


func _on_winding_amount_changed(fraction: float) -> void:
	# The same remaining charge drives both the actual rotation and the energy bar.
	_winder_area.set_winding_fraction(fraction)
	_progress_bar.value = fraction * 100.0


func _on_phase_changed(phase: WindingObjectController.MotionPhase) -> void:
	_winder_area.set_input_enabled(phase == WindingObjectController.MotionPhase.IDLE or phase == WindingObjectController.MotionPhase.WINDING)
	match phase:
		WindingObjectController.MotionPhase.IDLE:
			_phase = PlaybackPhase.REST
			_stop_audio()
		WindingObjectController.MotionPhase.WINDING:
			_phase = PlaybackPhase.WINDING
			_background_return_active = false
			_stop_audio()
		WindingObjectController.MotionPhase.MOVING:
			_phase = PlaybackPhase.FORWARD
			_background_return_active = false
			_backward_player.stop()
			_forward_player.play(0.0)
			_ensure_crank_sound_playing()
		WindingObjectController.MotionPhase.COOLDOWN:
			_stop_audio()
			_rest_elapsed = 0.0
			_background_return_start = _background_progress
			_background_return_active = object_controller.stop_behavior == WindingObjectController.StopBehavior.RETURN_TO_START
			_phase = PlaybackPhase.HOLD if _background_return_active else PlaybackPhase.COOLDOWN
		WindingObjectController.MotionPhase.FROZEN:
			_phase = PlaybackPhase.REST
			_background_return_active = false
			_stop_audio()
	_update_hint()


func _on_motion_advanced(path_fraction: float) -> void:
	_set_background_progress(_background_progress + path_fraction)


func _on_rest_advanced(delta: float) -> void:
	if not _background_return_active:
		return
	_rest_elapsed += delta
	if _rest_elapsed < object_controller.hold_duration:
		return
	if _phase != PlaybackPhase.RETURN:
		_phase = PlaybackPhase.RETURN
		_backward_player.play()
	var return_fraction: float = clampf((_rest_elapsed - object_controller.hold_duration) / maxf(object_controller.return_duration, 0.01), 0.0, 1.0)
	_set_background_progress(_background_return_start * (1.0 - return_fraction))
	if return_fraction >= 1.0:
		_background_return_active = false
		_backward_player.stop()
		_phase = PlaybackPhase.REST if object_controller.phase == WindingObjectController.MotionPhase.IDLE else PlaybackPhase.COOLDOWN


func _on_reset_requested() -> void:
	_background_return_active = false
	_rest_elapsed = 0.0
	_set_background_progress(0.0)
	_on_winding_amount_changed(0.0)
	_on_phase_changed(object_controller.phase)


func _on_forward_finished() -> void:
	if object_controller.phase == WindingObjectController.MotionPhase.MOVING:
		_forward_player.play(0.0)


func _set_background_progress(value: float) -> void:
	_background_progress = clampf(value, 0.0, 1.0)
	_background.position.x = BACKGROUND_START_X - BACKGROUND_TRAVEL_X * _background_progress


func _update_progress_color() -> void:
	if _progress_fill == null:
		return
	if _phase == PlaybackPhase.RETURN:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008)
		_progress_fill.bg_color = Color(0.72, 0.02, 0.03).lerp(Color(1.0, 0.22, 0.22), pulse)
	else:
		_progress_fill.bg_color = Color(0.10, 0.72, 0.20)


func _update_hint() -> void:
	if not is_instance_valid(object_controller):
		return
	var degrees: float = object_controller.get_wound_fraction() * WinderDrag.MAX_WINDING_DEGREES
	match object_controller.phase:
		WindingObjectController.MotionPhase.MOVING:
			_hint.text = "UNWINDING  %d / 270 DEG" % roundi(degrees)
		WindingObjectController.MotionPhase.COOLDOWN:
			_hint.text = "READY IN %.1f S" % object_controller.get_cooldown_remaining()
		WindingObjectController.MotionPhase.FROZEN:
			_hint.text = "COMPLETE"
		_:
			_hint.text = "DRAG CLOCKWISE  %d / 270 DEG" % roundi(degrees)


func _stop_audio() -> void:
	_forward_player.stop()
	_backward_player.stop()
	_crank_player.stop()


func _ensure_crank_sound_playing() -> void:
	if not _crank_player.playing:
		_crank_player.play()


func _configure_loop(player: AudioStreamPlayer) -> void:
	var stream: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
	if stream != null:
		var looped: AudioStreamOggVorbis = stream.duplicate() as AudioStreamOggVorbis
		looped.loop = true
		player.stream = looped
