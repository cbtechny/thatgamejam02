uniform sampler2D brushwork : source_color, filter_linear, repeat_disable;
uniform sampler2D painted_ball : source_color, filter_linear, repeat_disable;
uniform sampler2D painted_spiral : source_color, filter_linear, repeat_disable;
uniform sampler2D painted_drum : source_color, filter_linear, repeat_disable;
uniform sampler2D painted_star : source_color, filter_linear, repeat_disable;

vec3 painted_cutout(vec3 backdrop, sampler2D paint, vec2 point, vec4 placement, vec3 grade, float angle, float opacity) {
	vec2 offset = point - placement.xy;
	float c = cos(angle);
	float s = sin(angle);
	vec2 uv = (mat2(vec2(c, -s), vec2(s, c)) * offset) / placement.zw + vec2(0.5);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return backdrop;
	}
	vec4 brush = texture(paint, uv);
	float value = dot(brush.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pigment = mix(vec3(value), brush.rgb, 0.65) * grade;
	return mix(backdrop, pigment, brush.a * opacity);
}

vec3 painted_scenery(vec3 backdrop, vec2 uv, int room_style, float time) {
	vec2 p = uv * vec2(610.0, 390.0);
	float side = smoothstep(0.13, 0.46, abs(uv.x - 0.5));
	vec2 mural_uv = vec2(uv.x + 0.06 * sin(uv.y * 8.0), uv.y * 0.79 + 0.07);
	vec3 mural = texture(brushwork, mural_uv).rgb;

	if (room_style == 0) {
		// The painted folds sit inside the box's wings; the center recedes into shadow.
		backdrop = mix(backdrop, mural * vec3(0.38, 0.36, 0.43), 0.12 + side * 0.63);
		backdrop = painted_cutout(backdrop, painted_ball, p, vec4(407, 151, 38, 33), vec3(0.42, 0.52, 0.59), 0.8, 0.45);
		backdrop = painted_cutout(backdrop, painted_ball, p, vec4(443, 169, 61, 54), vec3(0.48, 0.57, 0.60), 0.5, 0.62);
		backdrop = painted_cutout(backdrop, painted_ball, p, vec4(486, 192, 92, 84), vec3(0.52, 0.57, 0.61), 0.2, 0.75);
		backdrop = painted_cutout(backdrop, painted_star, p, vec4(158, 162, 61, 83), vec3(0.47, 0.44, 0.54), -0.2, 0.74);
		backdrop = painted_cutout(backdrop, painted_spiral, p, vec4(75, 266, 249, 206), vec3(0.57, 0.51, 0.64), 0.18 + sin(time * 0.28) * 0.12, 0.88);
		backdrop = painted_cutout(backdrop, painted_drum, p, vec4(514, 304, 209, 172), vec3(0.58, 0.54, 0.61), -0.55 + sin(time * 0.42) * 0.075, 0.87);
		return backdrop;
	}

	// Stretch the original painting across the distant strata, under the moving tide.
	float horizon = smoothstep(0.38, 0.61, uv.y) * (1.0 - smoothstep(0.68, 0.9, uv.y));
	mural_uv = vec2(uv.x * 0.86 + 0.07, uv.y * 0.41 + 0.33 + 0.055 * sin(uv.x * 8.0));
	mural = texture(brushwork, mural_uv).rgb;
	if (room_style == 1) {
		backdrop = mix(backdrop, mural * vec3(0.54, 0.60, 0.64), (0.07 + side * 0.33) * horizon);
		backdrop = painted_cutout(backdrop, painted_spiral, p, vec4(378, 157, 109, 98), vec3(0.75, 0.64, 0.59), sin(time * 0.23) * 0.16, 0.68);
		backdrop = painted_cutout(backdrop, painted_ball, p, vec4(82, 126, 188, 171), vec3(0.43, 0.52, 0.61), -0.46, 0.73);
		backdrop = painted_cutout(backdrop, painted_drum, p, vec4(183, 226, 45, 29), vec3(0.49, 0.64, 0.70), 1.05, 0.34);
		backdrop = painted_cutout(backdrop, painted_drum, p, vec4(150, 233, 65, 48), vec3(0.49, 0.62, 0.67), 0.97, 0.48);
		backdrop = painted_cutout(backdrop, painted_drum, p, vec4(106, 243, 91, 68), vec3(0.49, 0.59, 0.63), 0.88, 0.64);
		backdrop = painted_cutout(backdrop, painted_drum, p, vec4(549, 253.0 + sin(time * 0.40) * 3.5, 172, 124), vec3(0.50, 0.55, 0.58), -0.66, 0.63);
		return backdrop;
	}

	backdrop = mix(backdrop, mural * vec3(0.25, 0.32, 0.52), horizon * (0.14 + side * 0.45));
	backdrop = painted_cutout(backdrop, painted_spiral, p, vec4(538, 145, 232, 196), vec3(0.21, 0.30, 0.53), -0.46, 0.65);
	backdrop = painted_cutout(backdrop, painted_ball, p, vec4(80, 245, 166, 111), vec3(0.24, 0.36, 0.49), 0.65, 0.56);
	backdrop = painted_cutout(backdrop, painted_star, p, vec4(449, 199, 31, 38), vec3(0.31, 0.40, 0.63), 0.8, 0.41);
	backdrop = painted_cutout(backdrop, painted_star, p, vec4(425, 174, 41, 51), vec3(0.33, 0.43, 0.67), 0.54, 0.52);
	backdrop = painted_cutout(backdrop, painted_star, p, vec4(398, 145, 69, 78), vec3(0.44, 0.52, 0.75), 0.26, 0.83);
	return backdrop;
}
