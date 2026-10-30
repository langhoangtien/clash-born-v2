shader_type spatial;
// D-178, D-180: mặt đất 3D: ảnh nền (cỏ, nền rừng, đất, đá lát) trộn theo mặt nạ của map (decor.py: R đất,
// G đá lát, B nền rừng, A bóng vẽ sẵn); mép trộn bẻ theo vân cho giống nét vẽ tay; cỏ đổi tông theo vân lớn
// để không lộ ô lặp. Sương (VIS-01) tính ngay ở đây từ các mắt phe mình (eyes = x, z, tầm nhìn theo mét).
// 6 lần đọc ảnh mỗi điểm. Không đèn. Đơn vị: mét.
render_mode unshaded, cull_back;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pave_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float grass_m = 7.0;
uniform float dirt_m = 6.0;
uniform float pave_m = 5.0;
uniform vec3 dirt_tint = vec3(0.80, 0.92, 0.98);
uniform vec3 shadow_tint = vec3(0.50, 0.60, 0.70);
uniform vec3 grass_warm = vec3(1.06, 1.02, 0.9);
// D-186: đá lát lấy sáng tối của ảnh, tô màu đá chung (cùng đá rừng): pave_tint = màu trung bình mong muốn,
// pave_luma = độ sáng trung bình của ảnh theo giá trị điểm ảnh (units_3d.json).
uniform vec3 pave_tint : source_color = vec3(0.5);
uniform float pave_luma = 0.5;
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
	col = mix(col, texture(dirt_tex, r / dirt_m).rgb * dirt_tint, smoothstep(0.35, 0.6, m.r + wobble * 0.5));
	float pl = dot(texture(pave_tex, xz / pave_m).rgb, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, pave_tint * (pl / pave_luma), smoothstep(0.4, 0.6, m.g + wobble * 0.2));
	col *= mix(vec3(1.0), shadow_tint, m.a);
	ALBEDO = mix(col, fog_color.rgb, fog_color.a * (1.0 - lit(xz)));
}
