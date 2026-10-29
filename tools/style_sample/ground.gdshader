shader_type spatial;
// Mặt đất cảnh mẫu: 3 ảnh nền lặp (cỏ, đất, đá lát) trộn theo mặt nạ; mép trộn bẻ theo vân ảnh cỏ cho
// giống nét vẽ tay; nền rừng tối hơn; bóng vẽ sẵn; đáy sông. Không đèn.
render_mode unshaded;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D shadow_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D pave_tex : filter_linear_mipmap, repeat_enable;
uniform float area = 40.0;
uniform float tile = 7.0;
uniform vec3 forest_tint = vec3(0.62, 0.74, 0.78);
uniform vec3 shadow_tint = vec3(0.50, 0.60, 0.70);
uniform vec3 bed = vec3(0.05, 0.13, 0.18);

varying vec2 xz;

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 muv = xz / area;
	vec4 m = texture(mask_tex, muv);
	vec2 t = xz / tile;
	vec3 grass = texture(grass_tex, t).rgb;
	vec3 big = texture(grass_tex, t * 0.23 + 0.37).rgb;
	float wobble = (dot(big, vec3(0.33)) - 0.33) * 1.6;
	vec3 col = grass;
	col *= mix(vec3(1.0), forest_tint, smoothstep(0.2, 0.7, m.b + wobble * 0.3));
	col = mix(col, texture(dirt_tex, t * 0.8).rgb, smoothstep(0.35, 0.6, m.r + wobble * 0.5));
	col = mix(col, texture(pave_tex, t * 0.6).rgb, smoothstep(0.4, 0.6, m.g + wobble * 0.2));
	col *= mix(vec3(1.0), shadow_tint, texture(shadow_tex, muv).r);
	col = mix(col, bed, smoothstep(0.0, 0.15, m.a));
	ALBEDO = col;
}
