shader_type spatial;
// D-178: nước: chỗ nông thấy đáy sông (ảnh), xuống sâu xanh lam sẫm (độ sâu: ảnh `water` của decor.py, D-180); mép bờ
// sáng, gợn sáng mảnh trôi chậm. Đục, không đèn. Đơn vị: mét.
render_mode unshaded;

uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform sampler2D bed_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float bed_m = 6.0;
uniform vec3 shallow_tint = vec3(0.75, 1.0, 1.05);
uniform vec3 deep = vec3(0.10, 0.28, 0.36);
uniform vec3 glint = vec3(0.45, 0.70, 0.74);

varying vec2 xz;

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float d = texture(depth_tex, (xz - mask_origin) / mask_size).r;
	vec3 bed = texture(bed_tex, (xz + sin(xz.yx * 1.3 + TIME) * 0.08) / bed_m).rgb * shallow_tint;
	vec3 col = mix(bed, deep, smoothstep(0.05, 0.75, d));
	float w = sin(xz.x * 1.7 + xz.y * 0.9 + TIME * 0.8 + sin(xz.y * 0.7 + TIME * 0.3) * 2.0);
	float lines = smoothstep(0.97, 1.0, w) * (1.0 - smoothstep(0.2, 0.9, d) * 0.6);
	float rim = 1.0 - smoothstep(0.0, 0.1, d);
	col = mix(col, glint, lines * 0.25 + rim * 0.35);
	ALBEDO = col;
}
