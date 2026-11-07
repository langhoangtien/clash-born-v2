class_name Updater
extends Node
## Tự cập nhật bản thử Android (D-148). Mở app → tải version.json (clashborn.quest, GitHub dự phòng — D-281); có versionCode lớn
## hơn bản đang chạy thì hiện nút "Cập nhật". Bấm → tải APK vào bộ nhớ app rồi mở màn cài của
## Android (lần đầu Android hỏi cho phép cài từ nguồn này), sau khi kiểm sha256. Lỗi → mở link APK bằng trình duyệt.
## Bản đang chạy đọc từ res://app/build.json (tools/build_android.sh ghi lúc build; không có = 0).

## D-281: hỏi VPS clashborn.quest trước (D-278); không trả lời thì GitHub Pages (dự phòng thời gian chuyển).
const SITES: Array[String] = ["https://clashborn.quest/", "https://langhoangtien.github.io/clash-born-v2/"]
const BUILD_INFO: String = "res://app/build.json"

var button: Button
var _http: HTTPRequest
var _apk_path: String = ""
var _latest: Dictionary = {}
## Nguồn đang dùng (chỉ số trong SITES) — nguồn đã trả version.json.
var _site: int = 0


## Mã bản đang chạy (0 nếu không rõ, ví dụ chạy từ editor).
static func current_code() -> int:
	if not FileAccess.file_exists(BUILD_INFO):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO))
	return int(data.get("code", 0)) if data is Dictionary else 0


## D-267: tên bản đang chạy (vd "0.1.449"), rỗng nếu không rõ (chạy từ editor).
static func current_name() -> String:
	if not FileAccess.file_exists(BUILD_INFO):
		return ""
	return version_name_from(JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO)))


static func version_name_from(data: Variant) -> String:
	return String(data.get("name", "")) if data is Dictionary else ""


## D-281: địa chỉ APK — `apk` trong version.json tương đối (theo nguồn) hoặc đầy đủ; thiếu thì tên cũ.
static func apk_url(site: String, latest: Dictionary) -> String:
	var apk: String = String(latest.get("apk", "clashborn.apk"))
	return apk if apk.begins_with("http") else site + apk


## D-281: file tải về khớp sha256 trong version.json (thiếu sha256 — version.json cũ — thì cho qua).
static func verified(path: String, latest: Dictionary) -> bool:
	var want: String = String(latest.get("sha256", "")).to_lower()
	return want.is_empty() or FileAccess.get_sha256(path) == want


## Có nên mời cập nhật: chỉ khi biết bản đang chạy và bản mới lớn hơn.
static func is_newer(latest: Dictionary, current: int) -> bool:
	return current > 0 and int(latest.get("code", 0)) > current


static func enabled() -> bool:
	return OS.get_name() == "Android"


## Gắn vào `parent` (màn chọn tướng): nút nằm góc trên phải, ẩn tới khi có bản mới.
func attach(parent: Control) -> void:
	button = Button.new()
	button.visible = false
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.45, 0.2), Color(0.5, 0.95, 0.55), 3, 12))
	button.add_theme_stylebox_override("hover", UiStyle.box(Color(0.16, 0.55, 0.25), Color(0.6, 1.0, 0.65), 3, 12))
	button.add_theme_stylebox_override("pressed", UiStyle.box(Color(0.1, 0.35, 0.16), Color(0.5, 0.95, 0.55), 3, 12))
	button.pressed.connect(_download)
	parent.add_child(button)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -460.0
	button.offset_right = -20.0
	button.offset_top = 16.0
	button.offset_bottom = 80.0
	_http = HTTPRequest.new()
	add_child(_http)
	if enabled():
		_check()


func _check() -> void:
	_http.request_completed.connect(_on_version, CONNECT_ONE_SHOT)
	# Thêm tham số thời gian để không lấy bản version.json cũ trong bộ đệm.
	if _http.request(SITES[_site] + "version.json?t=%d" % Time.get_unix_time_from_system()) != OK:
		_next_site()


## D-281: nguồn này không trả lời → hỏi nguồn kế tiếp.
func _next_site() -> void:
	_site += 1
	if _site < SITES.size():
		_check()


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if code == 200 else null
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		_next_site()
		return
	if is_newer(data, current_code()):
		_latest = data
		button.text = "Có bản mới %s · Cập nhật" % data.get("name", "")
		button.visible = true


func _download() -> void:
	if not _apk_path.is_empty():
		return
	_apk_path = OS.get_user_data_dir().path_join("update.apk")
	_http.download_file = _apk_path
	_http.request_completed.connect(_on_apk, CONNECT_ONE_SHOT)
	if _http.request(apk_url(SITES[_site], _latest) + "?t=%d" % Time.get_unix_time_from_system()) != OK:
		_fallback()


func _process(_delta: float) -> void:
	if _apk_path.is_empty() or _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		return
	var total: int = _http.get_body_size()
	if total > 0:
		button.text = "Đang tải… %d%%" % int(100.0 * _http.get_downloaded_bytes() / total)


func _on_apk(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fallback()
		return
	if not verified(_apk_path, _latest):  # D-281: file hỏng / bị tráo — không cài
		DirAccess.remove_absolute(_apk_path)
		_apk_path = ""
		button.text = "Tải lỗi (sai mã kiểm tra) · Thử lại"
		return
	button.text = "Đang mở màn cài…"
	if OS.shell_open(_apk_path) != OK:
		_fallback()


## Không tự cài được: mở link APK bằng trình duyệt như cách cũ.
func _fallback() -> void:
	button.text = "Mở trình duyệt để tải…"
	OS.shell_open(apk_url(SITES[_site], _latest))
	_apk_path = ""
