shader_type spatial;
// D-178, D-180: mặt đất 3D: ảnh nền (cỏ, nền rừng, đất, đá lát) trộn theo mặt nạ của map (decor.py: R đất,
// G đá lát, B nền rừng, A bóng vẽ sẵn); mép trộn bẻ theo vân cho giống nét vẽ tay; cỏ đổi tông theo vân lớn
// để không lộ ô lặp. Sương (VIS-01) tính ngay ở đây từ các mắt phe mình (eyes = x, z, tầm nhìn theo mét).
// D-187: đường đất rừng (kênh R) là đất nện: ảnh dirt chỉ lấy sáng tối, tô dirt_color. D-190, D-191: nền lane /
// base (kênh G) là ảnh "đất có phiến đá" Codex vẽ tay. D-312: lane = ảnh lane_dirt (Codex T13, đất vẽ tay + cụm đá thưa).
// Mép cỏ loang theo vân lớn.
// D-310: đất cao (base) — mặt nạ base_tex (R đá lát ảnh flagstones, G rêu quanh chân trụ D-313); chỉ đọc ảnh
// đá lát khi có. 7–8 lần đọc ảnh mỗi điểm. D-311: mép đá lát chuyển qua dải đất nện rồi mới tới cỏ; đá be ấm. Không đèn. Đơn vị: mét.
render_mode unshaded, cull_back;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stones_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_tex : filter_linear, repeat_disable;
uniform sampler2D flag_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float flag_m = 5.0;
uniform vec3 moss_tint = vec3(0.62, 0.74, 0.5);  // D-313: rêu = cỏ sẫm ngả xanh rêu
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float grass_m = 7.0;
uniform float dirt_m = 6.0;
uniform float stones_m = 7.0;
// D-187: đất tô màu dirt_color theo sáng tối ảnh dirt (dirt_luma = độ sáng trung bình theo giá trị điểm ảnh).
uniform vec3 dirt_color : source_color = vec3(0.5);
uniform float dirt_luma = 0.5;
uniform vec3 shadow_tint = vec3(0.50, 0.60, 0.70);
uniform vec3 grass_warm = vec3(1.06, 1.02, 0.9);
uniform vec4 eyes[64];
uniform int eye_count = 0;
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.07, 0.6);
uniform float fog_edge = 0.8;

varying vec2 xz;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float lit(vec2 at) {
	float l = 0.0;
	for (int i = 0; i < eye_count; i++) {
		l = max(l, 1.0 - smoothstep(eyes[i].z - fog_edge, eyes[i].z, distance(at, eyes[i].xy)));
		if (l >= 1.0) {
			break;
		}
	}
	return l;
}

// D-315: chỗ base lát kín (mặt nạ base R ≥ 0,97, không rêu) chỉ cần ảnh đá lát — bỏ qua cỏ / rừng / đất / đá lane (4 lần
// đọc ảnh thay 8): người chơi thấy FPS tụt khi đứng trong base.
vec3 paved(float patch) {
	vec3 flag = texture(flag_tex, xz / flag_m).rgb;
	return mix(flag, dirt_color * 1.04, smoothstep(0.55, 1.0, patch) * 0.3);  // D-311: chỗ mòn lộ đất
}

vec3 layered(vec4 m, vec2 b, vec2 r, float macro, float patch) {
	vec3 g = texture(grass_tex, xz / grass_m).rgb;
	vec3 col = g * mix(vec3(1.0), grass_warm, smoothstep(0.35, 0.55, macro));
	float wobble = (dot(g, vec3(0.33)) - 0.3) * 1.5;
	col = mix(col, texture(forest_tex, xz / grass_m).rgb, smoothstep(0.25, 0.65, m.b + wobble * 0.3));
	float dl = dot(texture(dirt_tex, r / dirt_m).rgb, LUMA) / dirt_luma;
	vec3 dirt = dirt_color * dl * mix(0.93, 1.06, smoothstep(0.38, 0.56, macro));  // D-312: đất loang sáng / sẫm
	float de = m.r + wobble * 0.6 + patch * 0.15;
	// D-312: mép đường như ảnh mẫu — cỏ sát mép sẫm và rậm hơn, đất sát cỏ sẫm nhẹ (vệt mòn / bóng cỏ).
	col *= mix(1.0, 0.8, smoothstep(0.1, 0.33, de) * (1.0 - smoothstep(0.33, 0.5, de)));
	dirt *= mix(0.88, 1.0, smoothstep(0.5, 0.8, de));
	col = mix(col, dirt, smoothstep(0.35, 0.62, de));
	vec3 stones = texture(stones_tex, xz / stones_m).rgb;
	col = mix(col, stones, smoothstep(0.4, 0.75, m.g + wobble * 0.3 + patch * 0.15));
	if (b.r + b.g > 0.004) {
		float v = b.r + wobble * 0.35 + patch * 0.1;
		col = mix(col, dirt, smoothstep(0.06, 0.3, v) * 0.9);  // D-311: dải đất nện giữa cỏ và đá (như ảnh mẫu)
		col = mix(col, paved(patch), smoothstep(0.42, 0.62, v));
		if (b.g > 0.01) {
			col = mix(col, g * moss_tint, smoothstep(0.35, 0.8, b.g + wobble * 0.6) * 0.85);  // D-313: rêu quanh chân trụ
		}
	}
	return col;
}

void fragment() {
	vec2 uv = (xz - mask_origin) / mask_size;
	vec4 m = texture(mask_tex, uv);
	vec2 b = texture(base_tex, uv).rg;
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz;
	float macro = texture(grass_tex, r / 61.0).g;
	float patch = clamp((macro - 0.447) * 14.0, -1.0, 1.0);  // vân lớn (−1…1): chỗ rêu nhiều / mòn lộ đất
	vec3 col = b.r >= 0.97 && b.g <= 0.01 ? paved(patch) : layered(m, b, r, macro, patch);
	col *= mix(vec3(1.0), shadow_tint, m.a);
	ALBEDO = mix(col, fog_color.rgb, fog_color.a * (1.0 - lit(xz)));
}
