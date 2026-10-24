class_name GameEvent
extends RefCounted
## Sự kiện có kiểu phát trong tick (GAME_RULES mục EVT). World.events chỉ giữ sự kiện
## của tick vừa chạy; TriggerSystem (M3) đọc chúng.

var type: StringName
var tick: int
var source_id: int = -1
var target_id: int = -1
var amount: float = 0.0
## attack_landed: sát thương đòn trước giáp / chặn (đã nhân chí mạng) — `event.raw_damage` (D-141).
var raw: float = 0.0
## Lý do (vd `effect_removed`: expired, depleted, removed_by_event, dispelled, owner_died).
var reason: StringName
## Số thứ tự toàn trận (World cấp) và tầng trigger đã sinh ra nó (EFF-04; 0 = sự kiện gốc).
var seq: int = 0
var depth: int = 0
## `effect_removed`: bản hiệu ứng vừa bị gỡ (điều kiện this_effect_*).
var effect: EffectInstance


static func make(p_type: StringName, p_tick: int, p_source: int, p_target: int, p_amount: float = 0.0, p_reason: StringName = &"") -> GameEvent:
	var e: GameEvent = GameEvent.new()
	e.type = p_type
	e.tick = p_tick
	e.source_id = p_source
	e.target_id = p_target
	e.amount = p_amount
	e.reason = p_reason
	return e
