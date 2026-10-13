class_name Command
extends RefCounted
## Yêu cầu từ người chơi, bot hoặc controller (ARCHITECTURE mục 1). Không đổi trận
## trực tiếp; CommandSystem kiểm tra rồi mới thành Order (CMD-01..05).

enum Type { MOVE_TO, MOVE_DIR, STOP }
enum Reject { NONE, UNKNOWN_UNIT, POINT_OUTSIDE_MAP, BAD_DIRECTION }

var type: Type
var entity_id: int
var point: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
## Tick mà lệnh được áp (World điền khi áp; dùng cho nhật ký và phát lại).
var tick: int = -1
var reject_reason: Reject = Reject.NONE


static func move_to(id: int, target: Vector2) -> Command:
	var c: Command = Command.new()
	c.type = Type.MOVE_TO
	c.entity_id = id
	c.point = target
	return c


## MOV-06: đi thẳng theo hướng (joystick/WASD).
static func move_dir(id: int, dir: Vector2) -> Command:
	var c: Command = Command.new()
	c.type = Type.MOVE_DIR
	c.entity_id = id
	c.direction = dir
	return c


static func stop(id: int) -> Command:
	var c: Command = Command.new()
	c.type = Type.STOP
	c.entity_id = id
	return c


## Bản sao sạch (không mang tick / lý do từ chối) để gửi lại khi phát lại.
func copy() -> Command:
	var c: Command = Command.new()
	c.type = type
	c.entity_id = entity_id
	c.point = point
	c.direction = direction
	return c
