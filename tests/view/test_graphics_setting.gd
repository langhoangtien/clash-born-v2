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


func test_D_181_default_level_is_low() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.get_value("graphics", "level", GraphicsSetting.DEFAULT), GraphicsSetting.Level.LOW)
