class_name BenchSession
extends Node
## D-272: trận Benchmark A/B (mở từ Cài đặt ở menu). Cảnh cố định: seed trận cố định, HERO đấu FOE, cả hai do
## bot; chờ màn tải xong → tua SIM tới PREP_TICKS (lính mid đã chạm nhau, quái rừng đã ra), mỗi khung một ít
## tick để máy không treo → chạy BenchPlan: dừng SIM, đặt từng ô của bảng chẩn đoán, ghi khung vào BenchResult;
## cuối cho SIM chạy để đo CPU → lưu CSV / JSON và mở bảng lưu / chép. Chỉ đọc World ngoài việc tua / dừng SIM.

const HERO: StringName = &"duy_anh"
const FOE: StringName = &"noctis"
## 0:45 trận.
const PREP_TICKS: int = 1350
## Tick tua mỗi khung (~0,2 s SIM / khung: không treo máy, ~8 s trên máy tính bảng).
const PREP_STEP: int = 6
enum State { LOAD, PREP, RUN, DONE }

## Menu đặt trước khi vào trận; trận đọc rồi xóa.
static var requested: bool = false

var world: World
var runner: SimRunner
var diag: DiagPanel
var hero: Entity
var result: BenchResult = BenchResult.new()
var files: PerfFiles = PerfFiles.new()
var panel: PerfExportPanel
var uploader: PerfUpload
var _state: State = State.LOAD
var _t0: int = 0
var _index: int = -1
var _step_start: int = 0
var _steps: Array[Dictionary] = BenchPlan.steps()
var _scale0: int = 1
var _label: Label
## Cảnh lúc bắt đầu đo (tick, số đơn vị) — ghi vào kết quả.
var _scene_info: String = ""


static func attach(parent: Node, w: World, me: Entity, d: DiagPanel) -> BenchSession:
	requested = false
	var b: BenchSession = BenchSession.new()
	b.name = "BenchSession"
	b.world = w
	b.hero = me
	b.diag = d
	b.runner = parent.get("runner")
	parent.add_child(b)
	MatchSetup.add_bot(w, me)  # tướng mình cũng do bot: cảnh lặp lại được
	b.runner.paused = true
	b._scale0 = d.values[&"scale"]
	b._label = Label.new()
	b._label.add_theme_font_size_override("font_size", 30)
	b._label.add_theme_color_override("font_color", UiStyle.GOLD)
	b._label.position = Vector2(560, 160)
	b._label.z_index = 40
	parent.get_node("Hud").add_child(b._label)
	FrameProfile.shared.frame_listener = b._on_frame
	return b


func _process(_delta: float) -> void:
	match _state:
		State.LOAD:
			var loading: MatchLoading = get_parent().get("loading")
			_status("Đang tải…")
			if loading == null or loading.finished():
				_state = State.PREP
		State.PREP:
			_prep()
		State.RUN:
			var i: int = BenchPlan.index_at((FrameProfile.now() - _t0) / 1_000_000.0)
			if i < 0:
				_finish()
			elif i != _index:
				_enter(i)


func _prep() -> void:
	for k: int in PREP_STEP:
		if world.tick < PREP_TICKS:
			world.step()
	_status("Đang chuẩn bị cảnh đo… %d%%" % (100 * world.tick / PREP_TICKS))
	if world.tick >= PREP_TICKS:
		_state = State.RUN
		_t0 = FrameProfile.now()
		_scene_info = "seed cố định, %s đấu %s (bot), %s (tick %d), %d đơn vị" % [HERO, FOE,
			MatchHud.clock_text(world.tick), world.tick, world.entities.size()]


func _enter(i: int) -> void:
	_index = i
	var step: Dictionary = _steps[i]
	for p: StringName in BenchPlan.PARTS:
		diag.set_value(p, 0 if (step["off"] as Array).has(p) else 1)
	var sc: int = DiagPanel.SCALES.find(int(step["scale"]))
	diag.set_value(&"scale", _scale0 if int(step["scale"]) == 100 or sc < 0 else sc)
	runner.paused = not step["sim"]
	diag.set_value(&"split", 1 if step.get("split", true) else 0)  # D-276
	result.begin(step)
	_step_start = FrameProfile.now()
	_status("Đang đo (%d/%d): %s — đừng chạm màn hình" % [i + 1, _steps.size(), step["label"]])


func _on_frame(frame: Dictionary, at: int) -> void:
	if _state == State.RUN and _index >= 0 and at - _step_start >= int(BenchPlan.WARM * 1_000_000):
		result.add(frame)


func _finish() -> void:
	_state = State.DONE
	FrameProfile.shared.frame_listener = Callable()
	for p: StringName in BenchPlan.PARTS:
		diag.set_value(p, 1)
	diag.set_value(&"scale", _scale0)
	diag.set_value(&"split", 1)
	runner.paused = true
	_label.visible = false
	var meta: Dictionary = PerfSession.device_meta(get_viewport(), hero)
	meta["mode"] = "benchmark_ab"
	meta["scene"] = _scene_info
	files.begin("bench_" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
	_write(files.base + ".csv", result.csv())
	_write(files.base + ".json", result.json(meta))
	_show(result.text(meta), "Đã lưu trong app: " + ProjectSettings.globalize_path(files.base).get_base_dir(), meta)


static func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _show(summary: String, status: String, meta: Dictionary) -> void:
	panel = PerfExportPanel.new()
	panel.name = "BenchPanel"
	get_parent().get_node("Hud").add_child(panel)
	panel.save_csv.connect(func() -> void: PerfFiles.save_as(result.csv(), files.base.get_file() + ".csv", "*.csv ; CSV", panel.set_status))
	panel.save_json.connect(func() -> void: PerfFiles.save_as(result.json(meta), files.base.get_file() + ".json", "*.json ; JSON", panel.set_status))
	panel.copy_summary.connect(func() -> void:
		DisplayServer.clipboard_set(summary)
		panel.set_status(true, "Đã chép kết quả — dán vào chat"))
	uploader = PerfUpload.new()
	add_child(uploader)
	panel.upload.connect(func(note: String) -> void:
		uploader.send(&"bench", note, summary, result.data(meta), panel.set_status))  # D-287
	panel.closed.connect(func() -> void: get_tree().change_scene_to_file("res://app/main.tscn"))
	panel.show_report(summary, status, "Benchmark A/B")


func _status(text: String) -> void:
	if _label != null:
		_label.text = text


func _exit_tree() -> void:
	if FrameProfile.shared.frame_listener == _on_frame:
		FrameProfile.shared.frame_listener = Callable()
