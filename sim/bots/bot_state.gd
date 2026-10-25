class_name BotState
extends RefCounted
## Trạng thái bot của một hero (BOT). Gắn vào Entity.bot; nằm trong state_hash (D-30).

enum Mode { ESCAPE_TOWER, RETREAT, RECOVER, TRADE, KILL, DEFEND_BASE, FARM, JUNGLE, PUSH, RALLY, SHOP, WARD }
enum Difficulty { EASY, NORMAL, HARD }

var mode: Mode = Mode.RALLY
var difficulty: Difficulty = Difficulty.NORMAL
## Lane bot giữ (D-94: 1v1 → MID).
var lane: String = "MID"
## Điểm đang đi tới (đã gửi lệnh), INF = chưa có.
var goal: Vector2 = Vector2.INF
## Mục tiêu đang đánh (đã gửi lệnh), -1 = không.
var target_id: int = -1
## DEF-08: chỗ bắt đầu đuổi (TRADE / KILL).
var chase_origin: Vector2 = Vector2.INF
## BOT-04: tới tick này còn đánh trả.
var trade_until_tick: int = -1
## Tick gần nhất bị trúng sát thương (điều kiện `taking_damage`).
var last_hurt_tick: int = -1000
## BOT-18: đang hơn (siege) ở lần nghĩ gần nhất.
var ahead: bool = false
## D-96: vị trí và tick lần cuối thấy bot nhích đi (phát hiện kẹt).
var last_pos: Vector2 = Vector2.INF
var last_pos_tick: int = 0
## BOT-14: số lần nâng điểm đã làm theo bot_skill_order.
var upgrades_done: int = 0


## Số tick giữa hai lần bot “nghĩ” (độ trễ phản xạ).
func think_ticks() -> int:
	return [9, 6, 3][difficulty]
## BOT-22: món đã bán để lấy chỗ — coi như xong trong thứ tự lên đồ, không mua lại.
var sold: Array[StringName] = []
