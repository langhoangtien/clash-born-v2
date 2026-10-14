class_name ExprUnit
extends RefCounted
## Đọc `self.<tên>` / `target.<tên>` trong biểu thức: chỉ số STAT-01 và current_hp,
## current_mana, level (RuleCatalog.UNIT_FIELDS).

var unit: Entity


func _get(property: StringName) -> Variant:
	if unit == null:
		return 0.0
	match property:
		&"current_hp":
			return unit.health
		&"current_mana":
			return unit.mana
		&"level":
			return float(unit.stats.level()) if unit.stats != null else 1.0
	var stat: int = StatId.from_name(property)
	if stat < 0 or unit.stats == null:
		return null
	return unit.stats.get_stat(stat)
