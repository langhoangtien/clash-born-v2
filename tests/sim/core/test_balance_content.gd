extends TestCase
## File hệ số thật trong content/ nạp được và hợp lệ (D-32, D-33).

const PATH: String = "res://content/balance/balance_settings.tres"


func test_balance_settings_loads() -> void:
	var bal: BalanceSettings = load(PATH) as BalanceSettings
	assert_true(bal != null, "nạp được " + PATH)
	if bal == null:
		return
	assert_true(bal.validation_errors().is_empty(), ", ".join(bal.validation_errors()))


func test_D_33_evasion_has_no_cap() -> void:
	var bal: BalanceSettings = load(PATH) as BalanceSettings
	assert_eq(bal.evasion_cap, 1.0)


func test_validation_catches_bad_values() -> void:
	var bal: BalanceSettings = (load(PATH) as BalanceSettings).duplicate()
	bal.armor_coefficient = 0.0
	bal.minimum_attacks_per_second = 5.0
	assert_eq(bal.validation_errors().size(), 2)
