shader_type spatial;
// D-176: cây rừng — màu theo đỉnh (sRGB như ModelLibrary.use_vertex_colors). Phần cây nằm giữa camera
// và một tướng (focus) bị bỏ điểm ảnh theo mẫu ô Bayer 4×4 (thưa dần về mép ống nhìn) để không che
// tướng; vẫn đục (không cần vẽ trong suốt, rẻ trên GL Compatibility).

// xyz: điểm giữa thân tướng (đơn vị 3D); w > 0.5: đang dùng.
uniform vec4 focus[10];
// Bán kính ống nhìn quanh đường camera → tướng; độ mềm mép; phần điểm ảnh bỏ tối đa.
uniform float radius = 1.15;
uniform float soft = 0.45;
uniform float max_fade = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	float fade = 0.0;
	for (int i = 0; i < 10; i++) {
		if (focus[i].w < 0.5) {
			continue;
		}
		vec3 seg = focus[i].xyz - cam;
		float t = dot(world_pos - cam, seg) / dot(seg, seg);
		if (t <= 0.0 || t >= 1.0) {
			continue;  // chỉ phần nằm trước tướng (phía camera)
		}
		float d = length(world_pos - (cam + seg * t));
		fade = max(fade, 1.0 - smoothstep(radius - soft, radius, d));
	}
	if (fade * max_fade > bayer4(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
