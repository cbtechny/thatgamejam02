shader_type canvas_item;
render_mode unshaded;

#include "res://Level/painted_scenery.gdshaderinc"

uniform vec2 mask_origin = vec2(-2.0);
uniform vec2 mask_size = vec2(364.0, 204.0);
uniform float stage_floor_y = 200.0;
uniform float beam_slope = 0.0;
uniform vec2 lamp_position = vec2(180.0, 22.0);
uniform sampler2D night_scenery : source_color, filter_linear, repeat_disable;
uniform sampler2D tower_texture : source_color, filter_linear, repeat_disable;
uniform vec4 tower_rect = vec4(140.0, 4.0, 80.0, 152.0);

void fragment() {
	// Extend past the room bounds to cover the antialiased water edges.
	vec2 point = mask_origin + UV * mask_size;
	vec2 offset = point - lamp_position;
	float depth = max(offset.y, 0.0);
	float radius = 5.0 + depth * 0.69;
	float distance_to_beam = abs(offset.x - beam_slope * depth);
	float beam = step(0.0, offset.y) * (1.0 - smoothstep(radius * 0.72, radius, distance_to_beam));
	beam *= 1.0 - smoothstep(stage_floor_y, stage_floor_y + 14.0, point.y);
	float lantern = 1.0 - smoothstep(6.0, 10.0, length(offset));
	float visibility = max(beam, lantern);
	// The mask extends two units past the scenery on each side.
	vec2 scenery_uv = (UV * mask_size - vec2(2.0)) / (mask_size - vec2(4.0));
	vec3 ambient = painted_scenery(texture(night_scenery, scenery_uv).rgb, scenery_uv, 2, 0.0);
	// Keep the distant tower readable and let its footing disappear into sea haze.
	vec2 tower_uv = (point - tower_rect.xy) / tower_rect.zw;
	vec4 tower = texture(tower_texture, tower_uv);
	float tower_bounds = step(0.0, tower_uv.x) * step(tower_uv.x, 1.0)
		* step(0.0, tower_uv.y) * step(tower_uv.y, 1.0);
	float haze = 1.0 - smoothstep(86.0, 118.0, point.y);
	vec3 silhouette = tower.rgb * vec3(0.28, 0.32, 0.40);
	ambient = mix(ambient, silhouette, tower.a * tower_bounds * haze * 0.78);
	float ambient_light = mix(0.5, 1.0, visibility);
	vec3 lit = ambient * ambient_light + vec3(0.42, 0.29, 0.15) * visibility;
	COLOR = vec4(lit, 1.0 - 0.93 * visibility);
}
