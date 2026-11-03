extends Control

signal resume_requested

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		resume_requested.emit()
		get_viewport().set_input_as_handled()
