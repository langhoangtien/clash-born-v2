shader_type spatial;
// D-178, D-180: mặt đất 3D: ảnh nền (cỏ, nền rừng, đất, đá lát) trộn theo mặt nạ của map (decor.py: R đất,
// G đá lát, B nền rừng, A bóng vẽ sẵn); mép trộn bẻ theo vân cho giống nét vẽ tay; cỏ đổi tông theo vân lớn
// để không lộ ô lặp. Sương (VIS-01) tính ngay ở đây từ các mắt phe mình (eyes = x, z, tầm nhìn theo mét).
// D-187: đường đất rừng (kênh R) là đất nện: ảnh dirt chỉ lấy sáng tối, tô dirt_color. D-190, D-191: nền lane /
// base (kênh G) là ảnh "đất có phiến đá" Codex vẽ tay, đã chỉnh về bảng màu chung (tools/textures/recolor.py).
// Mép cỏ loang theo vân lớn.
// 6 lần đọc ảnh mỗi điểm. Không đèn. Đơn vị: mét.
render_mode unshaded, cull_back;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stones_tex : source_color, filter_linear_mipmap, repeat_enable;
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

void fragment() {
	vec4 m = texture(mask_tex, (xz - mask_origin) / mask_size);
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz;
	vec3 g = texture(grass_tex, xz / grass_m).rgb;
	float macro = texture(grass_tex, r / 61.0).g;
	vec3 col = g * mix(vec3(1.0), grass_warm, smoothstep(0.35, 0.55, macro));
	float wobble = (dot(g, vec3(0.33)) - 0.3) * 1.5;
	col = mix(col, texture(forest_tex, xz / grass_m).rgb, smoothstep(0.25, 0.65, m.b + wobble * 0.3));
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	float patch = clamp((macro - 0.447) * 14.0, -1.0, 1.0);  // vân lớn (−1…1): chỗ rêu nhiều / mòn lộ đất
	float dl = dot(texture(dirt_tex, r / dirt_m).rgb, LUMA) / dirt_luma;
	vec3 dirt = dirt_color * dl;
	col = mix(col, dirt, smoothstep(0.35, 0.62, m.r + wobble * 0.6 + patch * 0.15));
	vec3 stones = texture(stones_tex, xz / stones_m).rgb;
	col = mix(col, stones, smoothstep(0.4, 0.75, m.g + wobble * 0.3 + patch * 0.15));
	col *= mix(vec3(1.0), shadow_tint, m.a);
	ALBEDO = mix(col, fog_color.rgb, fog_color.a * (1.0 - lit(xz)));
}
