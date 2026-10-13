extends TestCase
## CMB-02, CMB-03, STAT-01 (damage_taken_multiplier). Số mong đợi lấy từ test v1.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const PHYSICAL: int = DamageFormulas.DamageType.PHYSICAL
const MAGIC: int = DamageFormulas.DamageType.MAGIC
const PURE: int = DamageFormulas.DamageType.PURE
const EPS: float = 0.0001

var bal: BalanceSettings


func before_each() -> void:
	bal = Fixture.make()


func test_CMB_03_armor_table_matches_v1() -> void:
	var cases: Dictionary = {0.0: 100.0, 10.0: 62.5, 20.0: 45.454545, 30.0: 35.714286,
		-10.0: 137.5, -20.0: 154.545455, -30.0: 164.285714, -100.0: 185.714286}
	for armor: float in cases:
		assert_near(DamageFormulas.after_armor(100, PHYSICAL, armor, 999, bal), cases[armor], EPS, "giáp vật lý %s" % armor)
		assert_near(DamageFormulas.after_armor(100, MAGIC, 999, armor, bal), cases[armor], EPS, "giáp phép %s" % armor)


func test_CMB_03_magic_uses_magic_armor() -> void:
	assert_near(DamageFormulas.after_armor(200, MAGIC, 0, 20, bal), 90.909091, EPS)


func test_CMB_03_pure_ignores_all_armor() -> void:
	assert_near(DamageFormulas.after_armor(200, PURE, 50, 50, bal), 200.0, EPS)
	assert_near(DamageFormulas.after_armor(100, PURE, -100, -100, bal), 100.0, EPS)


func test_CMB_03_fractional_armor() -> void:
	assert_near(DamageFormulas.after_armor(100, PHYSICAL, 0.5, 0, bal), 100.0 / 1.03, EPS)


func test_CMB_03_negative_damage_never_heals() -> void:
	assert_eq(DamageFormulas.after_armor(-10, PURE, 0, 0, bal), 0.0)


func test_CMB_03_negative_armor_amplifies_with_diminishing_returns() -> void:
	var a0: float = DamageFormulas.armor_multiplier(0, 0.06)
	var a10: float = DamageFormulas.armor_multiplier(-10, 0.06)
	var a20: float = DamageFormulas.armor_multiplier(-20, 0.06)
	var a30: float = DamageFormulas.armor_multiplier(-30, 0.06)
	assert_true(a30 > a20 and a20 > a10 and a10 > a0, "giáp càng âm càng đau")
	assert_true(a30 - a20 < a20 - a10 and a20 - a10 < a10 - a0, "tăng chậm dần")


func test_CMB_03_effective_armor_reduction_then_penetration() -> void:
	assert_near(DamageFormulas.effective_armor(20, 5, 0.5), 7.5, EPS)
	assert_near(DamageFormulas.effective_armor(20, -5, 0.0), 20.0, EPS, "giảm giáp âm bị bỏ qua")
	assert_near(DamageFormulas.effective_armor(20, 0, 2.0), 0.0, EPS, "xuyên giáp tối đa 100%")


func test_STAT_01_damage_taken_multiplier_after_armor() -> void:
	assert_near(DamageFormulas.final_damage(100, PHYSICAL, 10, 0, 1.5, bal), 62.5 * 1.5, EPS)
	assert_near(DamageFormulas.final_damage(100, PURE, 0, 0, 0.0, bal), 0.0, EPS)
	assert_near(DamageFormulas.final_damage(100, PURE, 0, 0, -1.0, bal), 0.0, EPS, "hệ số âm không hồi máu")
