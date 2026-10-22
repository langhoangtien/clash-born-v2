class_name StatFormulas
extends RefCounted
## STAT-04 (D-35): thuộc tính → chỉ số; lên cấp chỉ cộng thuộc tính. Công thức v1
## (D-32). Các hàm trả về **phần đóng góp** của thuộc tính; StatBlock (M1.1) cộng
## phần này vào chỉ số gốc rồi áp Modifier theo STAT-02.

enum Attribute { NONE, STRENGTH, AGILITY, INTELLIGENCE }


## Thuộc tính ở `level`: gốc + tăng trưởng × (cấp − 1) + số lần đổi điểm thừa × thưởng.
static func attribute_at_level(base: float, growth: float, level: int,
		bonus_count: int, bonus_per_count: float) -> float:
	return base + growth * maxi(0, level - 1) + bonus_count * bonus_per_count


static func hp_from_strength(strength: float, b: BalanceSettings) -> float:
	return strength * b.hp_per_strength


static func hp_regen_from_strength(strength: float, b: BalanceSettings) -> float:
	return strength * b.hp_regen_per_strength


static func armor_from_agility(agility: float, b: BalanceSettings) -> float:
	return agility * b.armor_per_agility


static func mana_from_intelligence(intelligence: float, b: BalanceSettings) -> float:
	return intelligence * b.mana_per_intelligence


static func mana_regen_from_intelligence(intelligence: float, b: BalanceSettings) -> float:
	return intelligence * b.mana_regen_per_intelligence


static func magic_armor_from_intelligence(intelligence: float, b: BalanceSettings) -> float:
	return intelligence * b.magic_armor_per_intelligence


## CMB-13: khuếch đại phép từ Trí tuệ.
static func spell_amp_from_intelligence(intelligence: float, b: BalanceSettings) -> float:
	return intelligence * b.spell_amp_per_intelligence


static func attack_damage_from_primary(primary: Attribute, strength: float, agility: float,
		intelligence: float, b: BalanceSettings) -> float:
	match primary:
		Attribute.STRENGTH:
			return strength * b.primary_damage_coefficient
		Attribute.AGILITY:
			return agility * b.primary_damage_coefficient
		Attribute.INTELLIGENCE:
			return intelligence * b.primary_damage_coefficient
	return 0.0


## Hệ số tốc đánh: 1 + AGI × k + thưởng (AGI và thưởng cộng trước khi nhân tốc gốc).
static func attack_speed_multiplier(agility: float, bonus: float, b: BalanceSettings) -> float:
	return 1.0 + agility * b.attack_speed_per_agility + bonus


## Số đòn mỗi giây = hệ số / base_attack_time, kẹp trong [sàn, trần]; trần là
## min(trần tuyệt đối, N × tốc gốc) và không vượt khoảng cách tối thiểu giữa 2 đòn.
static func attacks_per_second(base_attack_time: float, multiplier: float, b: BalanceSettings) -> float:
	if base_attack_time <= 0.0:
		return b.minimum_attacks_per_second
	var base_rate: float = 1.0 / base_attack_time
	var cap: float = minf(b.maximum_attacks_per_second, base_rate * b.maximum_attack_speed_multiplier)
	cap = minf(cap, 1.0 / maxf(b.minimum_attack_interval, SimClock.TICK_SECONDS))
	var rate: float = base_rate * multiplier
	return maxf(b.minimum_attacks_per_second, minf(rate, cap))


static func status_resistance(raw: float, b: BalanceSettings) -> float:
	return clampf(raw, 0.0, b.status_resistance_cap)


static func movement_speed(raw: float, b: BalanceSettings) -> float:
	return maxf(b.minimum_movement_speed, raw)
