shader_type spatial;
// D-178: đá / rào / tường / tán cây: màu đỉnh vẽ sẵn sáng tối (style_kit.py) × vân ảnh chiếu theo trục chính
// của mặt (mỗi mặt phẳng một lần đọc ảnh — rẻ, mặt low-poly phẳng nên không lộ mối). Ảnh chia cho màu trung
// bình của nó: vân chỉ thêm chi tiết, tông theo màu đỉnh. luma_only: chỉ lấy sáng tối (tán cây). Không đèn.
render_mode unshaded, cull_disabled;

uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 face_mean = vec3(0.4);
uniform float meters = 3.0;
uniform float strength = 1.0;
uniform bool luma_only = false;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = abs(normalize(cross(dFdx(wpos), dFdy(wpos))));
	vec2 uv = n.y > max(n.x, n.z) ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	vec3 detail = texture(face_tex, uv / meters).rgb / face_mean;
	if (luma_only) {
		detail = vec3(dot(detail, vec3(0.3, 0.5, 0.2)));
	}
	ALBEDO = COLOR.rgb * mix(vec3(1.0), detail, strength);
}
