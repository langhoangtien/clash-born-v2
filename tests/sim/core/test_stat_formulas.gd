extends TestCase
## STAT-04 (D-35): thuộc tính → chỉ số; lên cấp chỉ cộng thuộc tính. Số từ test v1.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const STR: int = StatFormulas.Attribute.STRENGTH
const AGI: int = StatFormulas.Attribute.AGILITY
const INT: int = StatFormulas.Attribute.INTELLIGENCE
const NONE: int = StatFormulas.Attribute.NONE
const EPS: float = 0.0001

var bal: BalanceSettings


func before_each() -> void:
	bal = Fixture.make()


func test_STAT_04_strength_gives_hp_and_regen() -> void:
	assert_near(100 + StatFormulas.hp_from_strength(10, bal), 300.0, EPS)
	assert_near(2 + StatFormulas.hp_regen_from_strength(10, bal), 2.5, EPS)


func test_STAT_04_intelligence_gives_mana_regen_and_magic_armor() -> void:
	assert_near(20 + StatFormulas.mana_from_intelligence(20, bal), 260.0, EPS)
	assert_near(1 + StatFormulas.mana_regen_from_intelligence(20, bal), 1.8, EPS)
	assert_near(-5 + StatFormulas.magic_armor_from_intelligence(20, bal), -2.0, EPS)


func test_STAT_04_agility_gives_fractional_armor_keeping_negatives() -> void:
	assert_near(-10 + StatFormulas.armor_from_agility(40, bal), -4.0, EPS)


func test_STAT_04_attack_damage_from_primary_attribute() -> void:
	assert_near(100 + StatFormulas.attack_damage_from_primary(AGI, 10, 40, 20, bal), 140.0, EPS)
	assert_near(100 + StatFormulas.attack_damage_from_primary(STR, 10, 40, 20, bal), 110.0, EPS)
	assert_near(100 + StatFormulas.attack_damage_from_primary(INT, 10, 40, 20, bal), 120.0, EPS)
	assert_near(100 + StatFormulas.attack_damage_from_primary(NONE, 10, 40, 20, bal), 100.0, EPS)


func test_STAT_04_level_up_adds_only_attribute_growth() -> void:
	assert_near(StatFormulas.attribute_at_level(28, 3.5, 1, 0, 2), 28.0, EPS, "cấp 1 = gốc")
	assert_near(StatFormulas.attribute_at_level(28, 3.5, 10, 0, 2), 59.5, EPS, "9 lần tăng × 3.5")
	assert_near(StatFormulas.attribute_at_level(28, 3.5, 10, 3, 2), 65.5, EPS, "3 lần đổi điểm thừa × 2")


func test_STAT_04_level_up_damage_comes_only_from_attribute() -> void:
	# Hero STR chính: gốc 80 sát thương, STR 28 tăng 3.5/cấp. Cấp 10 hơn cấp 1 đúng 31.5.
	var lv1: float = 80 + StatFormulas.attack_damage_from_primary(STR, StatFormulas.attribute_at_level(28, 3.5, 1, 0, 2), 0, 0, bal)
	var lv10: float = 80 + StatFormulas.attack_damage_from_primary(STR, StatFormulas.attribute_at_level(28, 3.5, 10, 0, 2), 0, 0, bal)
	assert_near(lv10 - lv1, 31.5, EPS)


func test_STAT_04_attack_speed_agility_and_bonus_add_before_base() -> void:
	var mult: float = StatFormulas.attack_speed_multiplier(40, 0.3, bal)
	assert_near(StatFormulas.attacks_per_second(1.0 / 1.5, mult, bal), 2.25, EPS)


func test_STAT_02_attack_speed_limits() -> void:
	assert_near(StatFormulas.attacks_per_second(0.01, 1.0, bal), 4.2, EPS, "trần")
	assert_near(StatFormulas.attacks_per_second(10.0, 1.0, bal), 0.3, EPS, "sàn")
	assert_near(StatFormulas.attacks_per_second(0.0, 1.0, bal), 0.3, EPS, "BAT không hợp lệ → sàn")
	bal.minimum_attack_interval = 0.5
	assert_near(StatFormulas.attacks_per_second(0.01, 1.0, bal), 2.0, EPS, "khoảng cách tối thiểu")


func test_STAT_02_attack_speed_cap_scales_with_base() -> void:
	# Trần = min(4.2, 7 × tốc gốc): hero BAT 2.0 (0.5 đòn/s) tối đa 3.5 đòn/s.
	assert_near(StatFormulas.attacks_per_second(2.0, 100.0, bal), 3.5, EPS)


func test_STAT_02_status_resistance_and_move_speed_limits() -> void:
	assert_near(StatFormulas.status_resistance(0.9, bal), 0.6, EPS)
	assert_near(StatFormulas.status_resistance(-0.5, bal), 0.0, EPS)
	assert_near(StatFormulas.movement_speed(40, bal), 100.0, EPS)
	assert_near(StatFormulas.movement_speed(300, bal), 300.0, EPS)
