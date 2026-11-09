shader_type spatial;
// D-319: ngọn lửa trại bập bùng (người chơi: lửa đứng im). Một tấm phẳng luôn quay mặt về camera quanh trục đứng; 3 lưỡi
// lửa cong lắc theo thời gian (pha riêng mỗi đống lửa theo vị trí), lõi vàng → viền cam → đỉnh mờ. Trộn màu thường (cộng sáng chìm trên đất vàng),
// không ghi chiều sâu, không đèn.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.92, 0.55);
uniform vec3 edge : source_color = vec3(1.0, 0.45, 0.08);

varying float seed;

void vertex() {
	seed = dot(MODEL_MATRIX[3].xz, vec2(0.37, 0.71));
	// quay quanh trục đứng về phía camera (giữ thẳng đứng)
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z)) * length(MODEL_MATRIX[0].xyz);
	vec3 up = vec3(0.0, 1.0, 0.0) * length(MODEL_MATRIX[1].xyz);
	vec3 world = MODEL_MATRIX[3].xyz + right * VERTEX.x + up * VERTEX.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float tongue(vec2 uv, float x0, float w, float h, float t) {
	float y = 1.0 - uv.y;  // 0 đáy → 1 đỉnh
	float sway = sin(t * 7.0 + y * 4.0) * 0.06 * y + sin(t * 11.3 + y * 9.0) * 0.025 * y;
	float half_w = w * (1.0 - smoothstep(0.0, h, y)) * (0.6 + 0.4 * sin(y * 3.14));
	return 1.0 - smoothstep(half_w * 0.6, half_w, abs(uv.x - 0.5 - x0 - sway));
}

void fragment() {
	float t = TIME + seed;
	float h = 0.82 + 0.12 * sin(t * 5.1) + 0.06 * sin(t * 13.7);
	float a = max(tongue(UV, 0.0, 0.3, h, t), max(tongue(UV, -0.14, 0.18, h * 0.7, t + 1.7), tongue(UV, 0.14, 0.18, h * 0.75, t + 3.1)));
	float y = 1.0 - UV.y;
	float hot = tongue(UV, 0.0, 0.16, h * 0.55, t);
	vec3 col = mix(edge, core, hot) * (1.0 - 0.5 * smoothstep(0.5, 1.0, y));
	ALBEDO = col;
	ALPHA = clamp(a * (1.0 - 0.45 * y), 0.0, 1.0);
}
