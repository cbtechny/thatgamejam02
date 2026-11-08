extends "res://Level/ocean_room.gd"
## A fixed fan shot. The tide moves decks vertically; their moorings run on time.

const SHOT := Vector2(76.0, -12.0)
const LANDING_X: float = 12.0
const LANDING_Y: float = 8.0
# A forgiving finish after the timed crossing; earlier decks keep their tolerances.
const KEYHOLE_LANDING_X: float = 24.0
const KEYHOLE_LANDING_Y: float = 18.0
const FAN_OFFSET := Vector2(-9.5, -8.0)
const WIND_BURST_DURATION: float = 0.24

var _platform_fans: Array[AnimatedSprite2D]
var _touchdown_time: float = 0.0


func _ready() -> void:
	for blades: AnimatedSprite2D in _platform_fans:
		blades.stop()
		blades.animation = &"idle"
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if not _presentation_locked and not _exiting:
		_position_fans()


func _position_fans() -> void:
	for platform: int in range(_platform_fans.size()):
		var blades: AnimatedSprite2D = _platform_fans[platform]
		var fan := blades.get_parent() as Node2D
		fan.position = _platform_anchor(platform) + FAN_OFFSET - fan.transform.basis_xform(blades.position)


func _deck_position(platform: int) -> Vector2:
	return _deck_at(platform, _elapsed_time)


func _deck_at(_platform: int, _time: float) -> Vector2:
	return Vector2.ZERO


func _prepare_launch() -> void:
	_fan_blades = _platform_fans[_current_platform]
	# Start from the drawn fragment, but aim from the stable deck height so
	# surface bob does not change the launch tolerance.
	_hop_end = _deck_position(_current_platform) + SHOT + FRAGMENT_OFFSET
	var deck_y := _landing_point(_current_platform + 1, _elapsed_time).y
	var drop := deck_y - _hop_end.y
	if drop > LANDING_Y:
		_flight_duration += drop / _descent_speed()
	_touchdown_time = _elapsed_time + _flight_duration


func _descent_speed() -> float:
	return (_hop_end.y - _hop_start.y + PI * HOP_HEIGHT) / hop_duration


func _hop_point(progress: float) -> Vector2:
	if progress <= 1.0:
		return super._hop_point(progress)
	return _hop_end + Vector2(0.0, (progress - 1.0) * hop_duration * _descent_speed())


func _resolve_landing() -> int:
	var next: int = _current_platform + 1
	var error := _landing_point(next, _touchdown_time) - _fragment.position
	var keyhole: bool = next == _platform_names.size() - 1
	var tolerance_x: float = KEYHOLE_LANDING_X if keyhole else LANDING_X
	var tolerance_y: float = KEYHOLE_LANDING_Y if keyhole else LANDING_Y
	if absf(error.x) <= tolerance_x and absf(error.y) <= tolerance_y:
		return next
	return -1


func _update_mechanisms() -> void:
	_position_fans()


func _hint() -> String:
	return "Turn the crank. Time the jump."


func _draw() -> void:
	super._draw()
	for platform: int in range(_platform_fans.size()):
		var foot := _platform_anchor(platform) + Vector2(-10.0, 1.0)
		draw_line(foot, foot + Vector2(-3.0, -7.0), Color("735139"), 2.4, true)
		draw_line(foot - Vector2(2.0, 0.0), foot + Vector2(2.0, 0.0), Color("bc915d"), 1.4, true)


func _draw_guide() -> void:
	_draw_keyhole(_platform_names.size() - 1)
	if _state == State.HOPPING and _hop_elapsed < WIND_BURST_DURATION:
		_draw_wind_burst()
	if _state != State.RESTING or _presentation_locked:
		return
	var origin := _platform_anchor(_current_platform) + FRAGMENT_OFFSET
	var end := _deck_position(_current_platform) + SHOT + FRAGMENT_OFFSET
	for index: int in range(7):
		var fade := float(index) / 6.0
		var progress := lerpf(0.075, 0.75, fade)
		var point := origin.lerp(end, progress)
		point.y -= sin(progress * PI) * HOP_HEIGHT
		_guide.draw_circle(point, lerpf(1.1, 0.7, fade), Color(GOLD, lerpf(0.82, 0.32, fade)), true, -1.0, true)


func _draw_wind_burst() -> void:
	var fan := _fan_blades.get_parent() as Node2D
	var direction := Vector2.from_angle(fan.rotation)
	var perpendicular := direction.orthogonal()
	var progress := _hop_elapsed / WIND_BURST_DURATION
	var origin := _platform_anchor(_current_platform) + FAN_OFFSET + direction * lerpf(3.0, 17.0, progress)
	for strand: int in range(-1, 2):
		var start := origin + perpendicular * (float(strand) * 2.3) - direction * absf(strand) * 2.0
		var end := start + direction * (7.0 - absf(strand) * 2.0)
		_guide.draw_line(start, end, Color("e3f6ee", (1.0 - progress) * 0.8), 0.75, true)


func _landing_point(platform: int, time: float) -> Vector2:
	var offset: Vector2 = KEYHOLE_OFFSET if platform == _platform_names.size() - 1 else FRAGMENT_OFFSET
	return _deck_at(platform, time) + offset


func _resting_fragment_position(platform: int) -> Vector2:
	if platform == _platform_names.size() - 1:
		return _keyhole_position(platform)
	return super._resting_fragment_position(platform)
