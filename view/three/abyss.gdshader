shader_type spatial;
// D-197: vực ngoài rìa map (kiểu Liên Quân): vách đá đổ xuống (cliff_tex chiếu theo mặt đứng) và đáy vực
// (floor_tex nhìn từ trên). Càng sâu càng chìm vào màu sương `mist`. Không đèn. Đơn vị: mét.
render_mode unshaded, cull_disabled, fog_disabled;  // sương xa của Look3D (hết ở 34 m) sẽ nuốt đáy vực — vực tự pha sương

uniform sampler2D cliff_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D floor_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 mist : source_color = vec3(0.25, 0.38, 0.5);
uniform float depth = 18.0;
uniform float cliff_m = 8.0;
uniform float floor_m = 55.0;
uniform float floor_mist = 0.35;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnorm);
	if (n.y > 0.5) {
		ALBEDO = mix(texture(floor_tex, wpos.xz / floor_m).rgb, mist, floor_mist);
	} else {
		vec2 uv = n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y);
		float t = clamp(-wpos.y / depth, 0.0, 1.0);
		ALBEDO = mix(texture(cliff_tex, uv / cliff_m).rgb, mist, smoothstep(0.1, 0.95, t) * 0.85);
	}
}
