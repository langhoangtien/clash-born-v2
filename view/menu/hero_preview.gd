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
