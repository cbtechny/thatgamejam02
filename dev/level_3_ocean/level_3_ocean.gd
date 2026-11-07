extends "res://Level/tidal_ferry_room.gd"
## The lighthouse reveals the water on its own clock. The crank still sets the tide.

enum Platform { START, LOG_1, LOG_2, BREAKWATER, LOG_3, GOAL }

const LAMP := Vector2(180.0, 22.0)
const SWEEP_PERIOD: float = 13.0

@onready var _beam_material: ShaderMaterial = $NightMask/Darkness.material


func _ready() -> void:
	_platform_names = ["Shore", "Drift I", "Drift II", "Breakwater", "Drift III", "Keyhole"]
	_floating_platforms = [Platform.LOG_1, Platform.LOG_2, Platform.LOG_3]
	_platform_fans = [$Fan/Blades, $FanDriftI/Blades, $FanDriftII/Blades, $FanBreakwater/Blades, $FanDriftIII/Blades]
	_next_scene = "res://Level/ending.tscn"
	_beam_material.set_shader_parameter(&"lamp_position", LAMP)
	super._ready()
	var navigation := preload("res://Level/night_navigation.gd").new()
	navigation.name = "NightNavigation"
	add_child(navigation)


func _deck_at(platform: int, time: float) -> Vector2:
	var raft_y := _water_level() - 6.0
	match platform:
		Platform.START:
			return Vector2(26.0, 145.0)
		Platform.LOG_1:
			return Vector2(96.0 + 22.0 * sin(time * TAU / 4.9 - 0.8), raft_y)
		Platform.LOG_2:
			return Vector2(167.0 - 22.0 * cos(time * TAU / 6.1 + 0.7), raft_y)
		Platform.BREAKWATER:
			return Vector2(233.0, 119.0)
		Platform.LOG_3:
			return Vector2(284.0 + 24.0 * sin(time * TAU / 6.7 + 1.3), raft_y)
		Platform.GOAL:
			return Vector2(333.0, 91.0)
	return Vector2.ZERO


func _process(delta: float) -> void:
	super._process(delta)
	_update_beam()


func _update_mechanisms() -> void:
	super._update_mechanisms()
	_update_beam()


func _update_beam() -> void:
	var slope := -2.13 * cos(_elapsed_time * TAU / SWEEP_PERIOD + 0.91)
	_beam_material.set_shader_parameter(&"beam_slope", slope)


func _hint() -> String:
	return "Watch the drift while the lighthouse sweeps past."


func _draw() -> void:
	_draw_lighthouse()
	super._draw()


func _draw_lighthouse() -> void:
	# A cliff and painted masonry behind the playable decks.
	draw_colored_polygon(PackedVector2Array([
		Vector2(143, 154), Vector2(155, 109), Vector2(162, 94),
		Vector2(196, 92), Vector2(207, 110), Vector2(217, 154),
	]), Color("354654"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(171, 29), Vector2(189, 29), Vector2(199, 102), Vector2(161, 102),
	]), Color("c4b29b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(171, 36), Vector2(190, 36), Vector2(192, 52), Vector2(168, 52),
	]), Color("8e4c44"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(166, 65), Vector2(194, 65), Vector2(196, 82), Vector2(164, 82),
	]), Color("8e4c44"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(184, 29), Vector2(189, 29), Vector2(199, 102), Vector2(185, 102),
	]), Color(0.12, 0.18, 0.23, 0.32))
	draw_rect(Rect2(175, 84, 10, 17), Color("2c3b47"))
	draw_rect(Rect2(166, 27, 28, 4), Color("4d535a"))
	draw_rect(Rect2(171, 15, 18, 12), Color("54636c"))
	draw_rect(Rect2(174, 17, 12, 9), Color("f1b963"))
	draw_circle(LAMP, 3.6, Color("fff0b0"), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(167, 16), Vector2(180, 8), Vector2(193, 16),
	]), Color("844d48"))
