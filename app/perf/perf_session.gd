class_name PerfSession
extends Node
## D-268: ghi log hiệu năng trong một trận khi bật "Ghi log hiệu năng" (Cài đặt). Nghe từng khung của
## FrameProfile → PerfRecorder; nối CSV ra file mỗi FLUSH_USEC; mốc bật / tắt đồ họa từ bảng chẩn đoán; hết
## trận (hoặc "Xuất log hiệu năng", hoặc rời trận) thì ghi JSON và mở bảng lưu / chép. Chỉ đọc World.

## Ghi lô CSV mỗi chừng này µs (ít lần mở file, vẫn giữ log nếu app bị tắt giữa chừng).
const FLUSH_USEC: int = 60_000_000

var world: World
var view_3d: MatchView3D
var hero: Entity
var recorder: PerfRecorder
var files: PerfFiles = PerfFiles.new()
var panel: PerfExportPanel
var _last_flush: int = 0
var _ended: bool = false


static func attach(parent: Node, w: World, v: MatchView3D, me: Entity, diag: DiagPanel) -> PerfSession:
	var s: PerfSession = PerfSession.new()
	s.name = "PerfSession"
	s.world = w
	s.view_3d = v
	s.hero = me
	parent.add_child(s)
	if diag != null:
		diag.changed.connect(s.mark)
	s.set_recording(PerfSettings.enabled())
	return s


func recording() -> bool:
	return FrameProfile.shared.frame_listener == _on_frame


func set_recording(on: bool) -> void:
	if on and recorder == null:
		recorder = PerfRecorder.new()
		recorder.meta = _meta()
		recorder.context = _context
		files.begin(Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
	FrameProfile.shared.frame_listener = _on_frame if on else Callable()


func _on_frame(frame: Dictionary, at: int) -> void:
	if world.tick == 0:
		return  # còn màn "Đang tải…" (làm nóng shader, D-260): khung dài, không phải lúc chơi
	if recorder.hist.count == 0 and _last_flush == 0:
		_last_flush = at
		recorder.start(at)  # giờ log tính từ khung chơi đầu tiên
	recorder.on_frame(frame, at)
	if at - _last_flush >= FLUSH_USEC:
		_last_flush = at
		files.flush(recorder)


func _process(_delta: float) -> void:
	if recorder != null and not _ended and world.winner >= 0:
		_ended = true
		set_recording(false)
		export_now()


func _exit_tree() -> void:
	if recording():
		FrameProfile.shared.frame_listener = Callable()
	if recorder != null and not _ended:
		files.finish(recorder)  # rời trận giữa chừng: vẫn lưu


func mark(key: StringName, value: int) -> void:
	if recorder != null:
		recorder.mark(key, value, FrameProfile.now())


## Ghi CSV + JSON trong app và mở bảng lưu / chép.
func export_now() -> void:
	if recorder == null:
		_show("Chưa ghi log: bật Cài đặt → \"Ghi log hiệu năng\" (bắt đầu ghi ngay, hoặc từ trận sau).", "")
		return
	var path: String = files.finish(recorder)
	_show(PerfReport.summary_text(recorder), "Đã lưu trong app: " + path.get_base_dir())


func _show(summary: String, status: String) -> void:
	if panel == null:
		panel = PerfExportPanel.new()
		panel.name = "PerfExportPanel"
		get_parent().get_node("Hud").add_child(panel)
		panel.save_csv.connect(func() -> void: _save(PerfReport.csv(recorder, 0), ".csv", "*.csv ; CSV"))
		panel.save_json.connect(func() -> void: _save(PerfReport.json(recorder), ".json", "*.json ; JSON"))
		panel.copy_summary.connect(_copy)
		panel.closed.connect(func() -> void: panel.visible = false)
	panel.show_report(summary, status)


func _save(text: String, ext: String, filter: String) -> void:
	if recorder != null:
		PerfFiles.save_as(text, files.base.get_file() + ext, filter, panel.set_status)


func _copy() -> void:
	if recorder != null:
		DisplayServer.clipboard_set(PerfReport.summary_text(recorder))
		panel.set_status(true, "Đã chép tóm tắt — dán vào chat")


## Bối cảnh trận lúc ghi dòng / lúc giật: bộ đếm FrameProbe + số đơn vị theo loại + bộ nhớ.
func _context() -> Dictionary:
	var c: Dictionary = FrameProfile.shared.counts.duplicate()
	var n: Dictionary = {&"heroes": 0, &"lane_creeps": 0, &"jungle": 0, &"fighting_heroes": 0}
	for e: Entity in world.entities:
		if not e.alive:
			continue
		match e.kind:
			Entity.Kind.HERO:
				n[&"heroes"] += 1
				if e.cast != null or (e.order.type == Order.Type.ATTACK and not e.order.finished):
					n[&"fighting_heroes"] += 1
			Entity.Kind.LANE_CREEP:
				n[&"lane_creeps"] += 1
			Entity.Kind.NEUTRAL:
				n[&"jungle"] += 1
	c.merge(n, true)
	c[&"mem_static_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	c[&"video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	return c


func _meta() -> Dictionary:
	var vp: Viewport = get_viewport()
	return {"version": Updater.current_name(), "device": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"graphics": GraphicsSetting.NAMES[GraphicsSetting.load_level()],
		"resolution": "%dx%d · 3D %d%%" % [vp.get_visible_rect().size.x, vp.get_visible_rect().size.y, roundi(vp.scaling_3d_scale * 100)],
		"refresh_hz": _refresh_hz(), "vsync": DisplayServer.window_get_vsync_mode(),
		"hero": String(hero.hero_def.id) if hero.hero_def != null else "", "started": Time.get_datetime_string_from_system()}


## Tần số màn hình; máy không báo được → N/A.
static func _refresh_hz() -> Variant:
	var hz: float = DisplayServer.screen_get_refresh_rate()
	return snappedf(hz, 0.1) if hz > 0.0 else "N/A"
