class_name HeroPreview
extends RefCounted
## Màn chọn tướng (D-123): dữ liệu xem trước của một tướng — dựng hero thật ở cấp 1 và cấp 20
## trong một World riêng (không chạy) để đọc chỉ số đúng công thức trận đấu.

var def: HeroDef
var lv1: Entity
var lv20: Entity


static func of(def: HeroDef, balance: BalanceSettings) -> HeroPreview:
	var p: HeroPreview = HeroPreview.new()
	p.def = def
	var w: World = World.new(1, balance)
	p.lv1 = UnitFactory.hero(w, def, 0, Vector2.ZERO, 1)
	p.lv20 = UnitFactory.hero(w, def, 0, Vector2.ZERO, balance.hero_max_level)
	return p


## Thuộc tính chính theo chữ.
func primary_name() -> String:
	return ["—", "Sức mạnh", "Nhanh nhẹn", "Trí tuệ"][def.primary_attribute]


## Dòng bảng chỉ số: [tên, cấp 1, cấp 20, màu] (chưa có đồ nên không có phần cộng thêm).
func stat_table() -> Array:
	var a: Array = InfoPanels.stat_rows(lv1)
	var b: Array = InfoPanels.stat_rows(lv20)
	var out: Array = []
	for i: int in range(mini(a.size(), b.size())):
		out.append([a[i][0], a[i][1], b[i][1], a[i][3]])
	return out


## "+3.5 Sức mạnh, +1.9 Nhanh, +2.1 Trí mỗi cấp".
func growth_text() -> String:
	return "Mỗi cấp: +%.2f Sức mạnh · +%.2f Nhanh nhẹn · +%.2f Trí tuệ" % [def.strength_growth, def.agility_growth, def.intelligence_growth]


## Kỹ năng: [AbilityDef, tiêu đề, các dòng số theo cấp].
func skill_rows() -> Array:
	var out: Array = []
	var rows: Array = InfoPanels.ability_rows(lv1)
	var defs: Array[AbilityDef] = [def.innate, def.q, def.w, def.r]
	for i: int in range(mini(rows.size(), defs.size())):
		var key: String = ["Nội tại", "Q", "W", "R"][i]
		var target: String = ["Bị động", "Không chọn mục tiêu", "Chọn đơn vị", "Chọn điểm", "Chọn hướng"][defs[i].targeting]
		out.append([defs[i], "%s · %s" % [key, defs[i].display_name], target, rows[i][1]])
	return out


## Talent: [ô, AbilityDef, TalentDef].
func talents() -> Array:
	var out: Array = []
	for d: AbilityDef in [def.q, def.w, def.r]:
		if d != null and d.talent != null:
			out.append([["Q", "W", "R"][d.slot - 1], d, d.talent])
	return out


## Giá trị là tỉ lệ (ghi %).
const PERCENT: Array[StringName] = [&"chance", &"crit_chance", &"heal_fraction", &"slow", &"move_bonus", &"amplify",
	&"speed_bonus", &"attack_speed_bonus", &"reflect", &"block_chance", &"reflect_heal"]
## Giá trị kỹ thuật không hiện cho người chơi.
const HIDDEN: Array[StringName] = [&"dash_speed", &"block_ranged"]


## Số chiêu gọn kiểu ảnh mẫu (D-130): "Sát thương: 70 – 230 · Choáng (s): 0.8 – 1.6", hồi chiêu và
## mana cuối cùng; hai giá trị mỗi dòng.
static func compact_lines(d: AbilityDef) -> PackedStringArray:
	var names: Array = d.values.keys()
	var last: Array[StringName] = [&"cast_range", &"cooldown", &"mana"]
	names.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ka: int = last.find(a)
		var kb: int = last.find(b)
		return String(a) < String(b) if ka == kb else ka < kb)
	var parts: PackedStringArray = PackedStringArray()
	for n: StringName in names:
		var arr: PackedFloat32Array = d.values[n]
		if arr.is_empty() or HIDDEN.has(n) or (arr[0] == 0.0 and arr[arr.size() - 1] == 0.0):
			continue
		var pct: bool = PERCENT.has(n)
		var a: String = InfoPanels._num(arr[0] * (100.0 if pct else 1.0))
		var b: String = InfoPanels._num(arr[arr.size() - 1] * (100.0 if pct else 1.0))
		var label: String = InfoPanels.VALUE_NAMES.get(n, String(n))
		var unit: String = "%" if pct else ""
		if label.ends_with(" (s)"):
			label = label.trim_suffix(" (s)")
			unit = " giây"
		parts.append("%s: %s%s" % [label.trim_suffix(" +"), a if a == b else "%s – %s" % [a, b], unit])
	var out: PackedStringArray = PackedStringArray()
	for i: int in range(0, parts.size(), 2):
		out.append(parts[i] if i + 1 >= parts.size() else parts[i] + "  ·  " + parts[i + 1])
	return out
