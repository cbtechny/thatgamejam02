extends Node2D
## Decorative painted cutouts, behind puzzle pieces and clipped by BoxWindow.
@export var rotation_speeds: Array[float] = [6.0, -9.0, 7.0, -5.0]

func _process(delta: float) -> void:
	for index: int in range(mini(get_child_count(), rotation_speeds.size())):
		var ornament := get_child(index) as Sprite2D
		ornament.rotation = wrapf(ornament.rotation + deg_to_rad(rotation_speeds[index]) * delta, -PI, PI)
