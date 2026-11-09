shader_type spatial;
// D-313: vòng gợn nước quanh chân đơn vị đang lội (Wading3D): 2 vòng lan ra rồi mờ, pha riêng (INSTANCE_CUSTOM.r),
// đậm theo độ ngập (INSTANCE_CUSTOM.g). Không đèn, trong suốt.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.86, 0.95, 0.97);
uniform float period = 1.4;

varying vec2 info;

void vertex() {
	info = INSTANCE_CUSTOM.rg;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = 0.0;
	for (int k = 0; k < 2; k++) {
		float t = fract(TIME / period + info.x + float(k) * 0.5);
		float ring = 0.25 + t * 0.7;
		a += (1.0 - smoothstep(0.0, 0.07, abs(r - ring))) * (1.0 - t);
	}
	ALBEDO = color;
	ALPHA = clamp(a, 0.0, 1.0) * 0.55 * info.y * (1.0 - smoothstep(0.85, 1.0, r));
}
