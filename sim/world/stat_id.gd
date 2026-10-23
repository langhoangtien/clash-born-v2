class_name StatId
extends RefCounted
## Chỉ số theo STAT-01, cùng thứ tự với RuleCatalog.STATS (test kiểm tra). Thêm chỉ số
## = thay đổi luật.

enum Id {
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	MAX_HP,
	MAX_MANA,
	HP_REGEN,
	MANA_REGEN,
	PHYSICAL_DAMAGE,
	MAGIC_DAMAGE,
	PURE_DAMAGE,
	PHYSICAL_ARMOR,
	MAGIC_ARMOR,
	ATTACK_RANGE,
	CAST_RANGE,
	BASE_ATTACK_TIME,
	ATTACK_SPEED,
	MOVEMENT_SPEED,
	VISION_RANGE,
	EVASION,
	ACCURACY,
	CRITICAL_CHANCE,
	CRITICAL_MULTIPLIER,
	STATUS_RESISTANCE,
	ARMOR_REDUCTION,
	PHYSICAL_ARMOR_PENETRATION,
	LIFESTEAL,
	DAMAGE_TAKEN_MULTIPLIER,
	SPELL_AMPLIFICATION,
	MAGIC_ARMOR_REDUCTION,
	COOLDOWN_REDUCTION,
}


## Chỉ số của tên trong dữ liệu (`"max_hp"` → MAX_HP); -1 nếu không có.
static func from_name(stat_name: String) -> int:
	return Id.keys().find(stat_name.to_upper())
