shader_type spatial;
// D-319: ánh lửa rất nhẹ trên nền đất quanh đống lửa — đĩa cam mờ dần ra mép, nhấp nháy theo lửa. Cộng sáng.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 glow : source_color = vec3(1.0, 0.55, 0.18);

void fragment() {
	float seed = dot(NODE_POSITION_WORLD.xz, vec2(0.37, 0.71));
	float r = length(UV - 0.5) * 2.0;
	float flicker = 0.8 + 0.12 * sin((TIME + seed) * 9.0) + 0.08 * sin((TIME + seed) * 23.0);
	ALBEDO = glow;
	ALPHA = (1.0 - smoothstep(0.0, 1.0, r)) * 0.35 * flicker;
}
