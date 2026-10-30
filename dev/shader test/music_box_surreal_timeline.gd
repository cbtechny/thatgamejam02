extends MusicBoxTimeline
## Keep shader and panorama presentation on the same winding rules as Main.

const SHADER_TRANSITION_RATE: float = 2.5

@onready var _shader_material: ShaderMaterial = $SurrealMarbledBackground.material as ShaderMaterial
@onready var _box_window: Control = $BoxWindow
@onready var _box_window_texture: TextureRect = $BoxWindow/TextureRect

var _shader_time: float = 0.0
var _shader_motion_multiplier: float = 1.0
var _shader_motion_intensity: float = 0.0
var _shader_return_blend: float = 0.0
var _shader_forward_blend: float = 0.0
var _shader_idle_speed: float = 0.035
var _shader_forward_speed_multiplier: float = 5.0
var _box_window_scroll_range: float = 0.0


func _ready() -> void:
	super._ready()
	_box_window.clip_contents = true
	call_deferred("_cache_box_window_scroll_range")
	_shader_idle_speed = float(_shader_material.get_shader_parameter("motion_speed"))
	_shader_forward_speed_multiplier = float(_shader_material.get_shader_parameter("forward_speed_scale"))
	_update_shader_response(0.0)


func _process(delta: float) -> void:
	super._process(delta)
	_update_shader_response(delta)


func _update_shader_response(delta: float) -> void:
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


func _set_background_progress(value: float) -> void:
	super._set_background_progress(value)
	_update_box_window_pan()


func _cache_box_window_scroll_range() -> void:
	var panorama_width: float = float(_box_window_texture.texture.get_width())
	if _box_window_texture.size.x <= _box_window.size.x:
		_box_window_texture.size.x = maxf(panorama_width, _box_window.size.x)
	_box_window_scroll_range = maxf(0.0, _box_window_texture.size.x - _box_window.size.x)
	_update_box_window_pan()


func _update_box_window_pan() -> void:
	_box_window_texture.position.x = -_box_window_scroll_range * _background_progress
