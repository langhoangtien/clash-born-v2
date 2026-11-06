extends TestCase
## D-268: phiên ghi log hiệu năng trong trận — bật trong Cài đặt thì ghi, hết trận lưu CSV + JSON và mở bảng
## lưu / chép; mốc bật / tắt từ bảng chẩn đoán; tắt thì không nghe khung nào.

const SCENE: String = "res://app/match_scene.tscn"


func _scene(on: bool) -> Node:
	PerfSettings.save_enabled(on)
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.set_process(false)
	return scene


func _frames(n: int) -> void:
	var p: FrameProfile = FrameProfile.shared
	var t: int = FrameProfile.now() + 10_000_000
	for i: int in n:
		t += 20_000
		p.add(&"sim", t - 3000, t)
		p.next_frame(t)


func test_D_268_records_and_saves_at_match_end() -> void:
	var was: bool = PerfSettings.enabled()
	var scene: Node = _scene(true)
	var s: PerfSession = scene.settings.perf
	assert_true(s.recording(), "bật ghi log: nghe từng khung")
	_frames(30)
	assert_eq(s.recorder.total_frames, 0, "trận chưa chạy (đang tải): không tính khung")
	scene.world.tick = 1
	_frames(60)
	assert_true(s.recorder.total_frames >= 59)
	assert_true(s.recorder.rows.size() >= 2, "mẫu 0,5 s")
	scene.get_node("Hud/DiagPanel").changed.emit(&"fog", 0)
	assert_eq(s.recorder.markers.size(), 1, "mốc bật / tắt đồ họa")
	scene.world.winner = 0
	s._process(0.0)
	assert_false(s.recording(), "hết trận thôi ghi")
	assert_true(FileAccess.file_exists(s.files.base + ".csv"))
	assert_true(FileAccess.file_exists(s.files.base + ".json"))
	assert_true(s.panel != null and s.panel.visible, "mở bảng lưu / chép")
	var base: String = s.files.base
	scene.free()
	DirAccess.remove_absolute(base + ".csv")
	DirAccess.remove_absolute(base + ".json")
	PerfSettings.save_enabled(was)


func test_D_268_off_by_default_costs_nothing() -> void:
	var was: bool = PerfSettings.enabled()
	var scene: Node = _scene(false)
	var s: PerfSession = scene.settings.perf
	assert_false(s.recording())
	assert_false(FrameProfile.shared.frame_listener.is_valid(), "tắt: không ai nghe khung")
	s.export_now()
	assert_true(s.panel.visible, "xuất khi chưa bật: bảng báo cách bật")
	scene.free()
	assert_false(FrameProfile.shared.frame_listener.is_valid())
	PerfSettings.save_enabled(was)
