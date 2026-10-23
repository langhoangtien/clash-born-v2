class_name HeroDetail
extends RefCounted
## Màn chọn tướng (D-123, giao diện D-130): đầu khung (chân dung, tên, thuộc tính, chỉ số mỗi
## cấp) và ba thẻ Chiêu / Chỉ số / Talent, vẽ bằng UiStyle. Chỉ vẽ lên `c`, không giữ trạng thái.

enum Tab { SKILLS, STATS, TALENTS }

const TAB_NAMES: Array[String] = ["Chiêu", "Chỉ số", "Talent"]
const GOLD: Color = UiStyle.GOLD
const DIM: Color = UiStyle.DIM
const TEXT: Color = UiStyle.TEXT
const GREEN: Color = UiStyle.GREEN


static func portrait(c: CanvasItem, p: HeroPreview, box: Rect2, bright: bool = true) -> void:
	var tex: Texture2D = ArtLibrary.texture(StringName(String(p.def.id) + "_portrait"))
	if tex != null:
		c.draw_texture_rect(tex, box, false, Color.WHITE if bright else Color(0.62, 0.62, 0.66))
	else:
		UiStyle.text_center(c, UiStyle.serif(true), box.get_center(), p.def.display_name.left(1), int(box.size.y * 0.45), GOLD)


static func draw_header(c: CanvasItem, p: HeroPreview, at: Vector2) -> void:
	var box: Rect2 = Rect2(at, Vector2(140, 140))
	c.draw_style_box(UiStyle.box(UiStyle.CARD, GOLD, 3, 10, Color(GOLD, 0.25), 8), box)
	portrait(c, p, box.grow(-4))
	c.draw_string(UiStyle.serif(true), at + Vector2(168, 56), p.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, TEXT)
	var melee: bool = p.def.stats.attack_range <= 200.0
	var line: String = "%s · %s · Tầm %d" % [p.primary_name(), "Đánh gần" if melee else "Đánh xa", roundi(p.def.stats.attack_range)]
	c.draw_string(UiStyle.serif(), at + Vector2(168, 100), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, GOLD)
	c.draw_string(UiStyle.sans(), at + Vector2(168, 134), p.growth_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)


static func draw_tab(c: CanvasItem, p: HeroPreview, tab: Tab, area: Rect2) -> void:
	match tab:
		Tab.SKILLS:
			_skills(c, p, area)
		Tab.STATS:
			_stats(c, p, area)
		Tab.TALENTS:
			_talents(c, p, area)


## Lưới 2 × 2: Nội tại, W bên trên; Q, R bên dưới — mỗi chiêu một khung.
static func _skills(c: CanvasItem, p: HeroPreview, area: Rect2) -> void:
	var rows: Array = p.skill_rows()
	var gap: float = 16.0
	var cw: float = (area.size.x - gap) * 0.5
	var ch: float = (area.size.y - gap) * 0.5
	var order: Array[int] = [0, 2, 1, 3]
	for k: int in range(mini(rows.size(), 4)):
		var cell: Rect2 = Rect2(area.position + Vector2((k % 2) * (cw + gap), (k / 2) * (ch + gap)), Vector2(cw, ch))
		_skill(c, rows[order[k]], cell)


static func _skill(c: CanvasItem, row: Array, cell: Rect2) -> void:
	c.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 12), cell)
	var d: AbilityDef = row[0]
	var tex: Texture2D = ArtLibrary.texture(d.art_id)
	var icon: Rect2 = Rect2(cell.position + Vector2(18, 20), Vector2(108, 108))
	if tex != null:
		c.draw_texture_rect(tex, icon, false)
	var x: float = 146.0
	var w: float = cell.size.x - x - 16.0
	c.draw_string(UiStyle.serif(true), cell.position + Vector2(x, 42), row[1], HORIZONTAL_ALIGNMENT_LEFT, w, 26, GOLD)
	UiStyle.pill(c, cell.position + Vector2(x, 56), row[2], 16)
	var y: float = cell.position.y + 118.0
	if not d.description.is_empty():
		var h: float = UiStyle.sans().get_multiline_string_size(d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 19).y
		c.draw_multiline_string(UiStyle.sans(), Vector2(cell.position.x + x, y), d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 19, 3, TEXT)
		y += minf(h, 72.0) + 12.0
	for line: String in HeroPreview.compact_lines(d):
		if y > cell.end.y - 10.0:
			break
		c.draw_string(UiStyle.sans(true), Vector2(cell.position.x + x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, 18, GREEN)
		y += 24.0


static func _stats(c: CanvasItem, p: HeroPreview, area: Rect2) -> void:
	c.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 12), area)
	var x: Array[float] = [area.position.x + 28.0, area.position.x + 460.0, area.position.x + 760.0]
	var y: float = area.position.y + 44.0
	c.draw_string(UiStyle.serif(true), Vector2(x[1], y), "Cấp 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	c.draw_string(UiStyle.serif(true), Vector2(x[2], y), "Cấp %d" % p.lv20.stats.level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GOLD)
	y += 40.0
	for row: Array in p.stat_table():
		c.draw_string(UiStyle.serif(), Vector2(x[0], y), row[0], HORIZONTAL_ALIGNMENT_LEFT, 420, 21, DIM)
		c.draw_string(UiStyle.sans(true), Vector2(x[1], y), row[1], HORIZONTAL_ALIGNMENT_LEFT, 290, 21, row[3])
		c.draw_string(UiStyle.sans(true), Vector2(x[2], y), row[2], HORIZONTAL_ALIGNMENT_LEFT, 330, 21, row[3])
		UiStyle.divider(c, Vector2(x[0], y + 10), Vector2(area.end.x - 28, y + 10))
		y += 33.0


static func _talents(c: CanvasItem, p: HeroPreview, area: Rect2) -> void:
	c.draw_string(UiStyle.sans(), area.position + Vector2(4, 20), "Ở cấp 20 chọn 1 trong 3 talent; talent nâng chiêu tương ứng lên tầng II.", HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 21, DIM)
	var y: float = area.position.y + 44.0
	for t: Array in p.talents():
		var cell: Rect2 = Rect2(Vector2(area.position.x, y), Vector2(area.size.x, 118))
		c.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 12), cell)
		var d: AbilityDef = t[1]
		var tal: TalentDef = t[2]
		var tex: Texture2D = ArtLibrary.texture(d.art_id)
		if tex != null:
			c.draw_texture_rect(tex, Rect2(cell.position + Vector2(16, 14), Vector2(90, 90)), false)
		c.draw_string(UiStyle.serif(true), cell.position + Vector2(126, 46), "%s II · %s" % [t[0], tal.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, GOLD)
		c.draw_string(UiStyle.sans(), cell.position + Vector2(126, 86), tal.description, HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 140, 21, TEXT)
		y += 132.0
