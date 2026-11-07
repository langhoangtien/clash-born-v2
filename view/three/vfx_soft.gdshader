// D-296: hiệu ứng chiêu "dịu" dựng bằng shader (không cần ảnh) — phong cách Liên Quân / MLBB nhưng ít chói: trộn alpha
// (không cộng sáng), độ đục tối đa `alpha`, lõi chỉ sáng hơn màu chính một chút, nhiễu nhẹ cho đỡ phẳng, tan nhanh.
// `t` = tiến độ 0..1 của mảnh (VfxParts đặt mỗi khung). Chế độ `mode`:
//  0 vành mặt đất loang từ `from` ra mép · 1 đĩa mặt đất lóe rồi tan · 2 cột sáng (hình trụ, UV.y dọc) ·
//  3 đốm sáng quay về camera · 4 hào quang dưới chân (đứng yên, thở nhẹ) · 5 vệt đạn (UV.x dọc thân, đầu ở x = 1) ·
//  6 sóng mặt đất chạy dọc UV.y (0 gần chủ chiêu → 1 xa).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float t = 0.0;
uniform float alpha = 0.6;
uniform float width = 0.1;
uniform float from = 0.2;
uniform bool billboard = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Hiện nhanh trong `rise`, tan dần từ `hold` tới hết.
float life_fade(float rise, float hold) {
	return smoothstep(0.0, rise, t) * (1.0 - smoothstep(hold, 1.0, t));
}

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = 0.0;
	float core = 0.0;
	if (mode == 0) {
		float rr = mix(from, 1.0, 1.0 - pow(1.0 - t, 3.0));
		float band = 1.0 - smoothstep(0.0, width, abs(r - rr));
		float fill = (1.0 - smoothstep(0.0, rr, r)) * step(r, rr) * 0.3;
		a = (band + fill) * (0.8 + 0.2 * noise(c * 7.0 + TIME)) * life_fade(0.04, 0.45);
		core = band * band;
	} else if (mode == 1) {
		float n = noise(c * 4.0 + vec2(TIME * 0.6, -TIME * 0.4));
		float body = 1.0 - smoothstep(0.7, 1.0, r);
		float rim = 1.0 - smoothstep(0.0, 0.07, abs(r - 0.92));
		a = (body * (0.35 + 0.35 * n) + rim * 0.8) * life_fade(0.1, 0.55);
		core = rim;
	} else if (mode == 2) {
		float v = UV.y;
		float n = noise(vec2(UV.x * 10.0, v * 3.0 - TIME * 2.5));
		a = pow(v, 1.2) * (0.6 + 0.4 * n) * life_fade(0.08, 0.45);
		core = pow(v, 4.0) * 0.6;
	} else if (mode == 3) {
		a = exp(-r * r * 5.0) * (1.0 - t * t);
		core = exp(-r * r * 22.0);
	} else if (mode == 4) {
		float band = 1.0 - smoothstep(0.0, width, abs(r - 0.82));
		float inner = (1.0 - smoothstep(0.15, 0.82, r)) * 0.1;
		float swirl = noise(vec2(atan(c.y, c.x) * 2.5 + TIME * 0.8, TIME * 0.5));
		a = (band * (0.7 + 0.3 * swirl) + inner * 1.5) * (0.85 + 0.15 * sin(TIME * 3.5)) * life_fade(0.06, 0.88);
		core = band * 0.5;
	} else if (mode == 5) {
		float across = 1.0 - smoothstep(0.0, 1.0, abs(c.y));
		a = pow(UV.x, 2.2) * across * (0.8 + 0.2 * noise(vec2(UV.x * 12.0 - TIME * 8.0, c.y * 3.0)));
		core = pow(UV.x, 8.0) * pow(across, 3.0);
	} else {
		float y = 1.0 - UV.y + c.x * c.x * 0.12;  // QuadMesh: UV.y = 0 ở đầu xa; mép sóng cong như lưỡi liềm
		float front = mix(-0.1, 1.15, t);
		float band = smoothstep(front - 0.35, front, y) * (1.0 - smoothstep(front, front + 0.06, y));
		float across = 1.0 - smoothstep(0.35, 1.0, abs(c.x));
		a = band * across * (0.6 + 0.4 * noise(vec2(c.x * 5.0, y * 6.0 - TIME * 3.0))) * (1.0 - smoothstep(0.75, 1.0, t));
		core = band * band * across;
	}
	ALBEDO = mix(color.rgb, edge.rgb, clamp(core, 0.0, 1.0) * 0.8);
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
