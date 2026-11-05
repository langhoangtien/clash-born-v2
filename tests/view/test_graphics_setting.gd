extends TestCase
## D-181 (đo trên MatePad, D-180): mức đồ họa = độ phân giải cảnh 3D: Thấp 50% (mặc định), Vừa 75%, Cao 100%;
## MSAA không đổi FPS cũng không thấy khác trên máy thử → không dùng.


func test_D_181_levels_set_3d_scale_without_msaa() -> void:
	var vp: SubViewport = SubViewport.new()
	var want: Array[float] = [0.5, 0.75, 1.0]
	for level: int in GraphicsSetting.NAMES.size():
		GraphicsSetting.apply(vp, level as GraphicsSetting.Level)
		assert_near(vp.scaling_3d_scale, want[level], 0.001, "mức %s" % GraphicsSetting.NAMES[level])
		assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED, "không MSAA")
	vp.free()


## D-259 (đo trên máy tính bảng: Vulkan 48–52 fps ở 100%, đổi độ phân giải ảnh hưởng ít): mặc định Cao 100%.
func test_D_259_default_level_is_high() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.get_value("graphics", "level", GraphicsSetting.DEFAULT), GraphicsSetting.Level.HIGH)


## D-258 (đo trên máy tính bảng: chỉ độ phân giải đổi FPS, tắt mọi phần vẽ không lên): bỏ chỉnh màu của
## Environment — trên Compatibility nó thêm một lượt xử lý toàn màn hình mỗi khung, tốn theo độ phân giải.
func test_D_258_environment_has_no_fullscreen_adjustment() -> void:
	var e: Environment = Look3D.environment()
	assert_false(e.adjustment_enabled, "không chỉnh màu toàn màn hình")
	assert_false(e.glow_enabled, "không glow")


## D-258: trình vẽ Mobile (Vulkan) phóng cảnh 3D bằng FSR (sắc nét khi vẽ dưới 100%); Compatibility chỉ có bilinear.
func test_D_258_upscale_mode_by_renderer() -> void:
	assert_eq(GraphicsSetting.upscale_mode("mobile"), Viewport.SCALING_3D_MODE_FSR)
	assert_eq(GraphicsSetting.upscale_mode("gl_compatibility"), Viewport.SCALING_3D_MODE_BILINEAR)
