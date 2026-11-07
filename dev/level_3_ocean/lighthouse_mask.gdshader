shader_type canvas_item;
render_mode unshaded;

uniform float beam_slope = 0.0;
uniform vec2 lamp_position = vec2(180.0, 22.0);

void fragment() {
	// Extend past the room bounds to cover the antialiased water edges.
	vec2 point = UV * vec2(364.0, 204.0) - vec2(2.0);
	vec2 offset = point - lamp_position;
	float depth = max(offset.y, 0.0);
	float radius = 5.0 + depth * 0.69;
	float distance_to_beam = abs(offset.x - beam_slope * depth);
	float beam = step(0.0, offset.y) * (1.0 - smoothstep(radius * 0.72, radius, distance_to_beam));
	beam *= 1.0 - smoothstep(162.0, 176.0, point.y);
	float lantern = 1.0 - smoothstep(6.0, 10.0, length(offset));
	float visibility = max(beam, lantern);
	COLOR = vec4(vec3(0.20, 0.15, 0.08) * visibility, 1.0 - 0.93 * visibility);
}
