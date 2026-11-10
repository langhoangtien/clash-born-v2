extends TestCase
## D-272: Benchmark A/B — kịch bản cố định (đủ → tắt một phần → đủ…), tổng hợp chênh lệch so với mốc hai bên.


func test_D_272_plan_alternates_base_and_each_part() -> void:
	var steps: Array[Dictionary] = BenchPlan.steps()
	assert_true(steps[0]["settle"], "đầu tiên chờ ổn định")
	assert_true(steps[1]["base"], "rồi đo mốc đủ đồ họa")
	var parts: Array = []
	for i: int in steps.size():
		var s: Dictionary = steps[i]
		if s.has("key") and not s["sim"]:
			parts.append(s["key"])
			assert_true(steps[i - 1]["base"] and steps[i + 1]["base"], "mỗi phần kẹp giữa hai mốc: " + str(s["key"]))
	for p: StringName in BenchPlan.PARTS:
		assert_true(parts.has(p), "có đo " + str(p))
	assert_true(steps[-1]["sim"], "cuối: SIM chạy (đo CPU)")


func test_D_272_step_at_time() -> void:
	var steps: Array[Dictionary] = BenchPlan.steps()
	assert_eq(BenchPlan.index_at(0.0), 0)
	assert_eq(BenchPlan.index_at(float(steps[0]["seconds"]) + 0.01), 1)
	assert_eq(BenchPlan.index_at(BenchPlan.total_seconds() + 1.0), -1, "hết kịch bản")


func _frames(r: BenchResult, n: int, frame_ms: float, gpu_ms: float) -> void:
	for i: int in n:
		r.add({&"frame": int(frame_ms * 1000), &"gpu": int(gpu_ms * 1000), &"process": 5000, &"render": 8000})


func test_D_272_delta_against_neighbor_bases() -> void:
	var r: BenchResult = BenchResult.new()
	r.begin({"label": "Đủ", "base": true, "sim": false})
	_frames(r, 100, 20.0, 12.0)
	r.begin({"label": "Tắt Nền ảnh", "key": &"ground", "base": false, "sim": false})
	_frames(r, 100, 17.0, 8.0)
	r.begin({"label": "Đủ", "base": true, "sim": false})
	_frames(r, 100, 21.0, 13.0)
	var c: Array[Dictionary] = r.compare()
	assert_eq(c.size(), 1)
	assert_near(float(c[0]["gpu_delta_ms"]), 8.0 - 12.5, 0.01, "so với trung bình hai mốc kề")
	assert_near(float(c[0]["frame_delta_ms"]), 17.0 - 20.5, 0.01)
	assert_true(r.text({"version": "0.1.999"}).contains("Nền ảnh"))


func test_D_272_gpu_na_when_not_measured() -> void:
	var r: BenchResult = BenchResult.new()
	r.begin({"label": "Đủ", "base": true, "sim": false})
	_frames(r, 10, 20.0, 0.0)
	assert_eq(r.rows()[0]["gpu_ms"], "N/A")


func test_D_272_csv_and_json() -> void:
	var r: BenchResult = BenchResult.new()
	r.begin({"label": "Đủ", "base": true, "sim": false})
	_frames(r, 10, 20.0, 10.0)
	var lines: PackedStringArray = r.csv().strip_edges().split("\n")
	assert_eq(lines.size(), 2, "tiêu đề + một đoạn")
	var data: Variant = JSON.parse_string(r.json({"version": "x"}))
	assert_eq(data["meta"]["version"], "x")
	assert_eq(data["segments"].size(), 1)


func _bench_scene() -> Node:
	BenchSession.requested = true
	var cfg: MatchConfig = MatchConfig.duel(BenchSession.HERO, BenchSession.FOE)
	cfg.practice = true  # MATCH-06: main.gd mở Benchmark là trận thử
	(load("res://app/match_scene.gd") as GDScript).set("config", cfg)
	var scene: Node = (load("res://app/match_scene.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.set_process(false)
	return scene


func test_D_272_session_toggles_parts_and_restores_at_end() -> void:
	var scene: Node = _bench_scene()
	var b: BenchSession = scene.get_node("BenchSession")
	assert_false(BenchSession.requested, "cờ dùng một lần")
	assert_true(scene.hero.bot != null, "tướng mình do bot (cảnh lặp lại được)")
	assert_true(scene.runner.paused, "SIM chỉ chạy khi bench cho phép")
	var diag: DiagPanel = scene.get_node("Hud/DiagPanel")
	var steps: Array[Dictionary] = BenchPlan.steps()
	var ground: int = steps.find_custom(func(s: Dictionary) -> bool: return s.get("key", &"") == &"ground")
	b._state = BenchSession.State.RUN
	b._enter(ground)
	assert_eq(diag.values[&"ground"], 0, "đoạn Tắt Nền ảnh: ô Nền ảnh tắt")
	assert_eq(diag.values[&"fog"], 1, "chỉ tắt một phần")
	b._enter(ground + 1)
	assert_eq(diag.values[&"ground"], 1, "mốc kế tiếp: bật lại")
	b._enter(steps.size() - 1)
	assert_false(scene.runner.paused, "đoạn cuối: SIM chạy")
	b._finish()
	assert_true(scene.runner.paused)
	assert_false(FrameProfile.shared.frame_listener.is_valid())
	assert_true(FileAccess.file_exists(b.files.base + ".json") and FileAccess.file_exists(b.files.base + ".csv"))
	assert_true(b.panel != null and b.panel.visible)
	var base: String = b.files.base
	scene.free()
	DirAccess.remove_absolute(base + ".csv")
	DirAccess.remove_absolute(base + ".json")
