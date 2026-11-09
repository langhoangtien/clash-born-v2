shader_type spatial;
// D-178: nước: chỗ nông thấy đáy sông (ảnh), xuống sâu xanh lam sẫm (độ sâu: kênh L ảnh `water` của decor.py, D-180).
// D-313 (người chơi: bờ thẳng tắp, đi trên sông như trên băng): lưới nước phủ rộng hơn mép luật; mép nhìn thấy = trường
// bờ (kênh A, 0,5 = mép luật) + nhiễu → bờ lượn, viền bọt mảnh; nước trong hơn (thấy đáy rộng hơn), gợn nhỏ lấp lánh trôi
// theo hai hướng thay vệt sáng dài (trông như băng). Đục, không đèn. Đơn vị: mét.
render_mode unshaded;

uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform sampler2D bed_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float bed_m = 6.0;
uniform vec3 shallow_tint = vec3(0.72, 0.95, 1.0);
uniform vec3 deep = vec3(0.12, 0.30, 0.37);
uniform vec3 glint = vec3(0.70, 0.86, 0.88);
uniform vec3 foam = vec3(0.86, 0.92, 0.90);

varying vec2 xz;

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float noise(vec2 p) {  // nhiễu rẻ từ độ sáng ảnh đáy sông
	return dot(texture(bed_tex, p).rgb, vec3(0.33));
}

void fragment() {
	vec2 dd = texture(depth_tex, (xz - mask_origin) / mask_size).ra;
	float n = noise(xz / 19.0) * 1.4 - noise(xz / 4.3 + 0.37) * 0.6 - 0.25;
	float s = dd.y + n * 0.7;
	if (s < 0.5) {
		discard;
	}
	vec3 bed = texture(bed_tex, (xz + sin(xz.yx * 1.3 + TIME) * 0.06) / bed_m).rgb * shallow_tint;
	vec3 col = mix(bed, deep, smoothstep(0.1, 1.0, dd.x) * 0.78);
	float r1 = noise(xz / 2.6 + vec2(TIME * 0.035, TIME * 0.02));
	float r2 = noise(xz / 2.1 - vec2(TIME * 0.025, TIME * -0.03));
	float sparkle = smoothstep(0.74, 0.86, r1 * r2 * 2.6) * (0.6 + 0.4 * smoothstep(0.2, 0.8, dd.x));
	col = mix(col, glint, sparkle * 0.55);
	col = mix(col, foam, (1.0 - smoothstep(0.5, 0.56, s)) * 0.75);  // viền bọt mảnh ở mép
	ALBEDO = col;
}
