class_name StatsPainter
extends RefCounted
## D-253: vẽ bảng thông số hero (InfoPanels.Open.STATS) theo 3 tab. Chỉ số: hai cột, phần cộng thêm xanh "+12", phần
## trừ đỏ "−27". Kỹ năng: 4 thẻ có icon, nút + nâng cấp, mỗi loại giá trị một màu, cấp hiện tại sáng / đậm; hồi
## chiêu · mana · tầm của cấp hiện tại gom ở chân thẻ. Talent: 3 thẻ talent Q / W / R với nút chọn. Chỉ vẽ.

const TAB_NAMES: Array[String] = ["Chỉ số", "Kỹ năng", "Talent"]
const FOOTER: Array[StringName] = [&"cooldown", &"mana", &"cast_range"]
const C_DAMAGE: Color = Color(1.0, 0.6, 0.32)
const C_TIME: Color = Color(1.0, 0.86, 0.36)
const C_SIZE: Color = Color(0.78, 0.82, 0.9)
const C_HEAL: Color = Color(0.5, 0.95, 0.55)
const C_MOVE: Color = Color(0.45, 1.0, 0.92)
const C_CHANCE: Color = Color(1.0, 0.55, 0.7)
const C_OTHER: Color = Color(0.8, 0.66, 1.0)


## Màu dòng giá trị theo loại (đọc theo tên giá trị, không theo kỹ năng).
static func value_color(name: StringName) -> Color:
	var n: String = String(name)
	if n.contains("gold"):
		return UiStyle.GOLD
	if n.contains("damage") or n in ["strike", "dps", "bonus", "drain", "amplify", "pierce"]:
		return C_DAMAGE
	if n.contains("duration") or n in ["delay", "fade_in", "slow"]:
		return C_TIME
	if n in ["radius", "width", "length", "angle", "push"]:
		return C_SIZE
	if n.contains("heal") or n in ["regen", "shield"]:
		return C_HEAL
	if n.contains("speed") or n == "bat_cut":
		return C_MOVE
	if n.contains("chance") or n.contains("crit") or n.contains("reflect") or n.contains("deflect"):
		return C_CHANCE
	return C_OTHER


static func draw(c: InfoPanels, p: Rect2) -> void:
	var title: String = "%s — cấp %d" % [c.hero.hero_def.display_name if c.hero.hero_def != null else "Hero", c.hero.stats.level()]
	_text(c, UiStyle.serif(true), p.position + Vector2(28, 58), title, 34, UiStyle.TEXT)
	for t: int in 3:
		var r: Rect2 = c.tab_rect(t)
		UiStyle.tile(c, r, UiStyle.GOLD if t == c.tab else UiStyle.LINE, 2, UiStyle.CARD_HI if t == c.tab else UiStyle.CARD)
		var label: String = TAB_NAMES[t] + (" (%d)" % c.hero.skill_points if t == InfoPanels.Tab.SKILLS and c.hero.skill_points > 0 else "")
		UiStyle.text_center(c, UiStyle.sans(true), r.get_center() + Vector2(0, 8), label, 22, UiStyle.GOLD if t == c.tab else UiStyle.DIM)
	match c.tab:
		InfoPanels.Tab.STATS:
			_stats(c, p)
		InfoPanels.Tab.SKILLS:
			for slot: int in InfoPanels.SKILL_SLOTS:
				_skill_card(c, slot)
		InfoPanels.Tab.TALENT:
			for slot: int in InfoPanels.TALENT_SLOTS:
				_talent_card(c, slot)


static func _stats(c: InfoPanels, p: Rect2) -> void:
	var rows: Array = InfoPanels.stat_rows(c.hero)
	var half: int = ceili(rows.size() / 2.0)
	var font: Font = UiStyle.sans()
	for i: int in rows.size():
		var row: Array = rows[i]
		var at: Vector2 = p.position + Vector2(40 + (i / half) * 730, 130 + (i % half) * 46)
		_text(c, UiStyle.serif(), at, row[0], 22, UiStyle.DIM)
		_text(c, UiStyle.sans(true), at + Vector2(300, 0), row[1], 22, row[3])
		if row[2] != "":
			var w: float = font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var minus: bool = String(row[2]).begins_with("−")
			_text(c, UiStyle.sans(true), at + Vector2(316 + w, 0), String(row[2]).insert(1, " "), 22, UiStyle.RED_TEXT if minus else UiStyle.GREEN)


static func _skill_card(c: InfoPanels, slot: int) -> void:
	var a: AbilityInstance = Abilities.of(c.hero, slot)
	if a == null:
		return
	var r: Rect2 = c.card_rect(slot)
	UiStyle.card(c, r)
	var tex: Texture2D = ArtLibrary.texture(a.def.art_id)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(r.position + Vector2(18, 16), Vector2(78, 78)), false)
	var key: String = ["Nội tại", "Q", "W", "R"][slot]
	_text(c, UiStyle.serif(true), r.position + Vector2(112, 46), "%s  %s" % [key, a.def.display_name], 25, UiStyle.GOLD)
	for k: int in a.def.expected_ranks():  # chấm cấp
		UiStyle.orb(c, r.position + Vector2(122 + k * 26, 76), 8.0, UiStyle.GOLD if k < a.rank else UiStyle.LINE, k < a.rank)
	if c.can_level(slot):
		var b: Rect2 = c.level_rect(slot)
		UiStyle.tile(c, b, UiStyle.GOLD, 3, UiStyle.BLUE_BTN)
		UiStyle.text_center(c, UiStyle.sans(true), b.get_center() + Vector2(0, 12), "+", 36, UiStyle.GOLD)
	var names: Array = a.def.values.keys().filter(func(n: StringName) -> bool: return not FOOTER.has(n) and not HeroPreview.HIDDEN.has(n))
	names.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	var cols: int = 2 if names.size() > 6 else 1
	var per: int = ceili(names.size() / float(cols))
	for i: int in names.size():
		var at: Vector2 = r.position + Vector2(22 + (i / per) * 350, 128 + (i % per) * 31)
		_value_line(c, a, names[i], at, 160.0 if cols == 2 else 230.0)
	_footer(c, a, r)


## "Tên: 90 / 140 / 190" — tên theo màu loại, cấp hiện tại trắng đậm, cấp khác mờ.
static func _value_line(c: InfoPanels, a: AbilityInstance, name: StringName, at: Vector2, label_w: float) -> void:
	_text(c, UiStyle.sans(true), at, InfoPanels.VALUE_NAMES.get(name, String(name)), 17, value_color(name))
	var x: float = at.x + label_w
	var arr: PackedFloat32Array = a.def.values[name]
	var pct: bool = HeroPreview.PERCENT.has(name)
	for k: int in arr.size():
		var now: bool = k == a.rank - 1
		var s: String = InfoPanels.num(arr[k] * (100.0 if pct else 1.0)) + ("%" if pct else "") + (" /" if k < arr.size() - 1 else "")
		var f: Font = UiStyle.sans(now)
		_text(c, f, Vector2(x, at.y), s, 18 if now else 16, Color.WHITE if now else Color(UiStyle.DIM, 0.75))
		x += f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if now else 16).x + 6.0


static func _footer(c: InfoPanels, a: AbilityInstance, r: Rect2) -> void:
	var rank: int = maxi(a.rank, 1) - 1
	var parts: PackedStringArray = PackedStringArray()
	for n: StringName in FOOTER:
		if a.def.values.has(n):
			var arr: PackedFloat32Array = a.def.values[n]
			parts.append("%s %s" % [InfoPanels.VALUE_NAMES[n].replace(" (s)", ""), InfoPanels.num(arr[mini(rank, arr.size() - 1)])])
	var line: String = "   ·   ".join(parts)
	if a.talent_active and a.def.talent != null:
		line += "   ·   Talent: " + a.def.talent.display_name
	_text(c, UiStyle.sans(), r.position + Vector2(22, r.size.y - 18), line, 17, Color(0.6, 0.82, 1.0))


static func _talent_card(c: InfoPanels, slot: int) -> void:
	var a: AbilityInstance = Abilities.of(c.hero, slot)
	if a == null or a.def.talent == null:
		return
	var r: Rect2 = c.card_rect(slot)
	var chosen: bool = a.talent_active
	UiStyle.card(c, r, chosen)
	var tex: Texture2D = ArtLibrary.texture(a.def.art_id)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(r.position + Vector2(r.size.x * 0.5 - 60, 30), Vector2(120, 120)), false)
	var font: Font = UiStyle.serif(true)
	UiStyle.text_center(c, font, r.position + Vector2(r.size.x * 0.5, 196), a.def.talent.display_name, 26, UiStyle.GOLD)
	c.draw_multiline_string(UiStyle.sans(), r.position + Vector2(30, 250), a.def.talent.description, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 60, 21, -1, UiStyle.TEXT)
	var b: Rect2 = c.talent_rect(slot)
	var state: String = "Đã chọn" if chosen else ("Chọn" if c.can_pick(slot) else "Mở ở cấp %d" % c.world.balance.talent_level)
	UiStyle.tile(c, b, UiStyle.GOLD if c.can_pick(slot) or chosen else UiStyle.LINE, 2, UiStyle.BLUE_BTN if c.can_pick(slot) else UiStyle.CARD)
	UiStyle.text_center(c, UiStyle.sans(true), b.get_center() + Vector2(0, 9), state, 24, UiStyle.GOLD if chosen else UiStyle.TEXT)


static func _text(c: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
