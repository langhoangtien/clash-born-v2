// D-247, D-250: vệt chém hình quạt (kiểu "vệt chém ánh sáng"): u chạy theo góc quét (0 → 1), v từ trong (0) ra mép
// ngoài (1). Lưỡi liềm sáng ở mép ngoài — dày giữa, nhọn hai đầu — hiện ra theo `progress` (0 → 1 trong lúc vung),
// mặt quạt mờ trong suốt phía sau có vài vệt tốc độ; `fade` (1 → 0) làm tan: lưỡi liềm mảnh dần rồi mất.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.43, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float rim = 0.32;    // bề dày lưỡi liềm (phần bán kính) ở giữa cung
uniform float fill = 0.22;   // độ đục mặt quạt

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float shown = 1.0 - smoothstep(progress - 0.04, progress, u);       // phần cung đã quét tới
	float lead = smoothstep(progress - 0.18, progress, u) * shown;       // đầu vệt đang quét: sáng hơn
	float taper = pow(sin(3.14159 * clamp(u, 0.0, 1.0)), 0.7);           // nhọn hai đầu
	float w = rim * taper * mix(0.35, 1.0, fade);                        // tan: lưỡi liềm mảnh dần
	float band = smoothstep(1.0 - w, 1.0 - w * 0.55, v) * (1.0 - smoothstep(0.96, 1.0, v));
	float core = smoothstep(1.0 - w * 0.45, 1.0 - w * 0.15, v) * (1.0 - smoothstep(0.95, 0.99, v));
	float streak = smoothstep(0.86, 1.0, fract(u * 9.0 + v * 2.3)) * v * 0.5;  // vệt tốc độ trên mặt quạt
	float face = (fill * v * v + streak * fill) * taper;
	float a = max(band, face) * shown * fade + lead * band * 0.3;
	vec3 c = mix(color.rgb, edge.rgb, clamp(core + lead * band * 0.5, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 0.95);
}
