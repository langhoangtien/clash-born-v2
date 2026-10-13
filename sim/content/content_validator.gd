class_name ContentValidator
extends RefCounted
## Kiểm tra dữ liệu trong ContentLibrary theo luật (M0.5): số cấp của giá trị, tên giá
## trị trong biểu thức, tên chỉ số/sự kiện/điều kiện/tag, tham chiếu không rỗng,
## đủ ô và talent của hero.

var _errors: PackedStringArray = PackedStringArray()


static func errors(lib: ContentLibrary) -> PackedStringArray:
	var v: ContentValidator = ContentValidator.new()
	v._errors.append_array(lib.load_errors)
	for id: StringName in lib.heroes:
		v._check_hero(lib.heroes[id])
	for id: StringName in lib.abilities:
		v._check_ability(lib.abilities[id], String(id))
	for id: StringName in lib.items:
		v._check_item(lib.items[id])
	for id: StringName in lib.units:
		v._check_unit(lib.units[id])
	for id: StringName in lib.effects:
		# Hiệu ứng đứng riêng chưa biết kỹ năng nào áp nó: chỉ kiểm tra cấu trúc.
		v._walk(lib.effects[id], String(id), null)
	return v._errors


func _check_hero(hero: HeroDef) -> void:
	var where: String = String(hero.id)
	if hero.stats == null:
		_fail(where, "thiếu stats")
	elif hero.stats.base_attack_time <= 0.0:
		_fail(where, "base_attack_time phải > 0")
	_check_bot_order(hero, where)
	var slots: Array[AbilityDef.Slot] = [AbilityDef.Slot.INNATE, AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]
	var abilities: Array[AbilityDef] = hero.abilities()
	for i: int in range(4):
		var ability: AbilityDef = abilities[i]
		var slot_name: String = AbilityDef.Slot.keys()[slots[i]]
		if ability == null:
			_fail(where, "thiếu kỹ năng ô " + slot_name)
			continue
		if ability.slot != slots[i]:
			_fail(where, "kỹ năng %s đặt ở ô %s nhưng khai báo slot %s" % [ability.id, slot_name, AbilityDef.Slot.keys()[ability.slot]])
		if slots[i] != AbilityDef.Slot.INNATE and ability.talent == null:
			_fail(where, "kỹ năng %s thiếu talent (TAL-01)" % ability.id)
		_check_ability(ability, "%s.%s" % [where, ability.id])


func _check_ability(ability: AbilityDef, where: String) -> void:
	var ranks: int = ability.expected_ranks()
	for key: StringName in ability.values:
		if ability.values[key].size() != ranks:
			_fail(where, "giá trị '%s' có %d cấp, cần %d" % [key, ability.values[key].size(), ranks])
	if ability.targeting == AbilityDef.Targeting.PASSIVE and not ability.on_cast.is_empty():
		_fail(where, "kỹ năng bị động không có on_cast (dùng on_learn)")
	if ability.talent != null:
		for change: ValueChangeDef in ability.talent.value_changes:
			if not ability.values.has(change.value_name):
				_fail(where, "talent sửa giá trị không có: " + change.value_name)
	_walk(ability, where, ability.value_names())


func _check_item(item: ItemDef) -> void:
	var where: String = String(item.id)
	if item.cost <= 0:
		_fail(where, "giá phải > 0")
	if item.ability != null:
		if item.ability.slot != AbilityDef.Slot.ITEM:
			_fail(where, "kỹ năng của đồ phải có slot ITEM")
		_check_ability(item.ability, where + ".ability")
	_walk(item, where, PackedStringArray())


func _check_unit(unit: UnitDef) -> void:
	if unit.stats == null:
		_fail(String(unit.id), "thiếu stats")
	for ability: AbilityDef in unit.abilities:
		if ability != null:
			_check_ability(ability, "%s.%s" % [unit.id, ability.id])
	_walk(unit, String(unit.id), PackedStringArray())


## Duyệt mọi trường đã lưu của `res` và các Resource con. `names` = giá trị có tên của
## kỹ năng đang xét; null = không kiểm tra tên (chỉ cú pháp và self./event.).
func _walk(res: Resource, where: String, names: Variant, seen: Dictionary = {}) -> void:
	if res == null or seen.has(res.get_instance_id()):
		return
	if res is AbilityDef and not seen.is_empty():
		return  # kỹ năng con được kiểm tra riêng bởi chủ của nó (hero, đồ, đơn vị)
	seen[res.get_instance_id()] = true
	_check_names(res, where)
	for prop: Dictionary in res.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (prop["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var field: String = prop["name"]
		var value: Variant = res.get(field)
		var at: String = "%s.%s" % [where, field]
		if value is String and not GameDef.TEXT_FIELDS.has(field):
			_check_expr(value, at, names)
		elif value is Resource:
			_walk(value, at, names, seen)
		elif value is Array:
			for element: Variant in value:
				if element is Resource:
					_walk(element, at, names, seen)


func _check_expr(expr: String, where: String, names: Variant) -> void:
	var known: PackedStringArray = names if names != null else ExprRules.named_values(expr)
	for problem: String in ExprRules.errors(expr, known):
		_fail(where, problem)


func _check_names(res: Resource, where: String) -> void:
	if res is ModifierDef and not RuleCatalog.STATS.has(String(res.stat)):
		_fail(where, "chỉ số '%s' không có trong STAT-01" % res.stat)
	elif res is TriggerDef:
		if not RuleCatalog.EVENTS.has(String(res.event)):
			_fail(where, "sự kiện '%s' không có trong EVT" % res.event)
		if not RuleCatalog.TRIGGER_CONDITIONS.has(String(res.condition)):
			_fail(where, "điều kiện '%s' không có" % res.condition)
	elif res is EffectDef:
		for event: StringName in res.removed_by:
			if not RuleCatalog.EVENTS.has(String(event)):
				_fail(where, "removed_by '%s' không có trong EVT" % event)
		for tag: StringName in res.tags:
			if not RuleCatalog.EFFECT_TAGS.has(String(tag)):
				_fail(where, "tag '%s' không có trong luật" % tag)
	elif (res is ApplyEffectAction or res is RemoveEffectAction or res is EffectPatchDef) and res.effect == null:
		_fail(where, "thiếu hiệu ứng")


func _fail(where: String, message: String) -> void:
	_errors.append("%s: %s" % [where, message])


## BOT-14 + ABL-04: thứ tự nâng của bot phải hợp lệ ở từng cấp.
func _check_bot_order(hero: HeroDef, where: String) -> void:
	var ranks: Dictionary[HeroDef.Upgrade, int] = {HeroDef.Upgrade.Q: 0, HeroDef.Upgrade.W: 0, HeroDef.Upgrade.R: 0, HeroDef.Upgrade.ATTRIBUTES: 0}
	var limits: Dictionary[HeroDef.Upgrade, int] = {HeroDef.Upgrade.Q: 5, HeroDef.Upgrade.W: 5, HeroDef.Upgrade.R: 3, HeroDef.Upgrade.ATTRIBUTES: 7}
	const R_LEVELS: Array[int] = [6, 11, 16]
	if hero.bot_skill_order.size() > 20:
		_fail(where, "bot_skill_order dài hơn 20 cấp")
	for i: int in range(hero.bot_skill_order.size()):
		var level: int = i + 1
		var up: HeroDef.Upgrade = hero.bot_skill_order[i]
		var name: String = HeroDef.Upgrade.keys()[up]
		ranks[up] += 1
		var rank: int = ranks[up]
		if rank > limits[up]:
			_fail(where, "đổi thuộc tính quá 7 lần" if up == HeroDef.Upgrade.ATTRIBUTES else "%s quá cấp tối đa" % name)
		elif up == HeroDef.Upgrade.R and level < R_LEVELS[rank - 1]:
			_fail(where, "cấp %d nâng R lên %d (cần cấp %d)" % [level, rank, R_LEVELS[rank - 1]])
		elif (up == HeroDef.Upgrade.Q or up == HeroDef.Upgrade.W) and level < 2 * rank - 1:
			_fail(where, "cấp %d nâng %s lên %d (cần cấp %d)" % [level, name, rank, 2 * rank - 1])
	var talents: Array[AbilityDef.Slot] = hero.bot_talent_priority.duplicate()
	talents.sort()
	if talents != [AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]:
		_fail(where, "bot_talent_priority phải gồm Q, W, R mỗi ô một lần")
