class_name AccountPanel
extends Control
## D-333 (ROADMAP ACC.3): bảng Tài khoản ở menu — đăng nhập / đăng ký / xác minh email / quên mật khẩu / Google / đặt tên /
## đăng xuất. Chỉ hiện form và báo yêu cầu qua `request(action, body)`; APP (main.gd) gửi bằng AccountClient rồi gọi
## `on_reply` / `set_account`. Ô nhập là LineEdit thật (bàn phím điện thoại).

signal request(action: String, body: Dictionary)
signal closed

## Mỗi màn: tiêu đề, các ô nhập, các nút [chữ, việc] — việc "@màn" là chuyển màn, còn lại là yêu cầu gửi máy chủ.
const SCREENS: Dictionary = {
	"login": ["Đăng nhập", ["email", "password"], [["Đăng nhập", "login"], ["Đăng nhập bằng Google", "google/start"],
		["Tạo tài khoản", "@register"], ["Quên mật khẩu", "@reset"]]],
	"register": ["Tạo tài khoản", ["email", "password", "password2"], [["Đăng ký", "register"], ["Quay lại", "@login"]]],
	"verify": ["Xác minh email", ["code"], [["Xác minh", "verify"], ["Gửi lại mã", "resend"], ["Quay lại", "@login"]]],
	"reset": ["Quên mật khẩu", ["email"], [["Gửi mã", "reset"], ["Quay lại", "@login"]]],
	"reset2": ["Đặt mật khẩu mới", ["code", "password", "password2"], [["Đặt mật khẩu", "reset_finish"], ["Quay lại", "@login"]]],
	"google": ["Đăng nhập Google", [], [["Hủy", "google/cancel"]]],
	"name": ["Tên trong game", ["name"], [["Lưu tên", "name"]]],
	"profile": ["Tài khoản", [], [["Lịch sử trận", "history"], ["Đổi tên", "@name"], ["Đổi mật khẩu", "@password"],
		["Đăng xuất", "logout"], ["Xóa tài khoản", "@delete"]]],
	"password": ["Đổi mật khẩu", ["old", "password", "password2"], [["Lưu mật khẩu", "password"], ["Quay lại", "@profile"]]],
	"password_set": ["Đặt mật khẩu", ["password", "password2"], [["Lưu mật khẩu", "password"], ["Quay lại", "@profile"]]],
	"history": ["Lịch sử trận", [], [["Xem trên web", "open_web"], ["Quay lại", "@profile"]]],
	"delete": ["Xóa tài khoản?", [], [["Xóa vĩnh viễn", "delete"], ["Quay lại", "@profile"]]],
}
const HINTS: Dictionary = {"email": "Email", "password": "Mật khẩu (ít nhất 8 ký tự)", "password2": "Nhập lại mật khẩu",
	"old": "Mật khẩu hiện tại",
	"code": "Mã 6 số trong mail", "name": "3–16 ký tự, không trùng người khác"}
const BOX: Vector2 = Vector2(760, 820)

var screen: String = "login"
var email: String = ""          ## email đang dùng (giữ qua các màn xác minh / đặt lại)
var account: Dictionary = {}
var _fields: Dictionary[String, LineEdit] = {}
var _box: VBoxContainer
var _center: CenterContainer
var _message: Label
var _matches: Array = []        ## D-334: trận gần nhất (màn Lịch sử trận)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	show_screen("profile" if not account.is_empty() else "login")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	UiStyle.panel(self, Rect2((size - BOX) * 0.5, BOX))


func set_account(a: Dictionary) -> void:
	account = a
	if not a.is_empty():
		show_screen("name" if String(a.get("name", "")) == "" else "profile")
	elif screen in ["profile", "name", "delete"]:
		show_screen("login")


func show_screen(s: String, message: String = "", error: bool = false) -> void:
	if s == "password" and not account.get("has_password", true):
		s = "password_set"  # D-339: tài khoản chỉ đăng nhập Google — đặt mật khẩu lần đầu
	screen = s
	_build()
	_say(message, error)


## Trả lời của máy chủ cho `action` → chuyển màn / báo lỗi.
func on_reply(action: String, ok: bool, code: String, message: String, data: Dictionary = {}) -> void:
	if not ok:
		if code == "NOT_VERIFIED":
			request.emit("resend", {"email": email})
			show_screen("verify", "Email chưa xác minh — đã gửi lại mã vào " + email)
		else:
			_say(message, true)
		return
	match action:
		"register", "resend":
			show_screen("verify", "Đã gửi mã tới " + email + " (xem cả thư rác)")
		"reset":
			show_screen("reset2", "Nếu email có tài khoản, mã đã được gửi tới " + email)
		"google/start":
			show_screen("google", "Đã mở trình duyệt — đăng nhập Google rồi quay lại đây")
		"password":
			account = data if data.has("id") else account
			show_screen("profile", "Đã đổi mật khẩu — các máy khác đã bị đăng xuất")
		"history":
			_matches = data.get("matches", [])
			show_screen("history", "" if not _matches.is_empty() else "Chưa có trận nào (trận khi đã đăng nhập, có đội thắng, không phải trận thử)")


func _submit(action: String) -> void:
	if action.begins_with("@"):
		show_screen(action.substr(1))
		return
	var body: Dictionary = {}
	for key: String in _fields:
		body[key] = _fields[key].text.strip_edges() if not key in ["password", "password2", "old"] else _fields[key].text
	if body.has("password2"):
		if body["password2"] != body["password"]:
			_say("Hai mật khẩu không giống nhau", true)
			return
		body.erase("password2")
	if body.has("email"):
		email = String(body["email"])
	elif action in ["verify", "resend", "reset_finish"]:
		body["email"] = email
	if action == "google/cancel":  # APP ngừng hỏi máy chủ
		show_screen("login")
	else:
		_say("Đang gửi…", false)
	request.emit(action, body)


func _build() -> void:
	if _center != null:
		remove_child(_center)
		_center.queue_free()
	_fields.clear()
	_center = CenterContainer.new()  # luôn giữa màn, theo cỡ màn hình
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(BOX.x - 96, 0)
	_center.add_child(_box)
	var spec: Array = SCREENS[screen]
	_box.add_child(_label(spec[0], 40, UiStyle.GOLD, true))
	if screen == "profile":
		_box.add_child(_label("%s\n%s" % [account.get("name", ""), account.get("email", "")], 28, UiStyle.TEXT, false))
	if screen == "history":
		var list: MatchHistoryList = MatchHistoryList.new()  # D-343: cả hai đội, cuộn được
		_box.add_child(list)
		list.show_matches(_matches)
	if screen == "delete":
		var warn: Label = _label("Xóa vĩnh viễn tài khoản %s (tên, email, đăng nhập Google). Không hoàn tác được." % account.get("email", ""),
			24, UiStyle.RED_TEXT, false)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(warn)
	for key: String in spec[1]:
		_fields[key] = _line(key)
		_box.add_child(_fields[key])
	_message = _label("", 22, UiStyle.DIM, false)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_message)
	for b: Array in spec[2]:
		_box.add_child(_button(b[0], b[1]))
	var close: Button = _button("Đóng", "")
	close.pressed.connect(func() -> void: closed.emit())
	_box.add_child(close)
	queue_redraw()


func _say(text: String, error: bool) -> void:
	if _message != null:
		_message.text = text
		_message.add_theme_color_override("font_color", UiStyle.RED_TEXT if error else UiStyle.DIM)


func _line(key: String) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.placeholder_text = HINTS[key]
	e.secret = key.begins_with("password") or key == "old"
	e.custom_minimum_size = Vector2(0, 64)
	e.add_theme_font_size_override("font_size", 28)
	e.virtual_keyboard_type = {"email": LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS, "code": LineEdit.KEYBOARD_TYPE_NUMBER}.get(
		key, LineEdit.KEYBOARD_TYPE_PASSWORD if e.secret else LineEdit.KEYBOARD_TYPE_DEFAULT)
	if key == "email":
		e.text = email
	return e


func _label(text: String, size_px: int, color: Color, bold: bool) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", UiStyle.serif(bold))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_override("font", UiStyle.serif(true))
	b.add_theme_font_size_override("font_size", 26)
	var gold: bool = action != "" and not action.begins_with("@")
	b.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.GOLD_DEEP if gold else UiStyle.CARD, UiStyle.GOLD if gold else UiStyle.LINE, 2, 10))
	b.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.GOLD_DEEP if gold else UiStyle.CARD_HI, UiStyle.GOLD, 2, 10))
	b.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.CARD, UiStyle.GOLD, 2, 10))
	if action != "":
		b.pressed.connect(_submit.bind(action))
	return b
