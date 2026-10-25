shader_type spatial;
// Mặt đất bản 3D (D-150, D-155): bản đồ tĩnh (ảnh nướng có mipmap, theo tọa độ thế giới) nhân vân chi
// tiết, rồi phủ sương (lớp nhỏ) và lớp động (vùng chiêu, mũi nhắm, bóng chân…, alpha nhân sẵn).
// Ghép như bản 2D (trình vẽ Compatibility ghi màu sRGB thẳng). Không chiếu sáng.
render_mode unshaded, cull_back;

uniform sampler2D map_tex : filter_linear_mipmap, repeat_disable;
uniform bool has_map = false;
uniform vec2 map_size = vec2(1.0);
uniform sampler2D overlay : filter_linear, repeat_disable;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
// Độ mạnh vân mịn / vân lớn; cỡ vân (đơn vị 3D mỗi lần lặp).
uniform float fine_strength = 0.06;
uniform float broad_strength = 0.12;
uniform float fine_size = 3.2;
uniform float broad_size = 11.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}


void fragment() {
	vec3 col = has_map ? texture(map_tex, world_xz / map_size).rgb : vec3(0.0);
	float fine = texture(detail, world_xz / fine_size).r - 0.5;
	float broad = texture(detail, world_xz / broad_size + vec2(0.37, 0.71)).g - 0.5;
	col *= 1.0 + fine * fine_strength * 2.0 + broad * broad_strength * 2.0;
	vec4 f = texture(fog, UV);
	col = col * (1.0 - f.a) + f.rgb;
	vec4 o = texture(overlay, UV);
	col = col * (1.0 - o.a) + o.rgb;
	ALBEDO = col;
}
