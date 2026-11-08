shader_type canvas_item;
render_mode unshaded;

#include "res://Level/painted_scenery.gdshaderinc"

uniform int room_style = 0;
uniform float scenery_time = 0.0;

void fragment() {
	vec3 ground = texture(TEXTURE, UV).rgb;
	COLOR = vec4(painted_scenery(ground, UV, room_style, scenery_time), 1.0);
}
