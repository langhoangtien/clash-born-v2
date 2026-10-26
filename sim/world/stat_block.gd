class_name StatBlock
extends RefCounted
## Cách DUY NHẤT để có chỉ số cuối (STAT-02, STAT-03). Gộp: gốc → (thuộc tính, STAT-04)
## → ADD → MULTIPLY (phần trăm cộng nhau, D-40) → OVERRIDE (cái thêm sau cùng) → giới hạn. Nhóm duy nhất: STAT-05.
## Né và chính xác gộp nhân dồn (CMB-11).

const S = StatId.Id
const ATTRIBUTES: Array[int] = [S.STRENGTH, S.AGILITY, S.INTELLIGENCE]
## Cộng kiểu xác suất độc lập 1 − Π(1 − v): né/chính xác (CMB-11), giảm hồi chiêu (ABL-19),
## giảm sát thương vật lý (CMB-16), kháng hiệu ứng (ST-09, D-167).
const INDEPENDENT: Array[int] = [S.EVASION, S.ACCURACY, S.COOLDOWN_REDUCTION, S.PHYSICAL_DAMAGE_REDUCTION, S.STATUS_RESISTANCE]

var dirty: bool = true
var balance: BalanceSettings

var _base: PackedFloat64Array = PackedFloat64Array()
var _final: PackedFloat64Array = PackedFloat64Array()
var _modifiers: Array[StatModifier] = []
var _primary: StatFormulas.Attribute = StatFormulas.Attribute.NONE
var _attr_base: Vector3 = Vector3.ZERO
var _attr_growth: Vector3 = Vector3.ZERO
var _level: int = 1
var _bonus_count: int = 0
var _bonus_per_count: float = 0.0


func _init(p_balance: BalanceSettings) -> void:
	balance = p_balance
	_base.resize(S.size())
	_final.resize(S.size())
	_base[S.DAMAGE_TAKEN_MULTIPLIER] = 1.0


func set_base(stat: S, value: float) -> void:
	_base[stat] = value
	dirty = true


## Hero: thuộc tính gốc và tăng mỗi cấp (x = STR, y = AGI, z = INT).
## Giá trị gốc (trước modifier, thuộc tính) của một chỉ số.
func base(stat: S) -> float:
	return _base[stat]


func set_attributes(primary: StatFormulas.Attribute, base: Vector3, growth: Vector3) -> void:
	_primary = primary
	_attr_base = base
	_attr_growth = growth
	dirty = true


func level() -> int:
	return _level


func set_level(level: int, bonus_count: int, bonus_per_count: float) -> void:
	_level = level
	_bonus_count = bonus_count
	_bonus_per_count = bonus_per_count
	dirty = true


func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	dirty = true


func remove_source(source_id: int) -> void:
	_modifiers = _modifiers.filter(func(m: StatModifier) -> bool: return m.source_id != source_id)
	dirty = true


func get_stat(stat: S) -> float:
	return _final[stat]


## Giá trị "trắng" kiểu Dota (D-124): thuộc tính chỉ từ gốc + tăng theo cấp; sát thương đòn
## đánh = gốc + phần thuộc tính chính "trắng"; BAT gốc. Chỉ đọc, VIEW dùng để tách "120 + 70".
func natural(stat: S) -> float:
	var attrs: Vector3 = Vector3.ZERO
	for i: int in range(3):
		attrs[i] = _base[ATTRIBUTES[i]] + StatFormulas.attribute_at_level(_attr_base[i], _attr_growth[i], _level, _bonus_count, _bonus_per_count)
	match stat:
		S.STRENGTH:
			return attrs.x
		S.AGILITY:
			return attrs.y
		S.INTELLIGENCE:
			return attrs.z
		S.PHYSICAL_DAMAGE:
			return _base[S.PHYSICAL_DAMAGE] + StatFormulas.attack_damage_from_primary(_primary, attrs.x, attrs.y, attrs.z, balance)
	return _base[stat]


func values() -> PackedFloat64Array:
	return _final


func attacks_per_second() -> float:
	return StatFormulas.attacks_per_second(_final[S.BASE_ATTACK_TIME], _final[S.ATTACK_SPEED], balance)


func recompute() -> void:
	var active: Array[StatModifier] = _apply_unique_groups()
	var base: PackedFloat64Array = _base.duplicate()
	for i: int in range(3):
		base[ATTRIBUTES[i]] += StatFormulas.attribute_at_level(_attr_base[i], _attr_growth[i], _level, _bonus_count, _bonus_per_count)
		_final[ATTRIBUTES[i]] = _combine(ATTRIBUTES[i], base[ATTRIBUTES[i]], active)
	_add_attribute_contributions(base)
	for stat: int in range(S.size()):
		if not ATTRIBUTES.has(stat):
			_final[stat] = _combine(stat, base[stat], active)
	_apply_limits()
	dirty = false


## STAT-04: phần thuộc tính (đã có modifier) cộng vào gốc của chỉ số dẫn xuất.
func _add_attribute_contributions(base: PackedFloat64Array) -> void:
	var strength: float = _final[S.STRENGTH]
	var agility: float = _final[S.AGILITY]
	var intelligence: float = _final[S.INTELLIGENCE]
	base[S.MAX_HP] += StatFormulas.hp_from_strength(strength, balance)
	base[S.HP_REGEN] += StatFormulas.hp_regen_from_strength(strength, balance)
	base[S.PHYSICAL_ARMOR] += StatFormulas.armor_from_agility(agility, balance)
	base[S.MAX_MANA] += StatFormulas.mana_from_intelligence(intelligence, balance)
	base[S.MANA_REGEN] += StatFormulas.mana_regen_from_intelligence(intelligence, balance)
	base[S.MAGIC_ARMOR] += StatFormulas.magic_armor_from_intelligence(intelligence, balance)
	base[S.SPELL_AMPLIFICATION] += StatFormulas.spell_amp_from_intelligence(intelligence, balance)  # CMB-13
	base[S.PHYSICAL_DAMAGE] += StatFormulas.attack_damage_from_primary(_primary, strength, agility, intelligence, balance)
	base[S.ATTACK_SPEED] += StatFormulas.attack_speed_multiplier(agility, 0.0, balance)


func _combine(stat: int, base: float, active: Array[StatModifier]) -> float:
	var adds: Array[float] = []
	var factor: float = 1.0
	var override_value: float = NAN
	for m: StatModifier in active:
		if m.stat != stat:
			continue
		match m.op:
			ModifierDef.Op.ADD:
				adds.append(m.value)
			ModifierDef.Op.MULTIPLY:
				factor += m.value - 1.0  # D-40: phần trăm cộng với nhau
			ModifierDef.Op.OVERRIDE:
				override_value = m.value
	var value: float = base
	if INDEPENDENT.has(stat):
		adds.append(base)
		value = HitFormulas.combine_independent(adds)  # CMB-11, ABL-19
	else:
		for a: float in adds:
			value += a
	value *= maxf(0.0, factor)
	return value if is_nan(override_value) else override_value


## STAT-05 (D-55): trong mỗi nhóm chỉ giữ một nguồn: đồ thắng skill, đồ ô sau thắng ô trước;
## hòa (không phải đồ) thì id nguồn nhỏ hơn.
func _apply_unique_groups() -> Array[StatModifier]:
	var winners: Dictionary[StringName, StatModifier] = {}
	for m: StatModifier in _modifiers:
		if m.unique_group.is_empty():
			continue
		var best: StatModifier = winners.get(m.unique_group)
		if best == null or m.item_slot > best.item_slot \
				or (m.item_slot == best.item_slot and m.source_id < best.source_id):
			winners[m.unique_group] = m
	return _modifiers.filter(func(m: StatModifier) -> bool:
		return m.unique_group.is_empty() or winners[m.unique_group].source_id == m.source_id)


func _apply_limits() -> void:
	_final[S.MAX_HP] = maxf(1.0, _final[S.MAX_HP])
	_final[S.MAX_MANA] = maxf(0.0, _final[S.MAX_MANA])
	_final[S.MOVEMENT_SPEED] = StatFormulas.movement_speed(_final[S.MOVEMENT_SPEED], balance)
	_final[S.STATUS_RESISTANCE] = StatFormulas.status_resistance(_final[S.STATUS_RESISTANCE], balance)
	_final[S.EVASION] = minf(clampf(_final[S.EVASION], 0.0, 1.0), balance.evasion_cap)
	_final[S.ACCURACY] = clampf(_final[S.ACCURACY], 0.0, 1.0)
	_final[S.CRITICAL_CHANCE] = clampf(_final[S.CRITICAL_CHANCE], 0.0, 1.0)
	_final[S.PHYSICAL_ARMOR_PENETRATION] = clampf(_final[S.PHYSICAL_ARMOR_PENETRATION], 0.0, 1.0)
	_final[S.LIFESTEAL] = maxf(0.0, _final[S.LIFESTEAL])
	_final[S.PHYSICAL_DAMAGE] = maxf(0.0, _final[S.PHYSICAL_DAMAGE])  # DUL-07
	_final[S.COOLDOWN_REDUCTION] = clampf(_final[S.COOLDOWN_REDUCTION], 0.0, 1.0)  # ABL-19
	_final[S.PHYSICAL_DAMAGE_REDUCTION] = clampf(_final[S.PHYSICAL_DAMAGE_REDUCTION], 0.0, 1.0)  # CMB-16
	_final[S.DAMAGE_TAKEN_MULTIPLIER] = maxf(0.0, _final[S.DAMAGE_TAKEN_MULTIPLIER])
