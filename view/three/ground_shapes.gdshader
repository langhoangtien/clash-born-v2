shader_type spatial;
// D-180: hình phủ mặt đất (GroundCanvas) — mỗi hình là một ô vuông [-1, 1] của MultiMesh, shader cắt theo
// INSTANCE_CUSTOM: x = kiểu (0 chữ nhật đầy, 1 đĩa / vành / quạt, 2 tam giác nửa dưới), y = bán kính trong
// (tỉ lệ), z = góc đầu, w = độ mở (rad, ≥ 2π là cả vòng). Màu theo COLOR. Không đèn, không ghi chiều sâu.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

varying vec2 p;
varying vec4 shape;

void vertex() {
	p = VERTEX.xz;
	shape = INSTANCE_CUSTOM;
}

void fragment() {
	float a = 1.0;
	if (shape.x > 1.5) {
		vec2 st = p * 0.5 + 0.5;
		if (st.x + st.y > 1.0) {
			discard;
		}
	} else if (shape.x > 0.5) {
		float d = length(p);
		float aa = fwidth(d) * 0.75;
		a = 1.0 - smoothstep(1.0 - aa, 1.0, d);
		if (shape.y > 0.0) {
			a *= smoothstep(shape.y - aa, shape.y, d);
		}
		if (shape.w < 6.2831) {
			float t = mod(atan(p.y, p.x) - shape.z, 6.2831853);
			if (t > shape.w) {
				discard;
			}
		}
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
}
