shader_type spatial;
// Cảnh vật bộ asset mới: màu đỉnh đã vẽ sẵn sáng tối (style_kit.py) → không đèn, vẽ cả hai phía.
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
}
