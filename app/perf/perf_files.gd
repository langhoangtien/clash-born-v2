class_name PerfFiles
extends RefCounted
## D-268: ghi log hiệu năng ra file. Trong trận: nối dòng CSV mới theo lô (APP gọi `flush` mỗi phút) vào
## user://performance_logs/ để mất app giữa chừng vẫn còn log; hết trận / xuất: thêm JSON đầy đủ. `save_as`:
## hộp "Lưu vào…" của hệ điều hành (Android: chọn Download, Drive…) — không có thì báo đường dẫn trong app.

const DIR: String = "user://performance_logs/"

## Đường dẫn gốc (không đuôi) của trận này.
var base: String = ""
var _rows_written: int = 0


func begin(stamp: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	base = DIR + "clashborn_" + stamp
	_rows_written = 0


## Nối các dòng chưa ghi vào file CSV (lô đầu kèm tiêu đề).
func flush(r: PerfRecorder) -> void:
	if base == "" or _rows_written >= r.rows.size():
		return
	var path: String = base + ".csv"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if _rows_written > 0 else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string(PerfReport.csv(r, _rows_written, _rows_written == 0))
	f.close()
	_rows_written = r.rows.size()


## Ghi nốt CSV + JSON; trả về đường dẫn JSON thật trên máy.
func finish(r: PerfRecorder) -> String:
	flush(r)
	var f: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(PerfReport.json(r))
		f.close()
	return ProjectSettings.globalize_path(base + ".json")


## Hộp lưu của hệ điều hành → ghi `text` vào chỗ người dùng chọn; báo `done(ok, message)` (gọi trễ — hộp
## lưu có thể trả lời từ luồng khác trên vài nền tảng).
static func save_as(text: String, file_name: String, filter: String, done: Callable) -> void:
	var inside: String = ProjectSettings.globalize_path(DIR)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		done.call(false, "Máy không có hộp lưu file — log ở " + inside)
		return
	var answer: Callable = func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
		if not ok or paths.is_empty():
			done.call_deferred(false, "Đã hủy lưu")
		elif _write(paths[0], text):
			done.call_deferred(true, "Đã lưu: " + paths[0])
		else:
			done.call_deferred(false, "Không ghi được vào chỗ đã chọn — log vẫn ở " + inside)
	DisplayServer.file_dialog_show("Lưu log hiệu năng", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), file_name, false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray([filter]), answer)


static func _write(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
