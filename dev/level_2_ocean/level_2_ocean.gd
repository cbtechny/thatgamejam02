extends "res://Level/tidal_ferry_room.gd"

enum Platform { START, LOG_1, ROCK, LOG_2, GOAL }


func _ready() -> void:
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
