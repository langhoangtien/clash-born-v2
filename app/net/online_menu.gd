class_name OnlineMenu
extends Node
## M9.6 (D-344): APP — nối bảng Chơi online (OnlinePanel) với phiên mạng (OnlineSession): mở bảng → cần đăng nhập + tên
## trong game → nối máy chủ phòng, chuyển tin sảnh lên bảng; máy chủ chào vào trận → giao phiên cho màn trận rồi đổi màn.
## `dial` thay được trong test (mạng giả).

signal match_ready(session: OnlineSession)

var panel: OnlinePanel
var session: OnlineSession
## func() -> NetTransport — mặc định WebSocket tới máy chủ thật.
var dial: Callable = func() -> NetTransport: return WsTransport.dial(OnlineSession.URL)
var version: Callable = NetVersion.fingerprint


func attach(p: OnlinePanel) -> void:
	panel = p
	panel.request.connect(_on_request)
	panel.closed.connect(close)


## Mở bảng (nút Online ở menu).
func open() -> void:
	panel.visible = true
	if not AccountClient.signed_in():
		panel.show_status("Cần đăng nhập để chơi online (nút Đăng nhập ở trên)", true)
		return
	if String(AccountClient.account.get("name", "")) == "":
		panel.show_status(OnlineSession.error_text("NO_NAME"), true)
		return
	if session != null and session.stage == "lobby":
		_show_lobby()
		return
	panel.show_status("Đang nối máy chủ…")
	await get_tree().process_frame  # hiện chữ trước khi tính dấu vân tay SIM (~0,5–1 s trên điện thoại)
	session = OnlineSession.new(dial.call(), AccountClient.token, version.call())


func close() -> void:
	if session != null:
		session.send({"t": "leave"})
		session.close()
		session = null
	panel.visible = false


func _process(_delta: float) -> void:
	if session == null or session.stage == "game":
		return
	for msg: Dictionary in session.poll():
		_on_message(msg)


func _on_message(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"hello_ok", "lobby":
			_show_lobby()
		"error":
			var text: String = OnlineSession.error_text(String(msg.get("code", "")))
			if String(msg.get("for", "")) == "hello":
				panel.show_status(text, true)
			else:
				panel.say(text, true)
		"welcome":
			var s: OnlineSession = session
			session = null  # màn trận giữ phiên từ đây
			match_ready.emit(s)
		"closed":
			if panel.screen != "status":
				panel.show_status("Mất kết nối máy chủ phòng — đóng bảng rồi mở lại", true)
			session = null


func _show_lobby() -> void:
	if session.room.is_empty():
		panel.show_home(session.name)
	else:
		panel.show_room(session.room, session.peer_id, session.heroes)


func _on_request(msg: Dictionary) -> void:
	if session != null:
		session.send(msg)
