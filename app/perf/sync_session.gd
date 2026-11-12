class_name SyncSession
extends Control
## M9.3 (D-336): nút "Kiểm tra đồng bộ" ở menu — chạy SyncCheck (trận 3v3 bot cố định, không vẽ) từng đoạn mỗi khung
## (giữ khung hình mượt, hiện tiến độ), xong gửi lên máy chủ thành báo cáo S-xxxx để so với máy chủ x86. Không đổi gì
## trong game; bấm Đóng giữa chừng thì dừng.

const BUDGET_MS: int = 12  ## thời gian chạy SIM mỗi khung
const CHUNK: int = 10      ## tick mỗi lần hỏi đồng hồ

var _check: SyncCheck
var _label: Label
var _upload: PerfUpload
var _t0: int = 0
var _sim_usec: int = 0     ## thời gian thật nằm trong SIM (không tính chờ khung hình) — tốc độ tua của máy này (M9.8)
var _retry: Button
var _data: Dictionary = {}
var _summary: String = ""


static func open(parent: Node) -> SyncSession:
	var s: SyncSession = SyncSession.new()
	s.name = "SyncSession"
	parent.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UiStyle.serif(true))
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_label)
	var close: Button = Button.new()
	close.text = "Đóng"
	close.custom_minimum_size = Vector2(260, 64)
	close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(queue_free)
	_retry = Button.new()
	_retry.text = "Gửi lại"
	_retry.custom_minimum_size = Vector2(260, 64)
	_retry.add_theme_font_size_override("font_size", 28)
	_retry.visible = false
	_retry.pressed.connect(_post)
	box.add_child(_retry)
	box.add_child(close)
	_upload = PerfUpload.new()
	add_child(_upload)
	_label.text = "Đang chuẩn bị…"
	_t0 = Time.get_ticks_msec()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BG)


func _process(_delta: float) -> void:
	if _check == null:
		_check = SyncCheck.new()  # khung đầu đã vẽ chữ "Đang chuẩn bị…" rồi mới dựng trận
		return
	if _check.done():
		return
	var start: int = Time.get_ticks_usec()
	while not _check.done() and Time.get_ticks_usec() - start < BUDGET_MS * 1000:
		_check.advance(CHUNK)
	_sim_usec += Time.get_ticks_usec() - start
	_label.text = "Kiểm tra đồng bộ… %d%%" % int(_check.progress() * 100.0)
	if _check.done():
		_send()


func _send() -> void:
	var meta: Dictionary = {"version": Updater.current_name(), "device": OS.get_model_name(),
		"os": OS.get_name() + " " + OS.get_version(), "arch": Engine.get_architecture_name(), "ms": Time.get_ticks_msec() - _t0,
		"sim_ms": _sim_usec / 1000}
	_data = _check.result(meta)
	_summary = "Kiểm tra đồng bộ · %s · %s · %d giây trận trong %.1f giây · mã cuối %s" % [meta["version"], meta["device"],
		_check.seconds.size(), _sim_usec / 1e6, String(_check.seconds[-1]["hash"]).left(16) if not _check.seconds.is_empty() else "-"]
	_post()


## Gửi (lỗi mạng / máy chủ thì hiện nút Gửi lại — không phải chạy lại cả phút).
func _post() -> void:
	_retry.visible = false
	_upload.send(&"sync", "", _summary, _data, func(ok: bool, message: String) -> void:
		_label.text = "Đã chạy xong · " + message.replace(" · bấm Gửi để thử lại", "")
		_retry.visible = not ok)
