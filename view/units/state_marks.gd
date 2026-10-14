class_name StateMarks
extends RefCounted
## Dấu hiệu trạng thái trên hình tạm (M3.2): choáng (sao quay trên đầu), trói (vòng chân),
## câm lặng, cấm đánh, bất tử, ma, bị chậm. Chỉ đọc trạng thái SIM.

const S := UnitState.Id


## Có hiệu ứng debuff làm giảm tốc chạy.
static func is_slowed(e: Entity) -> bool:
	for inst: EffectInstance in e.effects:
		if not inst.def.tags.has(&"debuff"):
			continue
		for m: ModifierDef in inst.def.modifiers:
			if m.stat == &"movement_speed" and m.op == ModifierDef.Op.MULTIPLY:
				return true
	return false


## `height`: chiều cao hình; dấu trên đầu vẽ phía trên thanh máu.
static func draw(ci: CanvasItem, e: Entity, at: Vector2, height: float, tick: int) -> void:
	var r: float = e.radius
	if is_slowed(e):
		ci.draw_arc(at, r * 1.15, 0, TAU, 24, Color(0.45, 0.75, 1.0, 0.9), 4.0, true)
	for inst: EffectInstance in e.effects:
		if inst.absorb_left > 0.0:  # khiên (EFF-06)
			ci.draw_arc(at - Vector2(0, r), r * 1.5, 0, TAU, 32, Color(0.5, 0.9, 1.0, 0.9), 5.0, true)
			break
	if Rules.has_state(e, S.ROOTED):
		ci.draw_arc(at, r * 1.35, 0, TAU, 24, Color(0.35, 0.8, 0.3), 5.0, true)
	if Rules.has_state(e, S.INVULNERABLE):
		ci.draw_arc(at - Vector2(0, r), r * 1.6, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9), 4.0, true)
	if Rules.has_state(e, S.GHOST):
		ci.draw_circle(at - Vector2(0, r), r * 1.4, Color(0.7, 1.0, 0.8, 0.25))
	var top: Vector2 = at - Vector2(0, height + 38)
	if Rules.has_state(e, S.STUNNED):
		for i: int in range(3):
			var angle: float = tick * 0.25 + i * TAU / 3.0
			ci.draw_circle(top + Vector2(cos(angle) * r * 1.1, sin(angle) * r * 0.4), r * 0.32, Color(1.0, 0.9, 0.2))
	if Rules.has_state(e, S.SILENCED):
		ci.draw_arc(top, r * 0.55, 0, TAU, 16, Color(0.75, 0.45, 1.0), 4.0, true)
		ci.draw_line(top + Vector2(-r, -r) * 0.4, top + Vector2(r, r) * 0.4, Color(0.75, 0.45, 1.0), 4.0)
	if Rules.has_state(e, S.DISARMED):
		ci.draw_line(at + Vector2(-r, -r * 1.6), at + Vector2(r, -r * 0.4), Color(1, 0.3, 0.3), 4.0)
		ci.draw_line(at + Vector2(r, -r * 1.6), at + Vector2(-r, -r * 0.4), Color(1, 0.3, 0.3), 4.0)
