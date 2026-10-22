class_name InfoPanels
extends Control
## D-100: hai bảng xem thông tin kiểu Liên Quân. Chạm ô máu/mana (MatchHud.PANEL) → bảng thông số
## hero: chỉ số và kỹ năng (con số theo từng cấp, cấp đang có đánh dấu). Chạm tỷ số giữa trên →
## bảng tỷ số: mỗi hero một dòng (cấp, K/D/A, last hit, giá trị đồ, 6 ô đồ). Chạm lần nữa / ✕ để
## đóng. Chỉ đọc World.

enum Open { NONE, STATS, SCORE }

const PANEL_SIZE: Vector2 = Vector2(1500, 860)
const SCORE_HIT: Vector2 = Vector2(360, 76)
## Tên hiển thị của giá trị kỹ năng hay gặp; tên lạ thì in nguyên.
const VALUE_NAMES: Dictionary = {
	&"damage": "Sát thương", &"cooldown": "Hồi chiêu (s)", &"mana": "Mana", &"cast_range": "Tầm",
	&"duration": "Thời gian (s)", &"radius": "Bán kính", &"stun_duration": "Choáng (s)",
	&"slow_duration": "Làm chậm (s)", &"slow": "Làm chậm", &"move_bonus": "Tốc chạy +", &"delay": "Trễ (s)",
	&"width": "Bề rộng", &"length": "Chiều dài", &"silence_duration": "Câm lặng (s)", &"shield": "Khiên",
	&"root_duration": "Trói (s)", &"push": "Đẩy lùi", &"hex_duration": "Biến hình (s)", &"heal_fraction": "Hồi máu (phần)",
	&"fade_in": "Hiện dần (s)", &"drain": "Hút", &"disarm_duration": "Tước vũ khí (s)", &"damage_per_buff": "Sát thương / buff",
	&"crit_multiplier": "Chí mạng ×", &"crit_chance": "Tỉ lệ chí mạng", &"chance": "Tỉ lệ", &"bonus_damage": "Sát thương thêm",
	&"attack_speed_per_stack": "Tốc đánh / tầng", &"amplify": "Khuếch đại", &"ambush_damage": "Sát thương phục kích", &"pierce": "Xuyên",
	&"bonus": "Sát thương +", &"dps": "Sát thương / giây", &"zone_duration": "Thời gian vùng (s)", &"bat_cut": "Giảm BAT",
	&"regen": "Hồi máu / giây", &"rage_damage": "Sát thương khi Cuồng Hóa",
}

var world: World
var hero: Entity
var open: Open = Open.NONE


func panel_rect() -> Rect2:
	return Rect2((size - PANEL_SIZE) * 0.5, PANEL_SIZE)


func score_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - SCORE_HIT.x * 0.5, 0), SCORE_HIT)


func close_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(p.size.x - 70, 14), Vector2(52, 52))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _has_point(point: Vector2) -> bool:
	return MatchHud.PANEL.has_point(point) or score_rect().has_point(point) or (open != Open.NONE and panel_rect().has_point(point))


func press_at(local: Vector2) -> void:
	if open != Open.NONE and (close_rect().has_point(local) or not panel_rect().has_point(local)):
		open = Open.NONE
	elif open == Open.NONE and MatchHud.PANEL.has_point(local):
		open = Open.STATS
	elif open == Open.NONE and score_rect().has_point(local):
		open = Open.SCORE
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102: click PC không bật/tắt hai lần
	if at.is_finite():
		press_at(at)
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()


func _process(_delta: float) -> void:
	if open != Open.NONE:
		queue_redraw()


func _draw() -> void:
	if open == Open.NONE or world == null or hero == null:
		return
	var font: Font = ThemeDB.fallback_font
	var p: Rect2 = panel_rect()
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.95))
	draw_rect(p, Color(1, 0.85, 0.4, 0.8), false, 3.0)
	var x: Rect2 = close_rect()
	draw_rect(x, Color(0.5, 0.15, 0.15, 0.9))
	_text(font, x.get_center() + Vector2(-9, 10), "✕", 28, Color.WHITE)
	if open == Open.STATS:
		_draw_stats(font, p)
	else:
		_draw_score(font, p)


## Màu theo loại chỉ số (D-124) để lướt nhanh trong trận.
const C_DAMAGE: Color = Color(1.0, 0.62, 0.3)
const C_SPEED: Color = Color(1.0, 0.88, 0.35)
const C_ARMOR: Color = Color(0.62, 0.8, 1.0)
const C_MAGIC: Color = Color(0.82, 0.62, 1.0)
const C_MOVE: Color = Color(0.45, 1.0, 0.92)
const C_RANGE: Color = Color(0.92, 0.92, 0.92)
const C_HP: Color = Color(0.45, 0.95, 0.45)
const C_MANA: Color = Color(0.45, 0.65, 1.0)
const C_SPECIAL: Color = Color(1.0, 0.55, 0.65)
const C_STR: Color = Color(1.0, 0.45, 0.4)
const C_AGI: Color = Color(0.5, 1.0, 0.5)
const C_INT: Color = Color(0.5, 0.75, 1.0)
const C_BONUS: Color = Color(0.4, 1.0, 0.4)


## Dòng chỉ số: [tên, giá trị gốc, phần cộng thêm từ đồ / hiệu ứng ("" nếu không có), màu].
## Kiểu Dota (D-124): sát thương "120 + 70", thuộc tính "25 + 12".
static func stat_rows(e: Entity) -> Array:
	var s: StatBlock = e.stats
	var armor: float = s.get_stat(StatId.Id.PHYSICAL_ARMOR)
	var marmor: float = s.get_stat(StatId.Id.MAGIC_ARMOR)
	var b: BalanceSettings = s.balance
	var cut: float = 1.0 - DamageFormulas.after_armor(100.0, DamageFormulas.DamageType.PHYSICAL, armor, marmor, b) / 100.0
	var mcut: float = 1.0 - DamageFormulas.after_armor(100.0, DamageFormulas.DamageType.MAGIC, armor, marmor, b) / 100.0
	var bat: float = s.get_stat(StatId.Id.BASE_ATTACK_TIME)
	var bat_base: float = s.natural(StatId.Id.BASE_ATTACK_TIME)
	var primary: int = e.hero_def.primary_attribute if e.hero_def != null else 0
	var rows: Array = [
		_split("Sát thương", s, StatId.Id.PHYSICAL_DAMAGE, C_DAMAGE),
		["Tốc đánh", "%d  (%.2f đòn/giây)" % [roundi(s.get_stat(StatId.Id.ATTACK_SPEED) * 100.0), s.attacks_per_second()], "", C_SPEED],
		["BAT (thời gian đánh gốc)", "%.2f s" % bat, "" if is_equal_approx(bat, bat_base) else "(gốc %.2f)" % bat_base, C_SPEED],
		["Giáp", "%.1f  (giảm %d%%)" % [armor, roundi(cut * 100.0)], "", C_ARMOR],
		["Kháng phép", "%.1f  (giảm %d%%)" % [marmor, roundi(mcut * 100.0)], "", C_MAGIC],
		["Tốc chạy", "%d" % roundi(s.get_stat(StatId.Id.MOVEMENT_SPEED)), "", C_MOVE],
		["Tầm đánh", "%d" % roundi(s.get_stat(StatId.Id.ATTACK_RANGE)), "", C_RANGE],
		["Máu / hồi máu", "%d / %.1f mỗi giây" % [roundi(s.get_stat(StatId.Id.MAX_HP)), s.get_stat(StatId.Id.HP_REGEN)], "", C_HP],
		["Mana / hồi mana", "%d / %.1f mỗi giây" % [roundi(s.get_stat(StatId.Id.MAX_MANA)), s.get_stat(StatId.Id.MANA_REGEN)], "", C_MANA],
	]
	for extra: Array in [["Chí mạng", StatId.Id.CRITICAL_CHANCE], ["Né tránh", StatId.Id.EVASION], ["Hút máu", StatId.Id.LIFESTEAL], ["Kháng hiệu ứng", StatId.Id.STATUS_RESISTANCE]]:
		var v: float = s.get_stat(extra[1])
		if v > 0.0:
			rows.append([extra[0], "%d%%" % roundi(v * 100.0), "", C_SPECIAL])
	var attrs: Array = [["Sức mạnh", StatId.Id.STRENGTH, C_STR], ["Nhanh nhẹn", StatId.Id.AGILITY, C_AGI], ["Trí tuệ", StatId.Id.INTELLIGENCE, C_INT]]
	for i: int in range(3):
		rows.append(_split(attrs[i][0] + (" (chính)" if primary == i + 1 else ""), s, attrs[i][1], attrs[i][2]))
	return rows


static func _split(label: String, s: StatBlock, stat: StatId.Id, col: Color) -> Array:
	var white: float = s.natural(stat)
	var bonus: float = s.get_stat(stat) - white
	return [label, "%d" % roundi(white), ("+%d" % roundi(bonus)) if absf(bonus) >= 0.5 else "", col]


## Dòng kỹ năng: [tên + cấp, [dòng giá trị "Tên: 90 / 140 / [190] / 240"]].
static func ability_rows(e: Entity) -> Array:
	var out: Array = []
	for slot: int in [AbilityDef.Slot.INNATE, AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]:
		var a: AbilityInstance = Abilities.of(e, slot)
		if a == null:
			continue
		var key: String = ["Nội tại", "Q", "W", "R"][slot]
		var title: String = "%s  %s  (cấp %d/%d)" % [key, a.def.display_name, a.rank, a.def.expected_ranks()]
		var lines: PackedStringArray = PackedStringArray()
		var names: Array = a.def.values.keys()
		names.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
		for name: StringName in names:
			var parts: PackedStringArray = PackedStringArray()
			var arr: PackedFloat32Array = a.def.values[name]
			for i: int in range(arr.size()):
				var v: String = _num(arr[i])
				parts.append("[%s]" % v if i == a.rank - 1 else v)
			lines.append("%s: %s" % [VALUE_NAMES.get(name, String(name)), " / ".join(parts)])
		if a.talent_active and a.def.talent != null:
			lines.append("Talent: " + a.def.talent.display_name)
		out.append([title, lines])
	return out


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.2f" % v).rstrip("0").rstrip(".")


func _draw_stats(font: Font, p: Rect2) -> void:
	_text(font, p.position + Vector2(28, 52), "%s — cấp %d" % [hero.hero_def.display_name if hero.hero_def != null else "Hero", hero.stats.level()], 30, Color.WHITE)
	var y: float = 100.0
	for row: Array in stat_rows(hero):  # D-124: màu theo loại, phần cộng thêm màu xanh
		_text(font, p.position + Vector2(28, y), row[0], 20, Color(1, 1, 1, 0.65))
		_text(font, p.position + Vector2(300, y), row[1], 20, row[3])
		if row[2] != "":
			var w: float = font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_text(font, p.position + Vector2(310 + w, y), row[2], 20, C_BONUS)
		y += 31.0
	var x: float = 620.0
	y = 100.0
	for row: Array in ability_rows(hero):
		_text(font, p.position + Vector2(x, y), row[0], 22, Color(1, 0.85, 0.35))
		y += 30.0
		for line: String in row[1]:
			_text(font, p.position + Vector2(x + 20, y), line, 17, Color(1, 1, 1, 0.85))
			y += 24.0
		y += 12.0


## Dòng tỷ số: mỗi hero [đội, tên, cấp, K/D/A, LH, giá trị đồ, tên tắt 6 ô, art_id 6 ô (D-115)].
static func score_rows(w: World) -> Array:
	var out: Array = []
	for team: int in range(2):
		for e: Entity in w.entities:
			if e.kind != Entity.Kind.HERO or e.team != team:
				continue
			var worth: int = 0
			var slots: PackedStringArray = PackedStringArray()
			var arts: Array[StringName] = []
			for it: ItemInstance in Items.slots(e):
				worth += it.def.cost if it != null else 0
				slots.append(ItemButtons.short_name(it.def.display_name) if it != null else "")
				arts.append(it.def.art_id if it != null else &"")
			out.append([team, e.hero_def.display_name if e.hero_def != null else "Hero", e.stats.level(),
				"%d/%d/%d" % [e.kills, e.deaths, e.assists], e.last_hits, worth, slots, arts])
	return out


func _draw_score(font: Font, p: Rect2) -> void:
	_text(font, p.position + Vector2(28, 52), "Tỷ số  %d — %d" % [MatchScore.team_kills(world, 0), MatchScore.team_kills(world, 1)], 30, Color.WHITE)
	var heads: Array = ["Hero", "Cấp", "K/D/A", "LH", "Giá trị đồ", "Đồ"]
	var cols: Array[float] = [28.0, 330.0, 430.0, 590.0, 690.0, 860.0]
	for i: int in range(heads.size()):
		_text(font, p.position + Vector2(cols[i], 110), heads[i], 20, Color(1, 1, 1, 0.6))
	var y: float = 170.0
	for row: Array in score_rows(world):
		var col: Color = Color(0.45, 0.7, 1.0) if row[0] == 0 else Color(1.0, 0.45, 0.4)
		draw_rect(Rect2(p.position + Vector2(16, y - 40), Vector2(p.size.x - 32, 64)), Color(col, 0.12))
		_text(font, p.position + Vector2(cols[0], y), row[1], 24, col)
		_text(font, p.position + Vector2(cols[1], y), str(row[2]), 24, Color.WHITE)
		_text(font, p.position + Vector2(cols[2], y), row[3], 24, Color.WHITE)
		_text(font, p.position + Vector2(cols[3], y), str(row[4]), 24, Color.WHITE)
		_text(font, p.position + Vector2(cols[4], y), str(row[5]), 24, Color(1, 0.85, 0.3))
		for k: int in range(row[6].size()):
			var box: Rect2 = Rect2(p.position + Vector2(cols[5] + k * 72, y - 36), Vector2(60, 60))
			draw_rect(box, Color(0.15, 0.17, 0.22, 0.95))
			var tex: Texture2D = ArtLibrary.texture(row[7][k])
			if tex != null:
				draw_texture_rect(tex, box.grow(-2), false)
			elif row[6][k] != "":
				_text(font, box.get_center() + Vector2(-14, 8), row[6][k], 20, Color.WHITE)
		y += 84.0


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
