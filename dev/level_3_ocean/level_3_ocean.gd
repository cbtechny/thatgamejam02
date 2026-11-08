extends "res://Level/tidal_ferry_room.gd"
## The lighthouse reveals the water on its own clock. The crank still sets the tide.

enum Platform { START, LOG_1, LOG_2, BREAKWATER, LOG_3, GOAL }

const LAMP := Vector2(180.0, 22.0)
const SWEEP_PERIOD: float = 13.0

@onready var _beam_material: ShaderMaterial = $NightMask/Darkness.material


func _ready() -> void:
	_middle_fragment_platform = Platform.BREAKWATER
	_platform_names = ["Shore", "Drift I", "Drift II", "Breakwater", "Drift III", "Keyhole"]
	_floating_platforms = [Platform.LOG_1, Platform.LOG_2, Platform.LOG_3]
	_platform_fans = [$Fan/Blades, $FanDriftI/Blades, $FanDriftII/Blades, $FanBreakwater/Blades, $FanDriftIII/Blades]
	_next_scene = "res://Level/ending.tscn"
	_beam_material.set_shader_parameter(&"lamp_position", LAMP)
	_scenery.copy_paint_textures_to(_beam_material)
	_beam_material.set_shader_parameter(&"tower_texture", _scenery.LIGHTHOUSE)
	var tower: Rect2 = _scenery.LIGHTHOUSE_RECT
	_beam_material.set_shader_parameter(&"tower_rect", Vector4(tower.position.x, tower.position.y, tower.size.x, tower.size.y))
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
	return "Turn the crank. Follow the beam."


func _update_scenery_bounds() -> void:
	var darkness: ColorRect = $NightMask/Darkness
	var mask := _scenery_bounds.grow(2.0)
	darkness.position = mask.position
	darkness.size = mask.size
	_beam_material.set_shader_parameter(&"mask_origin", mask.position)
	_beam_material.set_shader_parameter(&"mask_size", mask.size)
	_beam_material.set_shader_parameter(&"stage_floor_y", _scenery_bounds.end.y)
