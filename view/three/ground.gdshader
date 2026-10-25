shader_type spatial;
// Mặt đất bản 3D (D-150): ảnh lớp 2D (map, sương, vùng…) nhân thêm vân chi tiết theo tọa độ thế giới
// cho bớt phẳng. D-160: nơi có nước (water_mask) gợn sóng chạy theo thời gian — nhân vào màu đã có
// sương nên vùng tối vẫn tối. Không chiếu sáng (màu map giữ như bản 2D).
render_mode unshaded, cull_back;

uniform sampler2D layer : source_color, filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D water_mask : filter_linear_mipmap, repeat_disable;
uniform bool has_water = false;
uniform vec2 map_size = vec2(1.0);
// Độ mạnh vân mịn / vân lớn; cỡ vân (đơn vị 3D mỗi lần lặp).
uniform float fine_strength = 0.06;
uniform float broad_strength = 0.12;
uniform float fine_size = 3.2;
uniform float broad_size = 11.0;
// Sóng: cỡ, tốc độ trôi, độ sáng gợn, độ lấp lánh đỉnh sóng.
uniform float wave_size = 4.5;
uniform float wave_speed = 0.06;
uniform float wave_strength = 0.09;
uniform float glint = 0.18;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 col = texture(layer, UV).rgb;
	float fine = texture(detail, world_xz / fine_size).r - 0.5;
	float broad = texture(detail, world_xz / broad_size + vec2(0.37, 0.71)).g - 0.5;
	float water = has_water ? texture(water_mask, world_xz / map_size).r : 0.0;
	col *= 1.0 + (fine * fine_strength * 2.0 + broad * broad_strength * 2.0) * (1.0 - water);
	if (water > 0.01) {
		vec2 p = world_xz / wave_size;
		float a = texture(detail, p + vec2(TIME * wave_speed, TIME * wave_speed * 0.6)).r;
		float b = texture(detail, p * 1.37 - vec2(TIME * wave_speed * 0.7, -TIME * wave_speed * 0.4)).r;
		float w = a + b - 1.0;
		col *= 1.0 + water * w * wave_strength * 2.0;
		col += col * water * glint * smoothstep(0.24, 0.38, w);
	}
	ALBEDO = col;
}
