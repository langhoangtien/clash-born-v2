extends TestCase
## D-413: trang Cài đặt của menu — chỉ tùy chọn có thật: chất lượng 3D + hiện FPS, Nhạc / Âm thanh riêng (D-414: công tắc +
## thanh âm lượng), tài khoản, công cụ đo; bấm là lưu ngay.

const PATH: String = "user://test_settings_page.cfg"


func _page() -> SettingsPage:
	AudioSettings.use_file(PATH)
	var p: SettingsPage = SettingsPage.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	p.size = Vector2(1920, 984)
	return p


func _done(p: SettingsPage) -> void:
	p.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	AudioSettings.use_file(AudioSettings.DEFAULT_PATH)


func test_D_414_settings_page_music_and_sound_separate() -> void:
	var p: SettingsPage = _page()
	p.press_at(p.section_rect(1).get_center())
	assert_eq(p.section, 1, "mục Âm thanh")
	var sfx: bool = AudioSettings.sfx_on
	p.press_at(p.toggle_rect(0).get_center())
	assert_false(AudioSettings.music_on, "công tắc Nhạc")
	assert_eq(AudioSettings.sfx_on, sfx, "tắt nhạc không đụng âm thanh")
	p.press_at(p.toggle_rect(1).get_center())
	assert_false(AudioSettings.sfx_on, "công tắc Âm thanh")
	assert_false(AudioSettings.music_on)
	var r: Rect2 = p.slider_rect(0)
	p.press_at(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.5))
	assert_near(AudioSettings.music_volume, 0.3, 0.01, "chạm thanh Nhạc → âm lượng nhạc")
	r = p.slider_rect(1)
	p.press_at(r.position + Vector2(r.size.x * 0.7, r.size.y * 0.5))
	assert_near(AudioSettings.sfx_volume, 0.7, 0.01, "thanh Âm thanh riêng")
	assert_near(AudioSettings.music_volume, 0.3, 0.01, "không đụng âm lượng nhạc")
	_done(p)


func test_D_413_settings_page_graphics_account_tools() -> void:
	var p: SettingsPage = _page()
	var got: Array[String] = []
	p.account_pressed.connect(func() -> void: got.append("account"))
	p.bench_pressed.connect(func() -> void: got.append("bench"))
	p.sync_pressed.connect(func() -> void: got.append("sync"))
	var level: int = GraphicsSetting.load_level()
	var fps: bool = GraphicsSetting.load_show_fps()
	p.press_at(p.option_rect(0, 0).get_center())
	assert_eq(GraphicsSetting.load_level(), GraphicsSetting.Level.LOW, "chất lượng Thấp lưu ngay")
	p.press_at(p.toggle_rect(1).get_center())
	assert_eq(GraphicsSetting.load_show_fps(), not fps, "hiện FPS")
	GraphicsSetting.save_level(level as GraphicsSetting.Level)
	GraphicsSetting.save_show_fps(fps)
	p.press_at(p.section_rect(3).get_center())
	p.press_at(p.button_rect(0).get_center())
	p.press_at(p.section_rect(4).get_center())
	var perf: bool = PerfSettings.enabled()
	p.press_at(p.toggle_rect(0).get_center())
	assert_eq(PerfSettings.enabled(), not perf, "ghi log hiệu năng")
	PerfSettings.save_enabled(perf)
	p.press_at(p.button_rect(1).get_center())
	p.press_at(p.button_rect(2).get_center())
	assert_eq(got, ["account", "bench", "sync"] as Array[String])
	_done(p)
