class_name Command
extends RefCounted
## Yêu cầu từ người chơi, bot hoặc controller (ARCHITECTURE mục 1). Không đổi trận
## trực tiếp; CommandSystem kiểm tra rồi mới thành Order (CMD-01..05).

enum Type { MOVE_TO, MOVE_DIR, STOP, ATTACK, ATTACK_AUTO, CAST, LEVEL_UP, CHOOSE_TALENT, BUY, SELL, RECALL }
enum Reject { NONE, UNKNOWN_UNIT, POINT_OUTSIDE_MAP, BAD_DIRECTION, BAD_TARGET, UNIT_DEAD,
	NOT_LEARNED, ON_COOLDOWN, NO_MANA, CANNOT_CAST, NO_SKILL_POINT, CANNOT_LEVEL,
	CANNOT_CHOOSE_TALENT, BAD_ITEM, NOT_ENOUGH_GOLD, INVENTORY_FULL, NOT_IN_SHOP, NOT_YET, SOLD_OUT, OUT_OF_STOCK }

## LEVEL_UP: ô đặc biệt = đổi điểm lấy thuộc tính (ABL-04).
const ATTRIBUTES: int = -1

var type: Type
var entity_id: int
var point: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var target_id: int = -1
## ATTACK: khóa mục tiêu (CTL-04). ATTACK_AUTO: chế độ chọn mục tiêu (Rules.AttackMode).
var lock: bool = false
var mode: int = 0
## CAST: ô kỹ năng (AbilityDef.Slot).
var slot: int = 0
## BUY: id món (SHOP-01). SELL dùng `slot` = chỉ số ô đồ 0..5.
var item_id: StringName
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


## CMB-01: đánh thường một mục tiêu (đi tới khi vào tầm); `lock` = khóa mục tiêu (CTL-04).
static func attack(id: int, target: int, lock_target: bool = false) -> Command:
	var c: Command = Command.new()
	c.type = Type.ATTACK
	c.entity_id = id
	c.target_id = target
	c.lock = lock_target
	return c


## CTL-02/03: nút đánh — chọn mục tiêu lúc áp lệnh; không có ai thì đánh gió (D-46).
static func attack_auto(id: int, attack_mode: int) -> Command:
	var c: Command = Command.new()
	c.type = Type.ATTACK_AUTO
	c.entity_id = id
	c.mode = attack_mode
	return c


## ABL-02: dùng kỹ năng ô `slot`. Tùy kiểu nhắm: `target` (UNIT), `point` (POINT), `dir` (DIRECTION).
static func cast(id: int, ability_slot: int, target: int = -1, at: Vector2 = Vector2.INF, dir: Vector2 = Vector2.ZERO) -> Command:
	var c: Command = Command.new()
	c.type = Type.CAST
	c.entity_id = id
	c.slot = ability_slot
	c.target_id = target
	c.point = at
	c.direction = dir
	return c


## ABL-04: dùng một điểm nâng kỹ năng ô `ability_slot` (hoặc ATTRIBUTES).
static func level_up(id: int, ability_slot: int) -> Command:
	var c: Command = Command.new()
	c.type = Type.LEVEL_UP
	c.entity_id = id
	c.slot = ability_slot
	return c


## TAL-01: chọn talent của kỹ năng ô `ability_slot`.
static func choose_talent(id: int, ability_slot: int) -> Command:
	var c: Command = level_up(id, ability_slot)
	c.type = Type.CHOOSE_TALENT
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
	c.target_id = target_id
	c.lock = lock
	c.mode = mode
	c.slot = slot
	c.item_id = item_id
	return c


## RCL-01: về thành (đứng kênh `recall_time` giây rồi về fountain).
static func recall(id: int) -> Command:
	var c: Command = Command.new()
	c.type = Type.RECALL
	c.entity_id = id
	return c


## SHOP-01: mua món `item` (id trong cửa hàng của trận).
static func buy(id: int, item: StringName) -> Command:
	var c: Command = Command.new()
	c.type = Type.BUY
	c.entity_id = id
	c.item_id = item
	return c


## SHOP-05: bán món ở ô đồ `index` (0..5).
static func sell(id: int, index: int) -> Command:
	var c: Command = Command.new()
	c.type = Type.SELL
	c.entity_id = id
	c.slot = index
	return c
