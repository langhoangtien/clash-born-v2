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


## Dòng chỉ số: [tên, giá trị đã định dạng].
static func stat_rows(e: Entity) -> Array:
	var s: StatBlock = e.stats
	var armor: float = s.get_stat(StatId.Id.PHYSICAL_ARMOR)
	var marmor: float = s.get_stat(StatId.Id.MAGIC_ARMOR)
	var b: BalanceSettings = s.balance
	var cut: float = 1.0 - DamageFormulas.after_armor(100.0, DamageFormulas.DamageType.PHYSICAL, armor, marmor, b) / 100.0
	var mcut: float = 1.0 - DamageFormulas.after_armor(100.0, DamageFormulas.DamageType.MAGIC, armor, marmor, b) / 100.0
	return [
		["Sát thương", "%d" % roundi(s.get_stat(StatId.Id.PHYSICAL_DAMAGE))],
		["Giáp", "%.1f  (giảm %d%%)" % [armor, roundi(cut * 100.0)]],
		["Kháng phép", "%.1f  (giảm %d%%)" % [marmor, roundi(mcut * 100.0)]],
		["Tốc đánh", "%.2f đòn/giây" % s.attacks_per_second()],
		["Tốc chạy", "%d" % roundi(s.get_stat(StatId.Id.MOVEMENT_SPEED))],
		["Tầm đánh", "%d" % roundi(s.get_stat(StatId.Id.ATTACK_RANGE))],
		["Máu / hồi máu", "%d / %.1f mỗi giây" % [roundi(s.get_stat(StatId.Id.MAX_HP)), s.get_stat(StatId.Id.HP_REGEN)]],
		["Mana / hồi mana", "%d / %.1f mỗi giây" % [roundi(s.get_stat(StatId.Id.MAX_MANA)), s.get_stat(StatId.Id.MANA_REGEN)]],
		["Chí mạng", "%d%%" % roundi(s.get_stat(StatId.Id.CRITICAL_CHANCE) * 100.0)],
		["Né tránh", "%d%%" % roundi(s.get_stat(StatId.Id.EVASION) * 100.0)],
		["Hút máu", "%d%%" % roundi(s.get_stat(StatId.Id.LIFESTEAL) * 100.0)],
		["Kháng hiệu ứng", "%d%%" % roundi(s.get_stat(StatId.Id.STATUS_RESISTANCE) * 100.0)],
		["Sức mạnh / Nhanh / Trí", "%d / %d / %d" % [roundi(s.get_stat(StatId.Id.STRENGTH)), roundi(s.get_stat(StatId.Id.AGILITY)), roundi(s.get_stat(StatId.Id.INTELLIGENCE))]],
	]


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
	for row: Array in stat_rows(hero):
		_text(font, p.position + Vector2(28, y), row[0], 20, Color(1, 1, 1, 0.65))
		_text(font, p.position + Vector2(300, y), row[1], 20, Color(0.6, 1, 0.6))
		y += 34.0
	var x: float = 620.0
	y = 100.0
	for row: Array in ability_rows(hero):
		_text(font, p.position + Vector2(x, y), row[0], 22, Color(1, 0.85, 0.35))
		y += 30.0
		for line: String in row[1]:
			_text(font, p.position + Vector2(x + 20, y), line, 17, Color(1, 1, 1, 0.85))
			y += 24.0
		y += 12.0


## Dòng tỷ số: mỗi hero [đội, tên, cấp, K/D/A, LH, giá trị đồ, tên tắt 6 ô].
static func score_rows(w: World) -> Array:
	var out: Array = []
	for team: int in range(2):
		for e: Entity in w.entities:
			if e.kind != Entity.Kind.HERO or e.team != team:
				continue
			var worth: int = 0
			var slots: PackedStringArray = PackedStringArray()
			for it: ItemInstance in Items.slots(e):
				worth += it.def.cost if it != null else 0
				slots.append(ItemButtons.short_name(it.def.display_name) if it != null else "")
			out.append([team, e.hero_def.display_name if e.hero_def != null else "Hero", e.stats.level(),
				"%d/%d/%d" % [e.kills, e.deaths, e.assists], e.last_hits, worth, slots])
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
			var box: Rect2 = Rect2(p.position + Vector2(cols[5] + k * 96, y - 36), Vector2(84, 56))
			draw_rect(box, Color(0.15, 0.17, 0.22, 0.95))
			if row[6][k] != "":
				_text(font, box.get_center() + Vector2(-14, 8), row[6][k], 20, Color.WHITE)
		y += 84.0


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
