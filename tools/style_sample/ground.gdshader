shader_type spatial;
// Mặt đất cảnh mẫu: ảnh nền Codex (cỏ, nền rừng, đất, đá lát) trộn theo mặt nạ; mép trộn bẻ theo vân cho giống
// nét vẽ tay; cỏ đọc hai cỡ xoay lệch nhau trộn theo nhiễu lớn để không lộ ô lặp; bóng vẽ sẵn. Không đèn.
render_mode unshaded;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D shadow_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pave_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float area = 40.0;
uniform float grass_m = 7.0;
uniform float dirt_m = 6.0;
uniform float pave_m = 5.0;
uniform vec3 dirt_tint = vec3(0.80, 0.92, 0.98);
uniform vec3 shadow_tint = vec3(0.50, 0.60, 0.70);

varying vec2 xz;

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec4 m = texture(mask_tex, xz / area);
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz;
	vec3 g1 = texture(grass_tex, xz / grass_m).rgb;
	vec3 g2 = texture(grass_tex, r / (grass_m * 1.7) + 0.31).rgb;
	float macro = texture(grass_tex, xz / 61.0).g;
	vec3 col = mix(g1, g2, smoothstep(0.35, 0.55, macro));
	float wobble = (dot(g1, vec3(0.33)) - 0.3) * 1.5;
	col = mix(col, texture(forest_tex, xz / grass_m).rgb, smoothstep(0.25, 0.65, m.b + wobble * 0.3));
	col = mix(col, texture(dirt_tex, r / dirt_m).rgb * dirt_tint, smoothstep(0.35, 0.6, m.r + wobble * 0.5));
	col = mix(col, texture(pave_tex, xz / pave_m).rgb, smoothstep(0.4, 0.6, m.g + wobble * 0.2));
	col *= mix(vec3(1.0), shadow_tint, texture(shadow_tex, xz / area).r);
	ALBEDO = col;
}
