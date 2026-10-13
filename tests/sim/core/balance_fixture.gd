extends RefCounted
## Hệ số cố định cho test công thức (bằng số của v1), để test công thức không đỏ khi
## cân bằng lại content/balance/balance_settings.tres.


static func make() -> BalanceSettings:
	var b: BalanceSettings = BalanceSettings.new()
	b.hp_per_strength = 20.0
	b.hp_regen_per_strength = 0.05
	b.armor_per_agility = 0.15
	b.magic_armor_per_intelligence = 0.15
	b.mana_per_intelligence = 12.0
	b.mana_regen_per_intelligence = 0.04
	b.primary_damage_coefficient = 1.0
	b.armor_coefficient = 0.06
	b.attack_speed_per_agility = 0.005
	b.minimum_attacks_per_second = 0.3
	b.maximum_attacks_per_second = 4.2
	b.maximum_attack_speed_multiplier = 7.0
	b.minimum_attack_interval = 0.1
	b.evasion_cap = 1.0
	b.status_resistance_cap = 0.6
	b.minimum_movement_speed = 100.0
	b.separation_speed = 400.0
	b.attribute_bonus = 2.0
	b.tower_body_radius = 52.0
	return b
