// D-247: vệt quét của chiêu chém (dải lưỡi liềm trên quạt): u chạy theo góc quét, v từ trong ra mép ngoài.
// `progress` đẩy đầu vệt từ 0 tới 1 + tail (vệt lướt qua rồi tan); viền ngoài sáng màu `edge`; đầu vệt sáng hơn.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.25, 0.55, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float tail = 0.55;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float head = smoothstep(progress - tail, progress, u) * (1.0 - smoothstep(progress, progress + 0.03, u));
	float radial = smoothstep(0.0, 0.55, v) * (1.0 - smoothstep(0.94, 1.0, v));
	float rim = smoothstep(0.72, 0.9, v) * (1.0 - smoothstep(0.93, 1.0, v));
	float a = head * radial * fade;
	ALBEDO = mix(color.rgb, edge.rgb, rim + 0.35 * head * head);  // phủ màu (không cộng sáng: nền đất sáng làm xanh bạc trắng)
	ALPHA = clamp(a * 2.0, 0.0, 0.95);
}
