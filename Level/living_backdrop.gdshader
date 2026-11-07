shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.65, 0.65, 0.65, 1.0);
uniform float motion_amount : hint_range(0.0, 0.04) = 0.018;
uniform float motion_speed : hint_range(0.0, 1.0) = 0.65;
uniform bool sky_mode = false;
varying vec4 item_color;
void vertex() { item_color = COLOR; }
void fragment() {
	vec2 uv = UV;
	float t = TIME * motion_speed;
	uv.x += sin(uv.y * 6.283 + t) * motion_amount;
	uv.y += cos(uv.x * 6.283 + t * 0.7) * motion_amount;
	vec4 paint = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	if (sky_mode) {
		float cloud = smoothstep(0.08, 0.75, dot(paint.rgb, vec3(0.299, 0.587, 0.114)));
		paint.rgb = mix(vec3(0.002, 0.005, 0.012), vec3(0.035, 0.095, 0.17), cloud);
	}
	COLOR = paint * tint * item_color;
}
