extends TextureRect
## The close pieces sway on independent clocks while the painted wings stay fixed.

var _time: float = 0.0


func _ready() -> void:
	material = material.duplicate()


func _process(delta: float) -> void:
	_time += delta
	(material as ShaderMaterial).set_shader_parameter(&"scenery_time", _time)
