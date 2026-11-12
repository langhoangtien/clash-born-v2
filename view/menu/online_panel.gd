class_name OnlinePanel
extends Control
## M9.6 (D-344, NET-11): bảng Chơi online ở menu — tạo phòng (1v1 / 2v2 / 3v3) hoặc nhập mã, phòng chờ (hai đội, chọn đội
## và tướng, chủ phòng đổi số người / bắt đầu). Chỉ hiện và báo yêu cầu qua `request(tin)` (đúng tin của máy chủ phòng:
## create / join / team / pick / size / start / leave) hoặc tin riêng của APP: `server {id}` (NET-14: 0 = Tự động); APP
## (OnlineMenu) gửi đi rồi gọi show_*. Hàng máy chủ (độ trễ từng máy, lựa chọn) đọc từ `servers` / `choice` / `current`.

signal request(msg: Dictionary)
signal closed

const BOX: Vector2 = Vector2(900, 900)
const HEADER: float = 80.0  ## dải đầu khung của UiStyle.panel
const SIZES: Array[int] = [1, 2, 3]
const TEAM_NAMES: Array[String] = ["Đội Xanh", "Đội Đỏ"]

var screen: String = "status"
## NET-14 (D-401): kết quả đo [{id, name, state, rtt_ms}], lựa chọn (0 = Tự động), máy đang nối (-1 = chưa).
var servers: Array[Dictionary] = []
var choice: int = 0
var current: int = -1
var _box: VBoxContainer
var _center: CenterContainer
var _message: Label
var _code: LineEdit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	if _center == null:
		show_status("")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	UiStyle.panel(self, Rect2((size - BOX) * 0.5, BOX))


## Một dòng chữ (đang nối, lỗi nối, cần đăng nhập…) + hàng máy chủ khi đã đo (chọn được máy khác ngay).
func show_status(text: String, error: bool = false) -> void:
	_begin("status", "Chơi online")
	if not servers.is_empty():
		_server_block()
	_end(text, error)


## Đã nối: tạo phòng hoặc vào bằng mã.
func show_home(player: String) -> void:
	_begin("home", "Chơi online")
	_box.add_child(_label("Bạn: " + player, 26, UiStyle.TEXT, false))
	_server_block()
	_box.add_child(_label("Tạo phòng — số người mỗi đội (ô trống là bot)", 22, UiStyle.DIM, false))
	var row: HBoxContainer = _row()
	for n: int in SIZES:
		row.add_child(_button("%d vs %d" % [n, n], {"t": "create", "size": n}, true))
	_box.add_child(_label("Vào phòng của bạn bè", 22, UiStyle.DIM, false))
	_code = LineEdit.new()
	_code.placeholder_text = "Mã phòng (%d số)" % RoomLobby.CODE_LEN
	_code.max_length = RoomLobby.CODE_LEN
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER  # D-345
	_code.custom_minimum_size = Vector2(0, 64)
	_code.add_theme_font_size_override("font_size", 30)
	_box.add_child(_code)
	var join: Button = _button("Vào phòng", {}, true)
	join.pressed.connect(func() -> void: request.emit({"t": "join", "code": _code.text.strip_edges()}))
	_box.add_child(join)
	_end("", false)


## Phòng chờ: `room` = trạng thái máy chủ gửi (RoomLobby.state), `me` = mã của mình, `heroes` = tướng được chọn.
func show_room(room: Dictionary, me: int, heroes: Array[StringName]) -> void:
	var host: bool = int(room.get("host", -1)) == me
	_begin("room", "Phòng " + String(room.get("code", "")))
	var n: int = int(room.get("size", 1))
	var line: String = "%d vs %d · gửi mã cho bạn bè · ô trống là bot (Thường)" % [n, n]
	if current >= 0:  # NET-14: chung dòng — thêm dòng thì tiêu đề đè dải đầu khung (3v3)
		line += " · " + server_line().trim_prefix("Máy chủ: ")
	_box.add_child(_label(line, 22, UiStyle.DIM, false))
	var mine: Dictionary = {}
	var taken: Dictionary = {}
	for m: Dictionary in room.get("members", []):
		taken[String(m.get("hero", ""))] = int(m.get("id", -1)) != me
		if int(m.get("id", -1)) == me:
			mine = m
	for team: int in 2:
		_box.add_child(_label(TEAM_NAMES[team] + ":  " + team_line(room, team), 24, UiStyle.TEXT, false))
	var row: HBoxContainer = _row()
	row.add_child(_button("Sang " + TEAM_NAMES[1 - int(mine.get("team", 0))], {"t": "team", "team": 1 - int(mine.get("team", 0))}, false))
	if host:
		for k: int in SIZES:
			row.add_child(_button("%dv%d" % [k, k], {"t": "size", "size": k}, k == n))
	_box.add_child(_label("Chọn tướng", 22, UiStyle.DIM, false))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	_box.add_child(grid)
	for h: StringName in heroes:
		var b: Button = _button(String(h).capitalize(), {"t": "pick", "hero": String(h)}, String(mine.get("hero", "")) == String(h))
		b.disabled = taken.get(String(h), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	if host:
		_box.add_child(_button("BẮT ĐẦU", {"t": "start"}, true))
	else:
		_box.add_child(_label("Chờ chủ phòng bắt đầu…", 22, UiStyle.DIM, false))
	_box.add_child(_button("Rời phòng", {"t": "leave"}, false))
	_end("", false)


## NET-14: "Máy chủ: Singapore · 45 ms" + hàng nút Tự động / từng máy (độ trễ hoặc lỗi), nút đang chọn màu vàng.
func _server_block() -> void:
	if current >= 0:
		_box.add_child(_label(server_line(), 22, UiStyle.DIM, false))
	var row: HBoxContainer = _row()
	row.add_child(_button("Tự động", {"t": "server", "id": 0}, choice == 0, 20))
	for r: Dictionary in servers:
		row.add_child(_button(RoomServers.label(r), {"t": "server", "id": int(r["id"])}, choice == int(r["id"]), 20))


func server_line() -> String:
	for r: Dictionary in servers:
		if int(r["id"]) == current:
			return "Máy chủ: " + RoomServers.label(r)
	return "Máy chủ: #%d" % current


## "Lăng (Gorran) ★, Minh (chưa chọn)" — ★ = chủ phòng.
static func team_line(room: Dictionary, team: int) -> String:
	var parts: PackedStringArray = []
	for m: Dictionary in room.get("members", []):
		if int(m.get("team", 0)) == team:
			var hero: String = String(m.get("hero", ""))
			parts.append("%s (%s)%s" % [m.get("name", "?"), hero.capitalize() if hero != "" else "chưa chọn",
				" ★" if int(m.get("id", -1)) == int(room.get("host", -2)) else ""])
	var free: int = int(room.get("size", 1)) - parts.size()
	for i: int in maxi(free, 0):
		parts.append("bot")
	return ", ".join(parts)


func say(text: String, error: bool) -> void:
	if _message != null:
		_message.text = text
		_message.add_theme_color_override("font_color", UiStyle.RED_TEXT if error else UiStyle.DIM)


func _begin(s: String, title: String) -> void:
	screen = s
	if _center != null:
		remove_child(_center)
		_center.queue_free()
	_center = CenterContainer.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.offset_top = HEADER  # căn giữa phần dưới dải đầu khung (UiStyle.panel) — màn phòng 3v3 cao, tiêu đề không đè dải
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(BOX.x - 96, 0)
	_center.add_child(_box)
	_box.add_child(_label(title, 40, UiStyle.GOLD, true))


func _end(text: String, error: bool) -> void:
	_message = _label("", 22, UiStyle.DIM, false)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_message)
	say(text, error)
	var close: Button = _button("Đóng", {}, false)
	close.pressed.connect(func() -> void: closed.emit())
	_box.add_child(close)
	queue_redraw()


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	return row


func _label(text: String, size_px: int, color: Color, bold: bool) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiStyle.serif(bold))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


## Nút gửi `msg` khi bấm ({} = APP tự nối); `gold` = nút chính / đang chọn.
func _button(text: String, msg: Dictionary, gold: bool, font_px: int = 26) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", UiStyle.serif(true))
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.GOLD_DEEP if gold else UiStyle.CARD, UiStyle.GOLD if gold else UiStyle.LINE, 2, 10))
	b.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.GOLD_DEEP if gold else UiStyle.CARD_HI, UiStyle.GOLD, 2, 10))
	b.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.CARD, UiStyle.GOLD, 2, 10))
	b.add_theme_stylebox_override("disabled", UiStyle.box(Color(UiStyle.CARD, 0.4), UiStyle.LINE, 1, 10))
	if not msg.is_empty():
		b.pressed.connect(func() -> void:
			say("Đang gửi…", false)
			request.emit(msg))
	return b
