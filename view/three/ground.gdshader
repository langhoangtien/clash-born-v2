shader_type spatial;
// Mặt đất bản 3D (D-150): ảnh lớp 2D (map, sương, vùng…) nhân thêm vân chi tiết theo tọa độ thế giới
// cho bớt phẳng, cộng tối nhẹ ở rìa xa. Không chiếu sáng (màu map giữ như bản 2D).
render_mode unshaded, cull_back;

uniform sampler2D layer : source_color, filter_linear, repeat_disable;
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
	vec3 col = texture(layer, UV).rgb;
	float fine = texture(detail, world_xz / fine_size).r - 0.5;
	float broad = texture(detail, world_xz / broad_size + vec2(0.37, 0.71)).g - 0.5;
	col *= 1.0 + fine * fine_strength * 2.0 + broad * broad_strength * 2.0;
	ALBEDO = col;
}
