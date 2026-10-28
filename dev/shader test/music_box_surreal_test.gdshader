shader_type canvas_item;

// Two fixed warp passes keep this full-screen effect inexpensive at 1080p.
// The controls are intentionally few so the comparison stays easy to tune.
uniform vec4 ink_blue : source_color = vec4(0.025, 0.08, 0.20, 1.0);
uniform vec4 dusty_violet : source_color = vec4(0.055, 0.27, 0.52, 1.0);
uniform vec4 warm_paper : source_color = vec4(0.36, 0.61, 0.78, 1.0);
uniform float motion_speed : hint_range(0.0, 0.3, 0.01) = 0.035;
uniform float forward_speed_scale : hint_range(1.0, 10.0, 0.25) = 7.0;
uniform vec4 forward_yellow : source_color = vec4(0.98, 0.70, 0.16, 1.0);
uniform vec4 forward_orange : source_color = vec4(0.96, 0.32, 0.08, 1.0);
uniform vec4 return_ink_red : source_color = vec4(0.30, 0.025, 0.055, 1.0);
uniform vec4 return_violet_red : source_color = vec4(0.68, 0.075, 0.12, 1.0);
uniform vec4 return_paper_red : source_color = vec4(0.95, 0.29, 0.25, 1.0);
uniform float return_blend : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float forward_blend : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float animation_time = 0.0;
uniform float motion_intensity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float warp_strength : hint_range(0.0, 0.25, 0.005) = 0.055;
uniform vec2 focal_offset = vec2(0.0, 0.0);
uniform int quality : hint_range(1, 2, 1) = 2;

void fragment() {
	// Use screen-space aspect correction to keep the swirls proportionate.
	vec2 centered = UV - (vec2(0.5) + focal_offset);
	centered.x *= 1.7777778;
	// The duplicate timeline advances this clock only while the box is active.
	float time = animation_time;

	// Active playback greatly widens the coordinate warp for obvious movement.
	float active_warp = mix(0.04, 0.42, motion_intensity);
	vec2 flow = centered;
	flow += active_warp * vec2(
		sin(centered.y * mix(3.0, 7.0, motion_intensity) + time * 1.4),
		cos(centered.x * mix(2.5, 6.0, motion_intensity) - time)
	);
	float first_field = length(flow * vec2(0.82, 1.25));
	float second_field = length(flow - vec2(0.42, -0.18));
	float warp_gain = mix(1.2, 7.0, motion_intensity);
	vec2 warped = flow + warp_strength * warp_gain * vec2(
		sin(second_field * mix(5.0, 10.0, motion_intensity) + time),
		cos(first_field * mix(4.0, 9.0, motion_intensity) - time * 0.8)
	);

	// The optional second pass adds gentle cross-flow without texture reads.
	if (quality > 1) {
		float cross_wave = sin((warped.x + warped.y) * 4.0 - time);
		warped += warp_strength * mix(0.12, 1.25, motion_intensity) * vec2(cross_wave, -cross_wave);
	}

	// Playback also tightens and curls the color bands for a stronger visual shift.
	float band_scale = mix(3.2, 7.2, motion_intensity);
	float marble = sin(warped.x * band_scale + warped.y * band_scale * 0.44 + sin(warped.y * band_scale * 0.9) * mix(0.2, 1.0, motion_intensity));
	float violet_mix = smoothstep(-0.52, -0.04, marble);
	float paper_mix = smoothstep(0.46, 0.82, marble);
	// Forward transit keeps the deep blue band and adds gold and orange bands.
	vec3 forward_ink = ink_blue.rgb;
	vec3 forward_violet = mix(dusty_violet.rgb, forward_yellow.rgb, forward_blend);
	vec3 forward_paper = mix(warm_paper.rgb, forward_orange.rgb, forward_blend);
	vec3 transit_ink = mix(forward_ink, return_ink_red.rgb, return_blend);
	vec3 transit_violet = mix(forward_violet, return_violet_red.rgb, return_blend);
	vec3 transit_paper = mix(forward_paper, return_paper_red.rgb, return_blend);
	vec3 color = mix(transit_ink, transit_violet, violet_mix);
	color = mix(color, transit_paper, paper_mix);
	COLOR = vec4(color, 1.0);
}
