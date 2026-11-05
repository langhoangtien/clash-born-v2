class_name StatsPainter
extends RefCounted
## D-253: vẽ bảng thông số hero (InfoPanels.Open.STATS) theo 3 tab. Chỉ số: hai cột, phần cộng thêm xanh "+12", phần
## trừ đỏ "−27". Kỹ năng: 4 thẻ có icon, nút + nâng cấp, mỗi loại giá trị một màu, cấp hiện tại sáng / đậm; hồi
## chiêu · mana · tầm của cấp hiện tại gom ở chân thẻ. Talent: 3 thẻ talent Q / W / R với nút chọn. Chỉ vẽ.
## D-255: cùng kiểu với màn chọn tướng (HeroDetail): UiStyle.panel / tab / section / button, serif cho tiêu đề – nhãn.

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
	var name: String = c.hero.hero_def.display_name if c.hero.hero_def != null else "Hero"
	c.draw_string(UiStyle.serif(true), p.position + Vector2(32, 64), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiStyle.TEXT)
	var w: float = UiStyle.serif(true).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	c.draw_string(UiStyle.serif(), p.position + Vector2(48 + w, 62), "Cấp %d" % c.hero.stats.level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiStyle.GOLD)
	for t: int in 3:
		var label: String = TAB_NAMES[t] + (" (%d)" % c.hero.skill_points if t == InfoPanels.Tab.SKILLS and c.hero.skill_points > 0 else "")
		UiStyle.tab(c, c.tab_rect(t), label, t == c.tab)
	UiStyle.divider(c, p.position + Vector2(24, 92), Vector2(p.end.x - 24, p.position.y + 92))
	match c.tab:
		InfoPanels.Tab.STATS:
			_stats(c, p)
		InfoPanels.Tab.SKILLS:
			for slot: int in InfoPanels.SKILL_SLOTS:
				_skill_card(c, slot)
		InfoPanels.Tab.TALENT:
			c.draw_string(UiStyle.sans(), p.position + Vector2(30, 128), "Ở cấp %d chọn 1 trong 3 talent; talent nâng chiêu tương ứng lên tầng II." % c.world.balance.talent_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiStyle.DIM)
			for slot: int in InfoPanels.TALENT_SLOTS:
				_talent_card(c, slot)


static func _stats(c: InfoPanels, p: Rect2) -> void:
	var area: Rect2 = Rect2(p.position + Vector2(24, 108), p.size - Vector2(48, 132))
	UiStyle.section(c, area)
	var rows: Array = InfoPanels.stat_rows(c.hero)
	var half: int = ceili(rows.size() / 2.0)
	var col_w: float = (area.size.x - 56.0) * 0.5
	for i: int in rows.size():
		var row: Array = rows[i]
		var x: float = area.position.x + 28.0 + (i / half) * (col_w + 28.0)
		var y: float = area.position.y + 50.0 + (i % half) * 44.0
		c.draw_string(UiStyle.serif(), Vector2(x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, 300, 21, UiStyle.DIM)
		c.draw_string(UiStyle.sans(true), Vector2(x + 300, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, row[3])
		if row[2] != "":
			var vw: float = UiStyle.sans(true).get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			var minus: bool = String(row[2]).begins_with("−")
			c.draw_string(UiStyle.sans(true), Vector2(x + 314 + vw, y), String(row[2]).insert(1, " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiStyle.RED_TEXT if minus else UiStyle.GREEN)
		UiStyle.divider(c, Vector2(x, y + 12), Vector2(x + col_w, y + 12))


static func _skill_card(c: InfoPanels, slot: int) -> void:
	var a: AbilityInstance = Abilities.of(c.hero, slot)
	if a == null:
		return
	var r: Rect2 = c.card_rect(slot)
	UiStyle.section(c, r)
	var tex: Texture2D = ArtLibrary.texture(a.def.art_id)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(r.position + Vector2(18, 16), Vector2(84, 84)), false)
	var key: String = ["Nội tại", "Q", "W", "R"][slot]
	c.draw_string(UiStyle.serif(true), r.position + Vector2(120, 48), "%s · %s" % [key, a.def.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.GOLD)
	for k: int in a.def.expected_ranks():  # chấm cấp
		UiStyle.orb(c, r.position + Vector2(130 + k * 26, 80), 8.0, UiStyle.GOLD if k < a.rank else UiStyle.LINE, k < a.rank)
	if c.can_level(slot):
		UiStyle.button(c, c.level_rect(slot), &"gold", "+", "", 40)
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


## Hàng talent như màn chọn tướng: icon, "Q II · tên", mô tả; nút Chọn bên phải.
static func _talent_card(c: InfoPanels, slot: int) -> void:
	var a: AbilityInstance = Abilities.of(c.hero, slot)
	if a == null or a.def.talent == null:
		return
	var r: Rect2 = c.card_rect(slot)
	var chosen: bool = a.talent_active
	if chosen:
		UiStyle.card(c, r, true)
	else:
		UiStyle.section(c, r)
	var tex: Texture2D = ArtLibrary.texture(a.def.art_id)
	if tex != null:
		c.draw_texture_rect(tex, Rect2(r.position + Vector2(20, (r.size.y - 110) * 0.5), Vector2(110, 110)), false)
	var key: String = ["", "Q", "W", "R"][slot]
	c.draw_string(UiStyle.serif(true), r.position + Vector2(156, 70), "%s II · %s" % [key, a.def.talent.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiStyle.GOLD)
	c.draw_multiline_string(UiStyle.sans(), r.position + Vector2(156, 112), a.def.talent.description, HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - 470, 21, 3, UiStyle.TEXT)
	var state: String = "Đã chọn" if chosen else ("Chọn" if c.can_pick(slot) else "Mở ở cấp %d" % c.world.balance.talent_level)
	UiStyle.button(c, c.talent_rect(slot), &"gold" if c.can_pick(slot) or chosen else &"ghost", state, "", 26)


static func _text(c: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
