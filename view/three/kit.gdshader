shader_type spatial;
// D-178: cảnh vật bộ asset mới (cây, khóm lá, lau sậy): màu đỉnh đã vẽ sẵn sáng tối (style_kit.py) → không
// đèn, vẽ cả hai phía (lá một mặt).
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
}
