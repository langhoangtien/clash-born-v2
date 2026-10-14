class_name GameEvent
extends RefCounted
## Sự kiện có kiểu phát trong tick (GAME_RULES mục EVT). World.events chỉ giữ sự kiện
## của tick vừa chạy; TriggerSystem (M3) đọc chúng.

var type: StringName
var tick: int
var source_id: int = -1
var target_id: int = -1
var amount: float = 0.0
## Lý do (vd `effect_removed`: expired, depleted, removed_by_event, dispelled, owner_died).
var reason: StringName


static func make(p_type: StringName, p_tick: int, p_source: int, p_target: int, p_amount: float = 0.0, p_reason: StringName = &"") -> GameEvent:
	var e: GameEvent = GameEvent.new()
	e.type = p_type
	e.tick = p_tick
	e.source_id = p_source
	e.target_id = p_target
	e.amount = p_amount
	e.reason = p_reason
	return e
