class_name ZonePainter
extends RefCounted
## Vẽ vùng kỹ năng trên bản đồ (tầng VIEW, chỉ đọc World).


## ABL-06/16: vòng báo trước của vùng có độ trễ (lõi lớn dần tới lúc nổ) và vùng tồn tại
## (nhấp nháy), vẽ dưới đơn vị; cả hai đội đều thấy.
static func draw(ci: CanvasItem, world: World) -> void:
	for p: PendingArea in world.pending_areas:
		if p.radius <= 0.0:
			continue
		var col: Color = (UnitsView.BLUE if p.team == 0 else UnitsView.RED).lightened(0.35)
		var t: float = clampf(float(world.tick - p.start_tick) / maxf(1.0, p.due_tick - p.start_tick), 0.0, 1.0)
		ci.draw_circle(p.center, p.radius, Color(col, 0.12))
		ci.draw_circle(p.center, p.radius * t, Color(col, 0.28))
		ci.draw_arc(p.center, p.radius, 0, TAU, 64, Color(col, 0.9), 4.0, true)
	for z: ActiveZone in world.zones:
		var col: Color = Color(1.0, 0.45, 0.1).lerp(UnitsView.BLUE if z.team == 0 else UnitsView.RED, 0.2)
		if world.tick < z.start_tick:
			ci.draw_arc(z.center, z.radius, 0, TAU, 64, Color(col, 0.5), 2.0, true)
			continue
		var phase: float = float(world.tick - z.start_tick) / z.interval_ticks
		var pulse: float = 1.0 - (phase - floorf(phase))
		ci.draw_circle(z.center, z.radius, Color(col, 0.22 + 0.2 * pulse))
		ci.draw_arc(z.center, z.radius, 0, TAU, 64, Color(col, 0.85), 3.0, true)
