shader_type spatial;
// D-195: khối tường thành rìa map (Terrain3D.edge_wall_mesh): mặt đứng dán ảnh castle_wall_face, mặt đỉnh
// castle_wall_top (chiếu theo trục chính của mặt). Ảnh chỉ lấy sáng tối, tô màu đá chung `tint` (cùng họ đá rừng);
// mặt đứng tối dần xuống chân, mặt quay ngược nắng tối hơn. Không đèn. Đơn vị: mét.
render_mode unshaded, cull_disabled;

uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.6);
uniform float face_luma = 0.4;
uniform float top_luma = 0.45;
uniform float meters = 4.0;
uniform vec3 sun = vec3(-0.5, 1.0, 0.55);  // = style_kit.SUN (Blender → Godot: y lên, z về nam)

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	vec3 n = abs(wnorm);
	float l;
	float shade;
	if (n.y > 0.5) {
		l = dot(texture(top_tex, wpos.xz / meters).rgb, LUMA) / top_luma;
		shade = 0.92;
	} else {
		vec2 uv = n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y);
		l = dot(texture(face_tex, uv / meters).rgb, LUMA) / face_luma;
		shade = mix(0.62, 1.0, clamp(dot(wnorm, normalize(sun)) * 0.5 + 0.6, 0.0, 1.0)) * mix(0.75, 1.0, clamp(wpos.y / 2.0, 0.0, 1.0));
	}
	ALBEDO = tint * l * shade;
}
