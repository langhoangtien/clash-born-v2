class_name PerfExportPanel
extends Control
## D-268: bảng log hiệu năng (hết trận hoặc khi bấm "Xuất log hiệu năng"): tóm tắt ngắn, nút lưu CSV / JSON
## (hộp "Lưu vào…" của máy), chép tóm tắt để dán vào chat, gửi lên máy chủ kèm ghi chú (D-287), đóng. Chỉ báo bằng
## tín hiệu; APP ghi file / gửi.

signal save_csv
signal save_json
signal copy_summary
signal upload(note: String)
signal closed

var _title: Label
var _summary: Label
var _status: Label
var _note: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(1300, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = _label("Log hiệu năng", 40, UiStyle.GOLD)
	box.add_child(_title)
	_summary = _label("", 20, UiStyle.TEXT)
	box.add_child(_summary)
	_status = _label("", 22, Color(0.6, 0.9, 1.0))
	box.add_child(_status)
	_note = LineEdit.new()
	_note.name = "Note"
	_note.placeholder_text = "Ghi chú khi gửi (không bắt buộc): máy nóng, lag lúc giao tranh…"
	_note.max_length = PerfUpload.NOTE_MAX
	_note.custom_minimum_size = Vector2(0, 64)
	_note.add_theme_font_size_override("font_size", 24)
	box.add_child(_note)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for b: Array in [["SaveCsv", "Lưu CSV…", save_csv], ["SaveJson", "Lưu JSON…", save_json],
			["Copy", "Chép tóm tắt", copy_summary], ["Close", "Đóng", closed]]:
		row.add_child(_button(b[0], b[1], b[2]))
	var send: Button = _button("Upload", "Gửi lên máy chủ", Signal())
	send.custom_minimum_size.x = 280
	send.pressed.connect(func() -> void: upload.emit(_note.text))
	row.add_child(send)
	row.move_child(send, 0)


func show_report(summary: String, status: String, title: String = "Log hiệu năng") -> void:
	_title.text = title
	_summary.text = summary
	_status.text = status
	visible = true


func set_status(_ok: bool, message: String) -> void:
	_status.text = message


func _label(text: String, size_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _button(node_name: String, text: String, pressed: Signal) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(220, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.2, 0.34), Color(0.45, 0.65, 1.0), 3, 12))
	b.add_theme_stylebox_override("hover", UiStyle.box(Color(0.16, 0.26, 0.42), Color(0.6, 0.8, 1.0), 3, 12))
	b.add_theme_stylebox_override("pressed", UiStyle.box(Color(0.1, 0.16, 0.28), Color(0.45, 0.65, 1.0), 3, 12))
	if not pressed.is_null():
		b.pressed.connect(func() -> void: pressed.emit())
	return b
