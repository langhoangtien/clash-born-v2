extends TestCase
## CMB-11 (D-33): né và chính xác nhân dồn; trượt = né × (1 − chính xác).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const EPS: float = 0.000001

var bal: BalanceSettings


func before_each() -> void:
	bal = Fixture.make()


func test_CMB_11_two_50_percent_evasion_items_give_75() -> void:
	assert_near(HitFormulas.evasion([0.5, 0.5], bal), 0.75, EPS)


func test_CMB_11_evasion_from_v1_cases() -> void:
	assert_near(HitFormulas.evasion([0.3, 0.3], bal), 0.51, EPS)
	assert_near(HitFormulas.evasion([0.3, 0.25, 0.25], bal), 0.60625, EPS)
	assert_near(HitFormulas.evasion([], bal), 0.0, EPS)


func test_CMB_11_full_evasion_allowed_without_cap() -> void:
	assert_near(HitFormulas.evasion([1.0], bal), 1.0, EPS)


func test_CMB_11_evasion_cap_is_configurable() -> void:
	bal.evasion_cap = 0.75
	assert_near(HitFormulas.evasion([0.9, 0.9], bal), 0.75, EPS)


func test_CMB_11_out_of_range_sources_clamped() -> void:
	assert_near(HitFormulas.evasion([1.5, -0.2], bal), 1.0, EPS)
	assert_near(HitFormulas.accuracy([-1.0]), 0.0, EPS)


func test_CMB_11_two_80_percent_accuracy_items_give_96() -> void:
	assert_near(HitFormulas.accuracy([0.8, 0.8]), 0.96, EPS)


func test_CMB_11_windrun_vs_one_accuracy_item_hits_80_of_100() -> void:
	assert_near(HitFormulas.miss_chance(1.0, HitFormulas.accuracy([0.8])), 0.2, EPS)


func test_CMB_11_windrun_vs_two_accuracy_items_hits_96_of_100() -> void:
	assert_near(HitFormulas.miss_chance(1.0, HitFormulas.accuracy([0.8, 0.8])), 0.04, EPS)


func test_CMB_11_v1_accuracy_cases() -> void:
	assert_near(HitFormulas.miss_chance(0.5, 0.6), 0.2, EPS)
	assert_near(HitFormulas.miss_chance(0.75, 1.0), 0.0, EPS)
	assert_near(HitFormulas.miss_chance(0.0, 0.0), 0.0, EPS)
