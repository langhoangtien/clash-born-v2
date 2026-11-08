// D-296: hiệu ứng chiêu "dịu" dựng bằng shader (không cần ảnh) — phong cách Liên Quân / MLBB nhưng ít chói: trộn alpha
// (không cộng sáng), độ đục tối đa `alpha`, lõi chỉ sáng hơn màu chính một chút, nhiễu nhẹ cho đỡ phẳng, tan nhanh.
// `t` = tiến độ 0..1 của mảnh (VfxParts đặt mỗi khung). Chế độ `mode`:
//  0 vành mặt đất loang từ `from` ra mép · 1 đĩa mặt đất lóe rồi tan · 2 cột sáng (hình trụ, UV.y dọc) ·
//  3 đốm sáng quay về camera · 4 hào quang dưới chân (đứng yên, thở nhẹ) · 5 vệt đạn (UV.x dọc thân, đầu ở x = 1) ·
//  6 sóng mặt đất chạy dọc UV.y (0 gần chủ chiêu → 1 xa) · 7 vũng (vùng tồn tại: mép loang không đều, gợn + bọt chạy) ·
//  8 vùng nạp (vùng có độ trễ: lõi sáng lớn dần theo t) · 9 khiên (bong bóng cầu, sáng ở rìa theo góc nhìn) ·
//  10 làn sáng bốc lên (hình trụ quanh người). D-297: mép mềm (không viền tròn sắc), thêm 7–10 theo góp ý người chơi.
//  D-298: 11 lốc xoáy (hình nón cụt, dải xoắn chạy lên) · 12 vòng xích dưới chân (mắt xích theo vòng) ·
//  13 vệt quét hình quạt (lưỡi sáng quét qua góc `angle` rồi tan; phía trước = UV.y nhỏ) · 14 khối băng (cầu, mặt
//  tinh thể theo ô, sáng rìa; D-299 dùng cho cụm tinh thể băng). 15 sao choáng xoay trên đầu (mặt phẳng ngang).
//  D-300: 16 tia gió trên dải bám đường chạy (SpeedTrail3D: UV.x = tuổi 0 đầu → 1 đuôi, UV.y ngang dải) — một đường
//  mảnh uốn lượn trong dải, mờ dần về đuôi (người chơi: vệt cũ thẳng tắp, đặc).
//  D-302: 17 luồng gió sau lưng (mặt phẳng quay về camera): 4 làn gió cong đứt quãng chảy ngược hướng chạy
//  `flow_angle`, đậm phía sau lưng, mờ dần ra rìa.
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
uniform float angle = 1.3;  // D-298: nửa góc quạt (radian) cho dạng 13
uniform float fade = 1.0;   // D-300: làm mờ cả mảnh (vệt gió tan cuối đời)
instance uniform float phase = 0.0;  // D-300: lệch pha từng dải gió
uniform float flow_angle = 0.0;     // D-302: hướng chạy trên màn hình (radian) cho dạng 17

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Mép tròn mềm, loang không đều theo góc (không ra đường tròn compa).
float soft_edge(vec2 c, float r, float inner, float wobble) {
	float ang = atan(c.y, c.x);
	float n = noise(vec2(ang * 2.2 + 3.0, TIME * 0.35)) + 0.5 * noise(vec2(ang * 5.0, TIME * 0.6 + 7.0));
	return 1.0 - smoothstep(inner, 1.0, r + (n - 0.75) * wobble);
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
		float d = (r - rr) / width;
		float band = exp(-d * d * 2.2);
		float fill = (1.0 - smoothstep(0.0, rr, r)) * smoothstep(rr + width, rr - width, r) * 0.3;
		float breakup = 0.6 + 0.4 * noise(vec2(atan(c.y, c.x) * 6.0, r * 4.0 - TIME * 1.5));
		a = (band * breakup + fill) * life_fade(0.04, 0.45);
		core = band * band;
	} else if (mode == 1) {
		float n = noise(c * 4.0 + vec2(TIME * 0.6, -TIME * 0.4));
		float body = soft_edge(c, r, 0.55, 0.25);
		float rim = body * smoothstep(0.45, 0.9, r);
		a = (body * (0.3 + 0.4 * n) + rim * 0.35) * life_fade(0.1, 0.55);
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
		float d = (r - 0.7) / max(width, 0.05);
		float band = exp(-d * d * 1.5);
		float glow = (1.0 - smoothstep(0.0, 0.85, r)) * 0.35;
		float swirl = noise(vec2(atan(c.y, c.x) * 3.0 + TIME * 0.9, r * 3.0 - TIME * 0.6));
		a = (band * (0.45 + 0.55 * swirl) + glow) * soft_edge(c, r, 0.7, 0.2) * (0.85 + 0.15 * sin(TIME * 3.0))
			* life_fade(0.06, 0.88);
		core = band * swirl * 0.6;
	} else if (mode == 5) {
		float across = 1.0 - smoothstep(0.0, 1.0, abs(c.y));
		a = pow(UV.x, 2.2) * across * (0.8 + 0.2 * noise(vec2(UV.x * 12.0 - TIME * 8.0, c.y * 3.0)));
		core = pow(UV.x, 8.0) * pow(across, 3.0);
	} else if (mode == 6) {
		float y = 1.0 - UV.y + c.x * c.x * 0.12;  // QuadMesh: UV.y = 0 ở đầu xa; mép sóng cong như lưỡi liềm
		float front = mix(-0.1, 1.15, t);
		float band = smoothstep(front - 0.35, front, y) * (1.0 - smoothstep(front, front + 0.06, y));
		float across = 1.0 - smoothstep(0.35, 1.0, abs(c.x));
		a = band * across * (0.6 + 0.4 * noise(vec2(c.x * 5.0, y * 6.0 - TIME * 3.0))) * (1.0 - smoothstep(0.75, 1.0, t));
		core = band * band * across;
	}
	if (mode == 7) {
		vec2 flow = c * 3.0 + vec2(TIME * 0.25, -TIME * 0.18);
		float n = noise(flow) * 0.6 + noise(flow * 2.3 - TIME * 0.4) * 0.4;
		float body = soft_edge(c, r, 0.6, 0.3);
		float bubbles = smoothstep(0.72, 0.9, noise(c * 9.0 + vec2(0.0, TIME * 0.8)));
		a = body * (0.32 + 0.38 * n + bubbles * 0.35) * life_fade(0.06, 0.92);
		core = bubbles + body * smoothstep(0.55, 0.95, r) * 0.4;
	} else if (mode == 8) {
		float body = soft_edge(c, r, 0.7, 0.15);
		float fillr = mix(0.05, 1.0, t);
		float charge = smoothstep(fillr, fillr - 0.25, r);
		float runes = 0.6 + 0.4 * noise(vec2(atan(c.y, c.x) * 8.0 + TIME, r * 6.0));
		a = body * (0.2 + charge * 0.55 * runes + smoothstep(0.7, 1.0, r) * 0.35);
		core = charge * runes;
	} else if (mode == 9) {
		float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
		float shimmer = noise(UV * vec2(18.0, 9.0) + vec2(TIME * 0.6, TIME * 0.3));
		a = (fres * 0.85 + 0.06 + shimmer * fres * 0.3) * life_fade(0.08, 0.9);
		core = fres * fres;
	} else if (mode == 10) {
		float v = UV.y;
		float streak = smoothstep(0.55, 0.85, noise(vec2(UV.x * 14.0, v * 3.0 + TIME * 1.6)));
		a = streak * smoothstep(0.0, 0.35, v) * smoothstep(1.0, 0.75, v) * 0.9 * life_fade(0.1, 0.88);
		core = streak * 0.5;
	}
	if (mode == 11) {
		float v = UV.y;
		float spiral = sin((UV.x * 3.0 + (1.0 - v) * 2.2 - TIME * 1.8) * 6.2831853);
		float bands = smoothstep(0.2, 0.9, spiral) * (0.65 + 0.35 * noise(vec2(UV.x * 12.0, v * 6.0 - TIME * 3.0)));
		float dust = noise(vec2(UV.x * 20.0 - TIME * 4.0, v * 10.0)) * 0.25;
		a = (bands + dust) * smoothstep(0.0, 0.15, v) * smoothstep(1.0, 0.8, v) * life_fade(0.08, 0.9);
		core = bands * smoothstep(0.4, 1.0, spiral);
	} else if (mode == 12) {
		float ang = atan(c.y, c.x) / 6.2831853 + 0.5;
		float n_links = 14.0;
		float link = fract(ang * n_links);
		float odd = mod(floor(ang * n_links), 2.0);
		vec2 lp = vec2((link - 0.5) * 2.0, (r - 0.7) / mix(0.16, 0.07, odd));
		float e = length(lp);
		float metal = (1.0 - smoothstep(0.75, 0.95, e)) * smoothstep(0.3, 0.5, e);
		a = metal * life_fade(0.08, 0.92);
		core = metal * smoothstep(-0.5, 0.8, lp.y - lp.x * 0.3);
	} else if (mode == 13) {
		float ang = atan(c.x, -c.y);
		float sweep = mix(-angle, angle, smoothstep(0.0, 0.35, t));
		float inside = 1.0 - smoothstep(angle - 0.05, angle + 0.05, abs(ang));
		float blade = exp(-pow((ang - sweep) * 5.0, 2.0)) * smoothstep(0.35, 0.8, r) * (1.0 - smoothstep(0.92, 1.0, r));
		float swept = step(ang, sweep) * smoothstep(0.2, 0.9, r) * (1.0 - smoothstep(0.85, 1.0, r));
		float n = 0.65 + 0.35 * noise(vec2(ang * 4.0, r * 6.0 - TIME * 2.0));
		a = inside * (blade * (1.0 - smoothstep(0.35, 0.6, t)) + swept * 0.35 * n) * (1.0 - smoothstep(0.55, 1.0, t));
		core = blade;
	} else if (mode == 14) {
		float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
		vec2 cell = floor(UV * vec2(9.0, 5.0));
		float facet = hash(cell);
		a = (0.28 + facet * 0.18 + fres * 0.55) * life_fade(0.06, 0.92);
		core = fres * 0.7 + step(0.82, facet) * 0.4;
	}
	if (mode == 15) {
		float track = exp(-pow((r - 0.6) / 0.05, 2.0));  // D-300: vòng tròn mảnh các sao chạy theo (kiểu Dota)
		a = track * 0.45;
		core = track * 0.3;
		for (int k = 0; k < 3; k++) {
			float ang = TIME * 2.4 + float(k) * 2.0944;
			vec2 d = c - vec2(cos(ang), sin(ang)) * 0.6;
			float rr = length(d);
			float star_r = 0.17 * (0.62 + 0.38 * cos(5.0 * atan(d.y, d.x) + TIME * 2.0));
			float shape = 1.0 - smoothstep(star_r - 0.03, star_r + 0.03, rr);
			a += shape + exp(-rr * rr * 45.0) * 0.35;
			core += shape * (1.0 - smoothstep(0.0, star_r, rr));
		}
	}
	if (mode == 16) {
		float age = UV.x;
		float center = 0.5 + 0.28 * sin(age * 9.0 - TIME * 7.0 + phase);
		float line = exp(-pow((UV.y - center) / 0.11, 2.0));
		float wisp = 0.6 + 0.4 * noise(vec2(age * 6.0 - TIME * 3.0, phase));
		a = line * pow(1.0 - age, 1.4) * smoothstep(0.0, 0.05, age) * wisp;
		core = line * line * (1.0 - age);
	}
	if (mode == 17) {
		vec2 p = UV - 0.5;
		float ca = cos(-flow_angle);
		float sa = sin(-flow_angle);
		vec2 q = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
		a = 0.0;
		core = 0.0;
		for (int k = 0; k < 4; k++) {
			float fk = float(k);
			float yk = (fk - 1.5) * 0.11 + 0.02 * sin(fk * 2.7);
			float d = q.y - yk - 0.035 * sin(q.x * 16.0 + TIME * 11.0 + fk * 1.9) * (0.5 - q.x);
			float line = exp(-d * d / 0.00035);
			float f = fract(q.x * 1.5 + TIME * 2.4 + fk * 0.37);
			float dash = smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.5, 0.75, f));
			float back = smoothstep(0.3, -0.35, q.x) * (1.0 - smoothstep(0.42, 0.5, length(q)));
			a += line * dash * back;
			core += line * line * dash * back;
		}
	}
	ALBEDO = mix(color.rgb, edge.rgb, clamp(core, 0.0, 1.0) * 0.8);
	ALPHA = clamp(a * alpha * fade, 0.0, 1.0);
}
