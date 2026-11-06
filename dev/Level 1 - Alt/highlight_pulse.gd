class_name HighlightPulse
extends Node2D
## Reusable soft, pulsing ring for drawing attention to a Node2D target.

@export var radius: float = 64.0
@export var glow_color: Color = Color(1.0, 0.8, 0.38, 0.8)
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
	outer.a *= 0.06 + pulse * 0.06
	var middle: Color = glow_color
	middle.a *= 0.35 + pulse * 0.18
	var core: Color = glow_color
	core.a *= 0.45 + pulse * 0.15
	draw_circle(Vector2.ZERO, radius * (1.12 + pulse * 0.08), outer)
	draw_arc(Vector2.ZERO, radius * (0.94 + pulse * 0.06), 0.0, TAU, 64, middle, 6.0 + pulse * 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 64, core, 2.5, true)
	for index: int in range(3):
		var angle: float = _time * 0.25 + float(index) * TAU / 3.0
		draw_circle(Vector2.from_angle(angle) * radius, 3.0 + pulse, core)
