class_name FloatingText
extends RefCounted
## Chữ nổi (VIEW): số sát thương (chí mạng to, vàng), "Trượt", "CHOÁNG". Đọc World.recent_notes. D-180: vẽ
## trên màn hình (Bars3D) tại điểm `to_screen(vị trí)` (trên đầu đơn vị; null = sau camera), bay lên dần.

const LIFE_TICKS: float = 24.0


static func draw(ci: CanvasItem, world: World, to_screen: Callable) -> void:
	var font: Font = ThemeDB.fallback_font
	for n: Array in world.recent_notes:
		var age: float = (world.tick - n[3]) / LIFE_TICKS
		if age >= 1.0:
			continue
		var text: String
		var size: int = 22
		var color: Color = Color.WHITE
		match n[0]:
			&"miss":
				text = "Trượt"
			&"deflect":
				text = "HẤT!"
				color = Color(0.55, 0.85, 1.0)
				size = 30
			&"reincarnate":
				text = "TÁI SINH"
				color = Color(1.0, 0.85, 0.35)
				size = 28
			&"stun":
				text = "CHOÁNG"
				color = Color(1.0, 0.9, 0.3)
				size = 26
			&"crit":
				text = "%d!" % roundi(n[2])
				color = Color(1.0, 0.8, 0.2)
				size = 34
			_:
				text = "%d" % roundi(n[2])
				color = Color(1.0, 0.45, 0.4)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var head: Variant = to_screen.call(n[1])
		if head == null:
			continue
		var at: Vector2 = (head as Vector2) - Vector2(w * 0.5, 40 * age + (30 if n[0] == &"stun" else 0))
		var fade: float = 1.0 - age * age
		ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8 * fade))
		ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, fade))
