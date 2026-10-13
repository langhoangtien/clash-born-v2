class_name Order
extends RefCounted
## Lệnh hiện tại của một đơn vị, do CommandSystem đặt (CMD-03). MovementSystem đọc nó.

enum Type { IDLE, MOVE, DIRECT }

var type: Type = Type.IDLE
var point: Vector2 = Vector2.ZERO
## Hướng đã chuẩn hóa của lệnh DIRECT (MOV-06).
var direction: Vector2 = Vector2.ZERO
## Hệ thống thực hiện lệnh đánh dấu xong (MOV-03); lệnh vẫn còn đến khi có lệnh mới.
var finished: bool = false


static func idle() -> Order:
	return Order.new()


static func direct(dir: Vector2) -> Order:
	var o: Order = Order.new()
	o.type = Type.DIRECT
	o.direction = dir.normalized()
	return o


static func move(target: Vector2) -> Order:
	var o: Order = Order.new()
	o.type = Type.MOVE
	o.point = target
	return o
