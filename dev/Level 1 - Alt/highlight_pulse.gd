class_name HighlightPulse
extends Node2D
## Reusable soft, pulsing ring for drawing attention to a Node2D target.

@export var radius: float = 64.0
@export var glow_color: Color = Color(1.0, 0.78, 0.32, 0.34)
@export_range(0.2, 8.0, 0.1) var pulse_speed: float = 2.4
@export var active: bool = true

var _time: float = 0.0


func _process(delta: float) -> void:
	visible = active
	if active:
		_time += delta * pulse_speed
		queue_redraw()


func set_active(value: bool) -> void:
	active = value
	visible = value
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time)
	var outer: Color = glow_color
	outer.a *= 0.10 + pulse * 0.10
	var middle: Color = glow_color
	middle.a *= 0.18 + pulse * 0.14
	var core: Color = glow_color
	core.a *= 0.3 + pulse * 0.2
	draw_circle(Vector2.ZERO, radius * (1.12 + pulse * 0.08), outer)
	draw_arc(Vector2.ZERO, radius * (0.94 + pulse * 0.06), 0.0, TAU, 48, middle, 10.0 + pulse * 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 48, core, 3.0, true)
