extends "res://Level/tidal_ferry_room.gd"

enum Platform { START, LOG_1, ROCK, LOG_2, GOAL }


func _ready() -> void:
	_middle_fragment_platform = Platform.ROCK
	_platform_names = ["Shore", "Ferry I", "Pier", "Ferry II", "Keyhole"]
	_floating_platforms = [Platform.LOG_1, Platform.LOG_2]
	_platform_fans = [$Fan/Blades, $FanFerryI/Blades, $FanPier/Blades, $FanFerryII/Blades]
	_next_scene = "res://dev/level_3_ocean/level_3_ocean.tscn"
	super._ready()


func _deck_at(platform: int, time: float) -> Vector2:
	match platform:
		Platform.START:
			return Vector2(28.0, 150.0)
		Platform.LOG_1:
			return Vector2(104.5 + 29.5 * cos(time * TAU / 5.4), _water_level() - 6.0)
		Platform.ROCK:
			return Vector2(201.0, 111.0)
		Platform.LOG_2:
			return Vector2(261.5 - 27.5 * cos(time * TAU / 6.2 + 0.35), _water_level() - 6.0)
		Platform.GOAL:
			return Vector2(330.0, 85.0)
	return Vector2.ZERO

func _pier_height_reachable() -> bool:
	var shot_y := _deck_position(Platform.LOG_1).y + SHOT.y
	return _deck_position(Platform.ROCK).y >= shot_y - LANDING_Y


func _can_launch() -> bool:
	return _current_platform != Platform.LOG_1 or _pier_height_reachable()


func _hint() -> String:
	if _current_platform == Platform.LOG_1:
		if not _pier_height_reachable():
			return "Raise the tide to reach the pier, then time your shot."
		return "Fire as Ferry I approaches the pier."
	return super._hint()


func _prepare_launch() -> void:
	super._prepare_launch()
	if _current_platform != Platform.LOG_1 or not _pier_height_reachable():
		return
	# The Pier is fixed: find the first descending contact, including extra
	# descent after the arc. Moving-deck prediction stays in the shared base.
	var target := _deck_position(Platform.ROCK) + FRAGMENT_OFFSET
	var entry_x := (target.x - LANDING_X + 0.01 - _hop_start.x) / SHOT.x
	if entry_x > 1.0:
		return
	var peak := acos(clampf((_hop_end.y - _hop_start.y) / (PI * HOP_HEIGHT), -1.0, 1.0)) / PI
	var first := maxf(peak, maxf(0.0, entry_x)) * hop_duration
	if first > _flight_duration:
		return
	# Aim for the actual deck surface; retain endpoint tolerance as fallback.
	var contact_y := target.y
	var last := _flight_duration
	if _hop_point(first / hop_duration).y >= contact_y:
		last = first
	else:
		for iteration: int in range(20):
			var middle := (first + last) * 0.5
			if _hop_point(middle / hop_duration).y < contact_y:
				first = middle
			else:
				last = middle
	var error := target - _hop_point(last / hop_duration)
	if absf(error.x) <= LANDING_X and absf(error.y) <= LANDING_Y:
		_flight_duration = last
		_touchdown_time = _elapsed_time + last
