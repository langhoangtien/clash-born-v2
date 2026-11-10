class_name NetTransport
extends RefCounted
## D-337 (NET): kênh gửi / nhận tin nhắn của trận online — tách khỏi SIM. Tin nhắn là Dictionary, đi trên dây dạng
## chuỗi JSON (mọi máy nhận cùng chuỗi → cùng số thực sau khi đọc). Bản thật: WebSocket (M9.5); bản giả: LoopbackNet
## (test, mô phỏng mạng). Đổi sang ENet / UDP sau chỉ cần thêm một lớp con.


func send(_msg: Dictionary) -> void:
	pass


## Tin đã đến (theo thứ tự gửi).
func receive() -> Array[Dictionary]:
	return []


func is_open() -> bool:
	return false


func close() -> void:
	pass
