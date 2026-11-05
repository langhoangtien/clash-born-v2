class_name RedrawGate
extends RefCounted
## D-263: HUD chỉ vẽ lại khi nội dung hiện ra đổi. Mỗi khung bảng dựng một "khóa" (mảng các giá trị đúng như
## sẽ hiện: số đã làm tròn, chữ…); khóa giống lần trước thì khỏi `queue_redraw`.

var _last: Variant = null
var _has: bool = false


## true nếu `key` khác lần trước (hoặc là lần đầu); nhớ bản sao sâu của `key`.
func changed(key: Variant) -> bool:
	if _has and typeof(key) == typeof(_last) and key == _last:
		return false
	_has = true
	_last = (key as Array).duplicate(true) if key is Array else key
	return true
