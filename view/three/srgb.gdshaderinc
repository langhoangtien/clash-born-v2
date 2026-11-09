// D-316: màu đỉnh / màu MultiMesh (COLOR) là giá trị sRGB vẽ sẵn (style_kit.py). Compatibility (OpenGL, máy tính) vẽ thẳng
// trên sRGB; Mobile / Forward+ (Vulkan, điện thoại) tính tuyến tính rồi đổi sang sRGB khi ra màn hình → phải đổi COLOR
// sang tuyến tính, không thì đá / cây / cỏ bạc màu trên điện thoại.
vec3 srgb_in(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
#endif
}
