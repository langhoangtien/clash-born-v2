class_name DamageFormulas
extends RefCounted
## Công thức sát thương mang từ v1 (D-32). Hàm thuần, không trạng thái.

enum DamageType { PHYSICAL, MAGIC, PURE }


## Giáp sau giảm giáp phẳng (chỉ tính phần dương) rồi xuyên giáp theo tỉ lệ.
static func effective_armor(armor: float, flat_reduction: float, penetration: float) -> float:
	return (armor - maxf(0.0, flat_reduction)) * (1.0 - clampf(penetration, 0.0, 1.0))


## Hệ số nhận sát thương theo giáp. Giáp dương giảm dần, giáp âm tăng dần và chậm lại.
static func armor_multiplier(armor: float, coefficient: float) -> float:
	var positive_curve: float = 1.0 / (1.0 + coefficient * absf(armor))
	return positive_curve if armor >= 0.0 else 2.0 - positive_curve


## CMB-03: vật lý theo giáp vật lý, phép theo giáp phép, thuần bỏ qua giáp.
static func after_armor(raw: float, type: DamageType, physical_armor: float,
		magic_armor: float, balance: BalanceSettings) -> float:
	var amount: float = maxf(0.0, raw)
	match type:
		DamageType.PHYSICAL:
			return amount * armor_multiplier(physical_armor, balance.armor_coefficient)
		DamageType.MAGIC:
			return amount * armor_multiplier(magic_armor, balance.armor_coefficient)
	return amount


## Sau giáp nhân `damage_taken_multiplier` của mục tiêu (STAT-01, CMB-02).
static func final_damage(raw: float, type: DamageType, physical_armor: float,
		magic_armor: float, damage_taken_multiplier: float, balance: BalanceSettings) -> float:
	var reduced: float = after_armor(raw, type, physical_armor, magic_armor, balance)
	return reduced * maxf(0.0, damage_taken_multiplier)
