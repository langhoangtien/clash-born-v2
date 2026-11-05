// D-252: ảnh hiệu ứng vẽ tay (trắng xám) nằm phẳng trên mặt đất, tô màu theo độ sáng: chỗ sáng nhất giữ `edge`
// (lõi trắng), còn lại `color` (vd xanh) — như mẫu "vệt chém ánh sáng". `tint` tắt thì giữ màu gốc của ảnh (bụi đất).
// Bảng khung `frames` × `frames`, khung đang vẽ `frame`; `fade` làm mờ cả ảnh.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(0.12, 0.45, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform bool tint = true;
uniform float frames = 1.0;
uniform float frame = 0.0;
uniform float fade = 1.0;
uniform float core = 0.55;  // độ sáng bắt đầu chuyển sang màu lõi

void fragment() {
	vec2 cell = vec2(mod(frame, frames), floor(frame / frames));
	vec4 t = texture(tex, (UV + cell) / frames);
	float lum = max(t.r, max(t.g, t.b));
	ALBEDO = tint ? mix(color.rgb, edge.rgb, smoothstep(core, 1.0, lum)) : t.rgb;
	ALPHA = clamp(t.a * fade * (tint ? 1.25 : 1.0), 0.0, 1.0);
}
