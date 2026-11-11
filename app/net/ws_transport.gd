class_name WsTransport
extends NetTransport
## D-337 / D-338: kênh WebSocket — máy khách (`dial`, wss://clashborn.quest/play) hoặc phía máy chủ bọc một WebSocketPeer
## đã nhận (`wrap`). Mỗi tin là một chuỗi JSON; tin lạ / quá cỡ bị bỏ.

const MAX_MESSAGE: int = 64 * 1024

var peer: WebSocketPeer


static func dial(url: String) -> WsTransport:
	var t: WsTransport = WsTransport.new()
	t.peer = WebSocketPeer.new()
	t.peer.inbound_buffer_size = 1 << 20  # M9.6: gói lệnh dồn lại lúc màn trận đang nạp
	t.peer.connect_to_url(url)
	return t


static func wrap(p: WebSocketPeer) -> WsTransport:
	var t: WsTransport = WsTransport.new()
	t.peer = p
	return t


func send(msg: Dictionary) -> void:
	if is_open():
		peer.send_text(JSON.stringify(msg))


func receive() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var raw: PackedByteArray = peer.get_packet()
		if raw.size() > MAX_MESSAGE:
			continue
		var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if d is Dictionary:
			out.append(d)
	return out


func is_open() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func connecting() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING


func closed() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_CLOSED


func close() -> void:
	peer.close()
