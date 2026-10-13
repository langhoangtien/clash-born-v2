extends TestCase
## M0.5: validator bắt đúng các lỗi dữ liệu theo luật.

const F = preload("res://tests/content/fixture_content.gd")


func _errors(defs: Array[GameDef]) -> PackedStringArray:
	return ContentValidator.errors(F.library_with(defs))


func _expect_error(defs: Array[GameDef], fragment: String) -> void:
	var errs: PackedStringArray = _errors(defs)
	var joined: String = "\n".join(errs)
	assert_true(joined.contains(fragment), "cần lỗi chứa '%s', có: %s" % [fragment, joined])


func test_valid_fixture_has_no_errors() -> void:
	var errs: PackedStringArray = _errors([F.hero(), F.item()])
	assert_true(errs.is_empty(), "\n".join(errs))


func test_ABL_01_q_needs_five_ranks() -> void:
	var h: HeroDef = F.hero()
	h.q.values[&"damage"] = PackedFloat32Array([1, 2, 3])
	_expect_error([h], "giá trị 'damage' có 3 cấp, cần 5")


func test_ABL_01_r_needs_three_ranks() -> void:
	var h: HeroDef = F.hero()
	h.r.values[&"duration"] = PackedFloat32Array([1, 2, 3, 4, 5])
	_expect_error([h], "giá trị 'duration' có 5 cấp, cần 3")


func test_ABL_11_innate_needs_six_ranks() -> void:
	var h: HeroDef = F.hero()
	h.innate.values[&"chance"] = PackedFloat32Array([1, 2, 3, 4, 5])
	_expect_error([h], "giá trị 'chance' có 5 cấp, cần 6")


func test_ABL_09_action_uses_unknown_named_value() -> void:
	var h: HeroDef = F.hero()
	((h.q.on_cast[0] as AreaAction).actions[0] as DamageAction).amount = "dmg"
	_expect_error([h], "giá trị có tên 'dmg' không có trong kỹ năng")


func test_ABL_09_effect_inside_ability_checked_with_ability_values() -> void:
	var h: HeroDef = F.hero()
	var ghost: EffectDef = (h.r.on_cast[0] as ApplyEffectAction).effect
	ghost.duration = "ghost_time"
	_expect_error([h], "'ghost_time'")


func test_EFF_09_unknown_stat_and_event_field() -> void:
	var h: HeroDef = F.hero()
	var ghost: EffectDef = (h.r.on_cast[0] as ApplyEffectAction).effect
	(ghost.periodic_actions[0] as HealAction).amount = "self.mana_pool"
	_expect_error([h], "chỉ số 'mana_pool'")
	(ghost.periodic_actions[0] as HealAction).amount = "event.total"
	_expect_error([h], "dữ liệu sự kiện 'total'")


func test_EFF_09_no_conditions_or_syntax_errors_in_expressions() -> void:
	var h: HeroDef = F.hero()
	var dmg: DamageAction = (h.q.on_cast[0] as AreaAction).actions[0]
	dmg.amount = "damage > 5"
	_expect_error([h], "ký tự không cho phép '>'")
	dmg.amount = "damage *"
	_expect_error([h], "sai cú pháp")


func test_EFF_09_valid_expressions_accepted() -> void:
	for expr: String in ["20 + 0.3 * self.strength", "max(1, damage)", "event.damage * 0.5", "target.max_hp / 10", "1.5"]:
		assert_true(ExprRules.errors(expr, PackedStringArray(["damage"])).is_empty(), expr)


func test_STAT_01_modifier_stat_must_exist() -> void:
	var h: HeroDef = F.hero()
	var ghost: EffectDef = (h.r.on_cast[0] as ApplyEffectAction).effect
	ghost.modifiers[0].stat = &"speed"
	_expect_error([h], "chỉ số 'speed' không có trong STAT-01")


func test_EVT_trigger_event_and_removed_by_must_exist() -> void:
	var h: HeroDef = F.hero()
	var passive: EffectDef = (h.innate.on_learn[0] as ApplyEffectAction).effect
	passive.triggers[0].event = &"on_hit"
	passive.removed_by = [&"attack_start"]
	_expect_error([h], "sự kiện 'on_hit' không có trong EVT")
	_expect_error([h], "removed_by 'attack_start'")


func test_EFF_08_trigger_condition_must_exist() -> void:
	var h: HeroDef = F.hero()
	var passive: EffectDef = (h.innate.on_learn[0] as ApplyEffectAction).effect
	passive.triggers[0].condition = &"if_lucky"
	_expect_error([h], "điều kiện 'if_lucky'")


func test_effect_tag_must_exist() -> void:
	var e: EffectDef = F.stun()
	e.tags = [&"stunny"]
	_expect_error([e], "tag 'stunny'")


func test_TAL_01_q_w_r_need_talents() -> void:
	var h: HeroDef = F.hero()
	h.w.talent = null
	_expect_error([h], "kỹ năng test_shield thiếu talent")


func test_TAL_02_talent_changes_existing_value_only() -> void:
	var h: HeroDef = F.hero()
	h.q.talent.value_changes[0].value_name = &"range"
	_expect_error([h], "talent sửa giá trị không có: range")


func test_hero_needs_all_slots_in_right_place() -> void:
	var h: HeroDef = F.hero()
	h.w = null
	_expect_error([h], "thiếu kỹ năng ô W")
	h = F.hero()
	h.q.slot = AbilityDef.Slot.R
	_expect_error([h], "đặt ở ô Q nhưng khai báo slot R")


func test_ABL_12_passive_uses_on_learn_not_on_cast() -> void:
	var h: HeroDef = F.hero()
	h.innate.on_cast = [HealAction.new()]
	_expect_error([h], "bị động không có on_cast")


func test_apply_effect_needs_effect() -> void:
	var h: HeroDef = F.hero()
	(h.w.on_cast[0] as ApplyEffectAction).effect = null
	_expect_error([h], "thiếu hiệu ứng")


func test_ITM_02_item_ability_slot_and_cost() -> void:
	var i: ItemDef = F.item()
	i.cost = 0
	i.ability = F.ability(&"test_active", AbilityDef.Slot.Q, ["cooldown"])
	_expect_error([i], "giá phải > 0")
	_expect_error([i], "kỹ năng của đồ phải có slot ITEM")


func test_hero_needs_positive_attack_time() -> void:
	var h: HeroDef = F.hero()
	h.stats.base_attack_time = 0
	_expect_error([h], "base_attack_time phải > 0")
