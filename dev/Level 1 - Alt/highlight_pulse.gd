class_name HighlightPulse
extends Node2D
## Reusable soft, pulsing ring for drawing attention to a Node2D target.

const READY_COLOR := Color(1.0, 0.84, 0.42, 0.9)
const WAITING_COLOR := Color(0.7, 0.42, 1.0, 0.85)

@export var radius: float = 64.0
@export var glow_color: Color = Color(1.0, 0.8, 0.38, 0.8)
@export_range(0.0, 8.0, 0.1) var intensity: float = 2.0
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
	outer.a = clampf(outer.a * (0.06 + pulse * 0.06) * intensity, 0.0, 1.0)
	var middle: Color = glow_color
	middle.a = clampf(middle.a * (0.35 + pulse * 0.18) * intensity, 0.0, 1.0)
	var core: Color = glow_color
	core.a = clampf(core.a * (0.45 + pulse * 0.15) * intensity, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * (1.12 + pulse * 0.08), outer)
	draw_arc(Vector2.ZERO, radius * (0.94 + pulse * 0.06), 0.0, TAU, 64, middle, 6.0 + pulse * 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 64, core, 2.5, true)
	for index: int in range(3):
		var angle: float = _time * 0.25 + float(index) * TAU / 3.0
		draw_circle(Vector2.from_angle(angle) * radius, 3.0 + pulse, core)


static func attach(target: Node2D, glow_radius: float) -> HighlightPulse:
	var highlight: HighlightPulse = HighlightPulse.new()
	highlight.radius = glow_radius
	# Stay behind this sprite without falling behind the stage background.
	highlight.z_index = 0
	highlight.show_behind_parent = true
	target.add_child(highlight)
	return highlight


static func attach_sparkles(target: Sprite2D, sprite_pixel_scale: Vector2) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "KeySparkles"
	particles.amount = 10
	particles.lifetime = 0.9
	particles.explosiveness = 0.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# The emitter follows the visible sprite, with small glints in world pixels.
	particles.scale = Vector2.ONE / sprite_pixel_scale
	particles.emission_rect_extents = target.texture.get_size() * sprite_pixel_scale * Vector2(0.36, 0.22)
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.gravity = Vector2(0.0, -5.0)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.45
	particles.color = Color(1.0, 0.88, 0.56, 0.9)
	particles.texture = make_sparkle_texture()
	target.add_child(particles)
	particles.position = Vector2.ZERO
	particles.emitting = true
	return particles


static func make_sparkle_texture() -> Texture2D:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in range(16):
		for x: int in range(16):
			var distance: float = Vector2(x - 7.5, y - 7.5).length() / 7.5
			var core: float = clampf(1.0 - distance * 2.0, 0.0, 1.0)
			var ray: float = clampf(1.0 - minf(absf(x - 7.5), absf(y - 7.5)), 0.0, 1.0)
			var alpha: float = maxf(core, ray) * clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
