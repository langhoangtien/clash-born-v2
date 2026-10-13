extends TestCase
## M1.1: StatBlock — STAT-02 (thứ tự gộp), STAT-03, STAT-04 (thuộc tính), STAT-05 (nhóm
## duy nhất), CMB-11 (né/chính xác nhân dồn).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const EPS: float = 0.0001

var bal: BalanceSettings


func before_each() -> void:
	bal = Fixture.make()


func _block() -> StatBlock:
	var b: StatBlock = StatBlock.new(bal)
	b.set_base(StatId.Id.MAX_HP, 500)
	b.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	b.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	return b


func _mod(stat: StatId.Id, op: ModifierDef.Op, value: float, source: int, group: StringName = &"", priority: float = NAN) -> StatModifier:
	return StatModifier.make(stat, op, value, source, group, value if is_nan(priority) else priority)


func test_STAT_02_base_then_add_then_multiply() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.MULTIPLY, 1.2, 1))
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.ADD, 50, 2))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MOVEMENT_SPEED), (300 + 50) * 1.2, EPS)


func test_STAT_02_override_last_applied_wins_then_limits() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.OVERRIDE, 140, 1))
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.OVERRIDE, 60, 2))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MOVEMENT_SPEED), 100.0, EPS, "OVERRIDE sau cùng (60) rồi giới hạn sàn 100")


func test_STAT_03_recompute_is_idempotent_and_removal_restores() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 250, 7))
	b.recompute()
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MAX_HP), 750.0, EPS, "tính lại không cộng dồn")
	b.remove_source(7)
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MAX_HP), 500.0, EPS)


func test_STAT_03_recompute_only_when_dirty() -> void:
	var b: StatBlock = _block()
	b.recompute()
	assert_false(b.dirty)
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 1, 1))
	assert_true(b.dirty)


func test_STAT_04_brakk_level_10_from_attributes_only() -> void:
	var b: StatBlock = StatBlock.new(bal)
	b.set_base(StatId.Id.MAX_HP, 1100)
	b.set_base(StatId.Id.PHYSICAL_DAMAGE, 74)
	b.set_base(StatId.Id.PHYSICAL_ARMOR, 4.5)
	b.set_base(StatId.Id.BASE_ATTACK_TIME, 2.0)
	b.set_attributes(StatFormulas.Attribute.STRENGTH, Vector3(30, 16, 15), Vector3(3.8, 1.5, 1.4))
	b.set_level(10, 0, 2.0)
	b.recompute()
	var strength: float = 30 + 3.8 * 9
	var agility: float = 16 + 1.5 * 9
	assert_near(b.get_stat(StatId.Id.STRENGTH), strength, EPS)
	assert_near(b.get_stat(StatId.Id.MAX_HP), 1100 + strength * 20, EPS)
	assert_near(b.get_stat(StatId.Id.PHYSICAL_DAMAGE), 74 + strength, EPS, "sát thương chỉ tăng nhờ thuộc tính chính")
	assert_near(b.get_stat(StatId.Id.PHYSICAL_ARMOR), 4.5 + agility * 0.15, EPS)
	assert_near(b.get_stat(StatId.Id.ATTACK_SPEED), 1 + agility * 0.005, EPS)


func test_STAT_04_attribute_bonus_points() -> void:
	var b: StatBlock = StatBlock.new(bal)
	b.set_attributes(StatFormulas.Attribute.AGILITY, Vector3(20, 33, 15), Vector3(1.9, 4.2, 1.3))
	b.set_level(1, 3, 2.0)
	b.recompute()
	assert_near(b.get_stat(StatId.Id.AGILITY), 39.0, EPS, "3 lần đổi điểm × 2")


func test_STAT_04_attribute_modifier_flows_into_derived_stats() -> void:
	var b: StatBlock = StatBlock.new(bal)
	b.set_base(StatId.Id.MAX_HP, 1000)
	b.set_attributes(StatFormulas.Attribute.STRENGTH, Vector3(10, 0, 0), Vector3.ZERO)
	b.set_level(1, 0, 2.0)
	b.add_modifier(_mod(StatId.Id.STRENGTH, ModifierDef.Op.ADD, 10, 1))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MAX_HP), 1000 + 20 * 20, EPS)
	assert_near(b.get_stat(StatId.Id.PHYSICAL_DAMAGE), 20, EPS)


func test_STAT_05_two_boots_only_fastest_counts() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.ADD, 50, 1, &"move_speed_boots"))
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.ADD, 65, 2, &"move_speed_boots"))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MOVEMENT_SPEED), 365.0, EPS)


func test_STAT_05_strongest_slow_only() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.MULTIPLY, 0.7, 1, &"slow", 0.3))
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.MULTIPLY, 0.5, 2, &"slow", 0.5))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MOVEMENT_SPEED), 150.0, EPS, "chỉ chậm 50%")


func test_STAT_05_group_winner_keeps_its_other_modifiers_loser_drops_all() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.ADD, 10, 1, &"g", 10))
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 100, 1, &"g", 10))
	b.add_modifier(_mod(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.ADD, 40, 2, &"g", 40))
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 5, 2, &"g", 40))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MOVEMENT_SPEED), 340.0, EPS)
	assert_near(b.get_stat(StatId.Id.MAX_HP), 505.0, EPS)


func test_STAT_05_tie_goes_to_smaller_source_id() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 30, 9, &"g", 1))
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 20, 4, &"g", 1))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MAX_HP), 520.0, EPS)


func test_STAT_05_ungrouped_modifiers_stack() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 30, 1))
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 30, 2))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.MAX_HP), 560.0, EPS)


func test_CMB_11_evasion_and_accuracy_sources_multiply() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.EVASION, ModifierDef.Op.ADD, 0.5, 1))
	b.add_modifier(_mod(StatId.Id.EVASION, ModifierDef.Op.ADD, 0.5, 2))
	b.add_modifier(_mod(StatId.Id.ACCURACY, ModifierDef.Op.ADD, 0.8, 3))
	b.add_modifier(_mod(StatId.Id.ACCURACY, ModifierDef.Op.ADD, 0.8, 4))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.EVASION), 0.75, EPS)
	assert_near(b.get_stat(StatId.Id.ACCURACY), 0.96, EPS)


func test_STAT_02_limits() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.STATUS_RESISTANCE, ModifierDef.Op.ADD, 0.9, 1))
	b.add_modifier(_mod(StatId.Id.CRITICAL_CHANCE, ModifierDef.Op.ADD, 1.5, 1))
	b.add_modifier(_mod(StatId.Id.MAX_HP, ModifierDef.Op.ADD, -9999, 1))
	b.add_modifier(_mod(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, ModifierDef.Op.ADD, -5, 1))
	b.recompute()
	assert_near(b.get_stat(StatId.Id.STATUS_RESISTANCE), 0.6, EPS)
	assert_near(b.get_stat(StatId.Id.CRITICAL_CHANCE), 1.0, EPS)
	assert_near(b.get_stat(StatId.Id.MAX_HP), 1.0, EPS)
	assert_near(b.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 0.0, EPS)


func test_damage_taken_multiplier_defaults_to_one() -> void:
	var b: StatBlock = _block()
	b.recompute()
	assert_near(b.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.0, EPS)


func test_attacks_per_second_uses_attack_speed_and_bat() -> void:
	var b: StatBlock = _block()
	b.add_modifier(_mod(StatId.Id.ATTACK_SPEED, ModifierDef.Op.ADD, 0.7, 1))
	b.recompute()
	assert_near(b.attacks_per_second(), 1.7 / 1.7, EPS)


func test_STAT_01_stat_ids_match_rule_catalog() -> void:
	assert_eq(StatId.Id.size(), RuleCatalog.STATS.size())
	for i: int in range(RuleCatalog.STATS.size()):
		assert_eq(StatId.from_name(RuleCatalog.STATS[i]), i, RuleCatalog.STATS[i])
	assert_eq(StatId.from_name("speed"), -1)
