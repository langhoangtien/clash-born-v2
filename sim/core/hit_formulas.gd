class_name HitFormulas
extends RefCounted
## CMB-11 (D-33): né và chính xác nhân dồn; trượt = né × (1 − chính xác).
## Chỉ tính xác suất. Tung xúc xắc (PRD) thuộc hệ thống đòn đánh (M3.6b).


## 1 − Π(1 − c): xác suất ít nhất một nguồn độc lập xảy ra.
static func combine_independent(chances: Array[float]) -> float:
	var none_happen: float = 1.0
	for chance: float in chances:
		none_happen *= 1.0 - clampf(chance, 0.0, 1.0)
	return 1.0 - none_happen


static func evasion(sources: Array[float], balance: BalanceSettings) -> float:
	return minf(combine_independent(sources), balance.evasion_cap)


static func accuracy(sources: Array[float]) -> float:
	return combine_independent(sources)


static func miss_chance(target_evasion: float, attacker_accuracy: float) -> float:
	return clampf(target_evasion, 0.0, 1.0) * (1.0 - clampf(attacker_accuracy, 0.0, 1.0))
