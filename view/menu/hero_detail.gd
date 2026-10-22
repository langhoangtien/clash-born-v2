class_name HeroDetail
extends RefCounted
## Màn chọn tướng (D-123): vẽ khung chi tiết tướng — đầu khung (chân dung, tên, thuộc tính) và
## ba thẻ Chiêu / Chỉ số / Talent. Chỉ vẽ lên `c`, không giữ trạng thái.

enum Tab { SKILLS, STATS, TALENTS }

const TAB_NAMES: Array[String] = ["Chiêu", "Chỉ số", "Talent"]
const GOLD: Color = Color(1, 0.84, 0.4)
const DIM: Color = Color(1, 1, 1, 0.62)
const TEXT: Color = Color(0.94, 0.92, 0.88)
const GREEN: Color = Color(0.62, 0.95, 0.62)


static func draw_header(c: CanvasItem, font: Font, p: HeroPreview, at: Vector2) -> void:
	var tex: Texture2D = ArtLibrary.texture(StringName(String(p.def.id) + "_portrait"))
	var box: Rect2 = Rect2(at, Vector2(150, 150))
	c.draw_rect(box, Color(0.1, 0.1, 0.14))
	if tex != null:
		c.draw_texture_rect(tex, box, false)
	else:
		_center(c, font, box.get_center(), p.def.display_name.left(1), 72, GOLD)
	c.draw_rect(box, GOLD, false, 3.0)
	c.draw_string(font, at + Vector2(176, 56), p.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	var melee: bool = p.def.stats.attack_range <= 200.0
	var line: String = "%s · %s (tầm %d)" % [p.primary_name(), "Đánh gần" if melee else "Đánh xa", roundi(p.def.stats.attack_range)]
	c.draw_string(font, at + Vector2(176, 100), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	c.draw_string(font, at + Vector2(176, 136), p.growth_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)


static func draw_tab(c: CanvasItem, font: Font, p: HeroPreview, tab: Tab, area: Rect2) -> void:
	match tab:
		Tab.SKILLS:
			_skills(c, font, p, area)
		Tab.STATS:
			_stats(c, font, p, area)
		Tab.TALENTS:
			_talents(c, font, p, area)


## Hai cột: Nội tại + Q bên trái, W + R bên phải.
static func _skills(c: CanvasItem, font: Font, p: HeroPreview, area: Rect2) -> void:
	var rows: Array = p.skill_rows()
	var col_w: float = area.size.x * 0.5 - 16.0
	var y: Array[float] = [area.position.y, area.position.y]
	for i: int in range(rows.size()):
		var col: int = 0 if i < 2 else 1
		var x: float = area.position.x + col * (col_w + 32.0)
		y[col] = _skill(c, font, rows[i], Vector2(x, y[col]), col_w) + 20.0


static func _skill(c: CanvasItem, font: Font, row: Array, at: Vector2, width: float) -> float:
	var d: AbilityDef = row[0]
	var tex: Texture2D = ArtLibrary.texture(d.art_id)
	var icon: Rect2 = Rect2(at, Vector2(64, 64))
	if tex != null:
		c.draw_texture_rect(tex, icon, false)
	c.draw_string(font, at + Vector2(78, 26), row[1], HORIZONTAL_ALIGNMENT_LEFT, width - 78, 24, GOLD)
	c.draw_string(font, at + Vector2(78, 54), row[2], HORIZONTAL_ALIGNMENT_LEFT, width - 78, 17, DIM)
	var y: float = at.y + 78.0
	if not d.description.is_empty():
		var h: float = font.get_multiline_string_size(d.description, HORIZONTAL_ALIGNMENT_LEFT, width, 18).y
		c.draw_multiline_string(font, Vector2(at.x, y + 14), d.description, HORIZONTAL_ALIGNMENT_LEFT, width, 18, -1, TEXT)
		y += h + 8.0
	for line: String in row[3]:
		c.draw_string(font, Vector2(at.x + 8, y + 14), line, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 17, GREEN)
		y += 23.0
	return y


static func _stats(c: CanvasItem, font: Font, p: HeroPreview, area: Rect2) -> void:
	var x: Array[float] = [area.position.x, area.position.x + 380.0, area.position.x + 700.0]
	var y: float = area.position.y + 24.0
	c.draw_string(font, Vector2(x[1], y), "Cấp 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD)
	c.draw_string(font, Vector2(x[2], y), "Cấp %d" % p.lv20.stats.level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD)
	y += 40.0
	for row: Array in p.stat_table():
		c.draw_rect(Rect2(Vector2(area.position.x - 8, y - 26), Vector2(area.size.x, 36)), Color(1, 1, 1, 0.03))
		c.draw_string(font, Vector2(x[0], y), row[0], HORIZONTAL_ALIGNMENT_LEFT, 360, 21, DIM)
		c.draw_string(font, Vector2(x[1], y), row[1], HORIZONTAL_ALIGNMENT_LEFT, 300, 21, row[3])
		c.draw_string(font, Vector2(x[2], y), row[2], HORIZONTAL_ALIGNMENT_LEFT, 360, 21, row[3])
		y += 34.0


static func _talents(c: CanvasItem, font: Font, p: HeroPreview, area: Rect2) -> void:
	c.draw_string(font, area.position + Vector2(0, 24), "Ở cấp 20 chọn 1 trong 3 talent; talent nâng chiêu tương ứng lên tầng II.", HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 20, DIM)
	var y: float = area.position.y + 64.0
	for t: Array in p.talents():
		var d: AbilityDef = t[1]
		var tal: TalentDef = t[2]
		var tex: Texture2D = ArtLibrary.texture(d.art_id)
		if tex != null:
			c.draw_texture_rect(tex, Rect2(Vector2(area.position.x, y), Vector2(72, 72)), false)
		c.draw_string(font, Vector2(area.position.x + 92, y + 28), "%s II · %s" % [t[0], tal.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
		c.draw_string(font, Vector2(area.position.x + 92, y + 62), tal.description, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 92, 20, TEXT)
		y += 120.0


static func _center(c: CanvasItem, font: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, at + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
