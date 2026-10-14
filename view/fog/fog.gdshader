shader_type canvas_item;
// Sương mù (M5.1): tối ở nơi phe mình không thấy. eyes[i] = (x, y, tầm nhìn, 0) theo tọa độ map.
uniform vec4 eyes[128];
uniform int count = 0;
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.07, 0.6);
uniform float edge = 80.0;
varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	float lit = 0.0;
	for (int i = 0; i < count; i++) {
		float d = distance(world_pos, eyes[i].xy);
		lit = max(lit, 1.0 - smoothstep(eyes[i].z - edge, eyes[i].z, d));
		if (lit >= 1.0) {
			break;
		}
	}
	COLOR = vec4(fog_color.rgb, fog_color.a * (1.0 - lit));
}
