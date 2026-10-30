class_name WindingObjectController
extends Node
## One winding key owns the clock and normalized travel for its assigned objects.

signal phase_changed(phase: MotionPhase)
signal winding_amount_changed(fraction: float)
signal motion_advanced(path_fraction: float)
signal rest_advanced(delta: float)
signal reset_requested
signal freeze_requested

enum MotionPhase { IDLE, WINDING, MOVING, COOLDOWN, FROZEN }
enum StopBehavior { RETURN_TO_START, KEEP_POSITION }

const INPUT_COOLDOWN: float = 2.0
const TIME_EPSILON: float = 0.0000001
const MAX_WINDING_DEGREES: float = 270.0

@export var stop_behavior: StopBehavior = StopBehavior.RETURN_TO_START
## Time to unwind a full 270-degree charge. A half charge takes half this time.
@export_range(0.1, 30.0, 0.1, "or_greater", "suffix:s") var full_unwind_duration: float = 4.0
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var hold_duration: float = 1.5
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:s") var return_duration: float = 0.5

var phase: MotionPhase = MotionPhase.IDLE

var _wound_fraction: float = 0.0
var _cooldown_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	var remaining: float = delta
	# Split ticks at phase boundaries so hold, return, and cooldown start exactly
	# when the key reaches zero, regardless of the released winding amount.
	while remaining > TIME_EPSILON:
		match phase:
			MotionPhase.MOVING:
				var duration: float = maxf(full_unwind_duration, 0.1)
				var step: float = minf(remaining, _wound_fraction * duration)
				var fraction: float = minf(step / duration, _wound_fraction)
				motion_advanced.emit(fraction)
				_set_wound_fraction(_wound_fraction - fraction)
				remaining -= step
				if _wound_fraction <= TIME_EPSILON:
					_set_wound_fraction(0.0)
					_cooldown_remaining = INPUT_COOLDOWN
					_set_phase(MotionPhase.COOLDOWN)
			MotionPhase.COOLDOWN:
				var step: float = minf(remaining, _cooldown_remaining)
				_cooldown_remaining = maxf(_cooldown_remaining - step, 0.0)
				rest_advanced.emit(step)
				remaining -= step
				if _cooldown_remaining <= TIME_EPSILON:
					_cooldown_remaining = 0.0
					_set_phase(MotionPhase.IDLE)
			MotionPhase.IDLE:
				# A return delayed by an obstacle can outlast the input cooldown.
				rest_advanced.emit(remaining)
				return
			_:
				return


func begin_winding() -> bool:
	if phase != MotionPhase.IDLE:
		return false
	_set_phase(MotionPhase.WINDING)
	return true


func set_winding_amount(fraction: float) -> void:
	if phase == MotionPhase.WINDING:
		_set_wound_fraction(fraction)


func release_winding() -> void:
	if phase != MotionPhase.WINDING:
		return
	_set_phase(MotionPhase.MOVING if _wound_fraction > 0.0 else MotionPhase.IDLE)


## Sandbox or scripted input. Interactive winding uses begin/set/release instead.
func start_motion(fraction: float = 1.0) -> bool:
	if not begin_winding():
		return false
	set_winding_amount(fraction)
	release_winding()
	return true


func get_wound_fraction() -> float:
	return _wound_fraction


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func reset_objects() -> void:
	_cooldown_remaining = 0.0
	_set_wound_fraction(0.0)
	_set_phase(MotionPhase.IDLE)
	reset_requested.emit()


func freeze_objects() -> void:
	_set_phase(MotionPhase.FROZEN)
	freeze_requested.emit()


func _set_wound_fraction(value: float) -> void:
	var fraction: float = clampf(value, 0.0, 1.0)
	if fraction == _wound_fraction:
		return
	_wound_fraction = fraction
	winding_amount_changed.emit(fraction)


func _set_phase(value: MotionPhase) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit(phase)
