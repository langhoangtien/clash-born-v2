class_name ScorePainter
extends RefCounted
## D-223: bảng tỷ số (chạm khung tỷ số) kiểu Liên Quân — băng rôn đầu bảng (xanh | đồng hồ | đỏ), hai cột đội,
## mỗi hero một thẻ: chân dung tròn + huy hiệu cấp, tên, K/D/A, LH, giá trị đồ có đồng xu, 6 ô đồ bo góc.

const BLUE: Color = Color(0.3, 0.58, 1.0)
const RED: Color = Color(1.0, 0.4, 0.36)
const ROW_H: float = 150.0


static func height(rows: Array) -> float:
	var per_team: Array[int] = [0, 0]
	for row: Array in rows:
		per_team[row[0]] += 1
	return 170.0 + ROW_H * maxi(1, maxi(per_team[0], per_team[1]))


static func draw(c: CanvasItem, p: Rect2, world: World, rows: Array) -> void:
	_banner(c, p, world)
	var half: float = (p.size.x - 72.0) * 0.5
	var y: Array[float] = [p.position.y + 150.0, p.position.y + 150.0]
	for team: int in 2:
		var x: float = p.position.x + 24.0 + team * (half + 24.0)
		_label(c, UiStyle.serif(true), Vector2(x + 8, y[team] - 14), "Đội Xanh" if team == 0 else "Đội Đỏ", 26, BLUE if team == 0 else RED)
	for row: Array in rows:
		var team: int = row[0]
		var x: float = p.position.x + 24.0 + team * (half + 24.0)
		_card(c, Rect2(Vector2(x, y[team] + 6), Vector2(half, ROW_H - 16)), row)
		y[team] += ROW_H


static func _banner(c: CanvasItem, p: Rect2, world: World) -> void:
	var w: float = 520.0
	var r: Rect2 = Rect2(Vector2(p.get_center().x - w * 0.5, p.position.y + 26), Vector2(w, 76))
	var side: float = w * 0.34
	for team: int in 2:
		var col: Color = BLUE if team == 0 else RED
		var wr: Rect2 = Rect2(Vector2(r.position.x if team == 0 else r.end.x - side - 24, r.position.y), Vector2(side + 24, r.size.y))
		c.draw_style_box(UiStyle.box(col.darkened(0.25), Color(UiStyle.GOLD_DEEP, 0.95), 2, 38, Color(0, 0, 0, 0.35), 8), wr)
		var at: float = r.position.x + side * 0.5 + 8 if team == 0 else r.end.x - side * 0.5 - 8
		UiStyle.text_center(c, UiStyle.sans(true), Vector2(at, r.get_center().y), str(MatchScore.team_kills(world, team)), 46, Color.WHITE)
	var mid: Rect2 = Rect2(r.position + Vector2(side, 0), Vector2(w - side * 2.0, r.size.y))
	UiStyle.soft_frame(c, mid, 14, Color(0.04, 0.06, 0.1, 0.98))
	UiStyle.text_center(c, UiStyle.sans(true), mid.get_center() + Vector2(0, -6), MatchHud.clock_text(world.tick), 30, Color.WHITE)
	UiStyle.text_center(c, UiStyle.sans(), mid.get_center() + Vector2(0, 22), "Tỷ số", 16, UiStyle.DIM)


static func _card(c: CanvasItem, r: Rect2, row: Array) -> void:
	var col: Color = BLUE if row[0] == 0 else RED
	c.draw_style_box(UiStyle.box(Color(col.darkened(0.6), 0.55), Color(col, 0.55), 2, 18), r)
	var pc: Vector2 = r.position + Vector2(62, r.size.y * 0.5)
	UiStyle.orb(c, pc, 46.0, col.darkened(0.55))
	var tex: Texture2D = ArtLibrary.texture(row[8]) if row.size() > 8 and row[8] != &"" else null
	if tex != null:
		var pts: PackedVector2Array = PackedVector2Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		for k: int in 32:
			var d: Vector2 = Vector2.from_angle(TAU * k / 32.0)
			pts.append(pc + d * 40.0)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	var badge: Vector2 = pc + Vector2(-32, 32)
	UiStyle.orb(c, badge, 16.0, Color(0.12, 0.2, 0.36))
	UiStyle.text_center(c, UiStyle.sans(true), badge, str(row[2]), 18, Color.WHITE)
	var x: float = r.position.x + 128
	_label(c, UiStyle.serif(true), Vector2(x, r.position.y + 42), row[1], 26, Color.WHITE)
	_label(c, UiStyle.sans(true), Vector2(x, r.position.y + 78), row[3], 24, Color(1, 1, 1, 0.92))
	_label(c, UiStyle.sans(), Vector2(x + 110, r.position.y + 78), "LH %d" % row[4], 20, UiStyle.DIM)
	UiStyle.coin(c, Vector2(x + 210, r.position.y + 70), 10.0)
	_label(c, UiStyle.sans(true), Vector2(x + 226, r.position.y + 78), str(row[5]), 22, Color(1, 0.86, 0.4))
	for k: int in range(row[6].size()):
		var box: Rect2 = Rect2(Vector2(x + k * 52, r.position.y + 90), Vector2(44, 44))
		UiStyle.soft_frame(c, box, 9, Color(0.08, 0.1, 0.15, 0.95))
		var it: Texture2D = ArtLibrary.texture(row[7][k])
		if it != null:
			c.draw_texture_rect(it, box.grow(-4), false)


static func _label(c: CanvasItem, f: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	c.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.75))
	c.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
