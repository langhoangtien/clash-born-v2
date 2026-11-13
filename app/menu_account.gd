class_name MenuAccount
extends RefCounted
## D-333 / D-413: tài khoản ở menu — AccountClient (mạng, lưu phiên) + AccountPanel (form) nối qua tín hiệu; tên tài khoản
## trên thanh trên của MenuShell; đăng nhập rồi thì hỏi lịch sử trận để Trang chủ hiện "Trận gần đây" (D-334).

var client: AccountClient
var panel: AccountPanel
var shell: MenuShell
var home: HomePage
var _auto_history: bool = false  ## lịch sử hỏi cho Trang chủ (không mở màn Lịch sử trong bảng tài khoản)


static func attach(parent: Node, s: MenuShell, h: HomePage) -> MenuAccount:
	var a: MenuAccount = MenuAccount.new()
	a.shell = s
	a.home = h
	a.client = AccountClient.new()
	a.client.name = "Account"
	parent.add_child(a.client)
	a.panel = AccountPanel.new()
	a.panel.name = "AccountPanel"
	a.panel.visible = false
	parent.add_child(a.panel)
	a.panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	a.client.changed.connect(a.refresh)
	a.client.replied.connect(a._on_reply)
	a.panel.request.connect(a._on_request)
	a.panel.closed.connect(func() -> void: a.panel.visible = false)
	s.account_pressed.connect(a.open)
	h.recent_pressed.connect(func() -> void:  # Trận gần đây → bảng tài khoản, màn Lịch sử trận
		a.open()
		a.client.send("history", {}))
	a.refresh()
	return a


func open() -> void:
	panel.visible = true


## Tên trên thanh trên; đăng nhập → hỏi lịch sử trận cho thẻ Trận gần đây; đăng xuất → ẩn thẻ.
func refresh() -> void:
	var name: String = String(AccountClient.account.get("name", "")) if AccountClient.signed_in() else ""
	shell.account_name = ("Đặt tên" if name == "" else name) if AccountClient.signed_in() else ""
	shell.queue_redraw()
	panel.set_account(AccountClient.account)
	if AccountClient.signed_in():
		_auto_history = not client.busy()
		client.send("history", {})
	else:
		home.recent = []
		home.queue_redraw()


func _on_reply(action: String, ok: bool, code: String, message: String, data: Dictionary) -> void:
	if action == "history" and ok:
		home.recent = recent_lines(data.get("matches", []))
		home.queue_redraw()
	if action == "history" and _auto_history:
		_auto_history = false
		return
	panel.on_reply(action, ok, code, message, data)


## Thẻ Trận gần đây: [dòng chính, dòng phụ] của trận mới nhất (rỗng = không có trận).
static func recent_lines(matches: Array) -> Array[String]:
	if matches.is_empty() or not matches[0] is Dictionary:
		return []
	var l: Array[String] = MatchHistoryList.lines(matches[0])
	return [l[0], l[1] if l.size() > 1 else ""]


func _on_request(action: String, body: Dictionary) -> void:
	if action == "google/cancel":
		client.cancel_google()
	elif action == "open_web":  # D-334: trang người chơi trên clashborn.quest/stats/
		OS.shell_open(Updater.SITES[0] + "stats/player.html?name=" + String(AccountClient.account.get("name", "")).uri_encode())
	elif action == "google/start":
		client.google()
	else:
		client.send(action, body)
