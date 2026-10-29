shader_type spatial;
// Nước cảnh mẫu: mép nông sáng, giữa sâu đậm (kênh A mặt nạ), gợn sáng mảnh trôi chậm. Đục, không đèn.
render_mode unshaded;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform float area = 40.0;
uniform vec3 shallow = vec3(0.16, 0.42, 0.48);
uniform vec3 deep = vec3(0.04, 0.16, 0.26);
uniform vec3 glint = vec3(0.55, 0.78, 0.80);

varying vec2 xz;

void vertex() {
	xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float d = texture(mask_tex, xz / area).a;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 0.8, d));
	float w = sin(xz.x * 1.7 + xz.y * 0.9 + TIME * 0.8 + sin(xz.y * 0.7 + TIME * 0.3) * 2.0);
	float lines = smoothstep(0.97, 1.0, w) * (1.0 - smoothstep(0.2, 0.9, d) * 0.6);
	float rim = 1.0 - smoothstep(0.0, 0.12, d);
	col = mix(col, glint, lines * 0.3 + rim * 0.45);
	ALBEDO = col;
}
