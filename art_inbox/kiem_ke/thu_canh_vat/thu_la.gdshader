shader_type spatial;
// D-361 (bản thử, chưa vào game): tán lá / bụi / hoa lá — như kit_tex (màu đỉnh × vân ảnh chiếu theo trục chính của mặt,
// chỉ lấy sáng tối) + kéo tông: giảm bão hòa `sat`, nhân sáng `value`, pha về màu `tint` theo `tint_mix`. Không đèn.
render_mode unshaded, cull_disabled;
#include "res://view/three/srgb.gdshaderinc"

uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 face_mean = vec3(0.4);
uniform float meters = 2.5;
uniform float strength = 0.6;
uniform float sat = 0.72;
uniform float value = 0.86;
uniform vec3 tint = vec3(0.42, 0.48, 0.27);  // giá trị sRGB
uniform float tint_mix = 0.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = abs(normalize(cross(dFdx(wpos), dFdy(wpos))));
	vec2 uv = n.y > max(n.x, n.z) ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	float detail = dot(texture(face_tex, uv / meters).rgb / face_mean, vec3(0.3, 0.5, 0.2));
	vec3 c = COLOR.rgb;  // kéo tông trên giá trị sRGB (như mắt thấy), rồi mới đổi sang tuyến tính
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(vec3(l), c, sat) * value;
	c = mix(c, tint * (l * value / dot(tint, vec3(0.3, 0.5, 0.2))), tint_mix);
	c = srgb_in(clamp(c, 0.0, 1.0));
	ALBEDO = c * mix(1.0, detail, strength);
}
