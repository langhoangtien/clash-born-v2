class_name AimIndicator
extends Node
## Vẽ trên map khi đang kéo nhắm chiêu (M3.8): vòng tầm quanh hero và chỗ chiêu sẽ trúng
## (vùng tròn tại điểm, đường theo hướng, hoặc vùng quanh hero với chiêu không chọn mục tiêu).
## Chỉ đọc dữ liệu APP đặt vào; MatchView3D gọi paint vào GroundCanvas mỗi khung (D-180).

var active: bool = false
var origin: Vector2 = Vector2.ZERO
var reach: float = 0.0
## Điểm chiêu nhắm tới (đã kẹp trong tầm), bán kính vùng (0 = không có), kiểu nhắm.
var target: Vector2 = Vector2.ZERO
var area_radius: float = 0.0
var width: float = 0.0
## ABL-20: chiêu hướng có góc quạt (độ) thì vẽ hình quạt bán kính `reach`.
var cone_angle: float = 0.0
var targeting: AbilityDef.Targeting = AbilityDef.Targeting.NO_TARGET
## D-108: chiêu chọn đơn vị — vị trí kẻ sẽ bị chọn (INF = chưa có ai), bán kính thân.
var unit_at: Vector2 = Vector2.INF
var unit_radius: float = 30.0


func paint(ci: GroundCanvas) -> void:
	if not active:
		return
	var line: Color = Color(0.6, 0.85, 1.0, 0.8)
	var fill: Color = Color(0.6, 0.85, 1.0, 0.18)
	ci.draw_arc(origin, reach, 0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
	match targeting:
		AbilityDef.Targeting.NO_TARGET:
			ci.draw_circle(origin, area_radius, fill)
			ci.draw_arc(origin, area_radius, 0, TAU, 64, line, 4.0, true)
		AbilityDef.Targeting.DIRECTION when cone_angle > 0.0:
			var mid: float = (target - origin).angle()
			var half: float = deg_to_rad(cone_angle) * 0.5
			ci.draw_sector(origin, reach, mid - half, mid + half, fill)
			ci.draw_arc(origin, reach, mid - half, mid + half, 24, line, 4.0, true)
			ci.draw_line(origin, origin + Vector2.from_angle(mid - half) * reach, line, 4.0, true)
			ci.draw_line(origin, origin + Vector2.from_angle(mid + half) * reach, line, 4.0, true)
		AbilityDef.Targeting.DIRECTION:
			var dir: Vector2 = (target - origin).normalized()
			var side: Vector2 = dir.orthogonal() * maxf(width, 40.0) * 0.5
			var end: Vector2 = origin + dir * reach
			ci.draw_colored_polygon(PackedVector2Array([origin + side, end + side, end - side, origin - side]), fill)
			ci.draw_line(origin, end, line, 4.0, true)
		AbilityDef.Targeting.UNIT:
			if unit_at.is_finite():
				ci.draw_line(origin, unit_at, Color(1, 0.4, 0.3, 0.8), 4.0, true)
				ci.draw_arc(unit_at, unit_radius + 14.0, 0, TAU, 40, Color(1, 0.3, 0.25, 0.95), 5.0, true)
				ci.draw_circle(unit_at, unit_radius + 14.0, Color(1, 0.3, 0.25, 0.15))
			else:
				ci.draw_line(origin, target, Color(1, 1, 1, 0.3), 3.0, true)
		_:
			ci.draw_line(origin, target, Color(1, 1, 1, 0.4), 3.0, true)
			ci.draw_circle(target, maxf(area_radius, 40.0), fill)
			ci.draw_arc(target, maxf(area_radius, 40.0), 0, TAU, 48, line, 4.0, true)
