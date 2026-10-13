class_name RuleCatalog
extends RefCounted
## Danh sách tên do luật định nghĩa. Thêm tên ở đây = thay đổi luật (sửa GAME_RULES
## trước). Dữ liệu trong content/ chỉ được dùng các tên này.

## STAT-01
const STATS: PackedStringArray = [
	"strength", "agility", "intelligence", "max_hp", "max_mana", "hp_regen", "mana_regen",
	"physical_damage", "magic_damage", "pure_damage", "physical_armor", "magic_armor",
	"attack_range", "cast_range", "base_attack_time", "attack_speed", "movement_speed",
	"vision_range", "evasion", "accuracy", "critical_chance", "critical_multiplier",
	"status_resistance", "armor_reduction", "physical_armor_penetration", "lifesteal",
	"damage_taken_multiplier",
]

## EVT
const EVENTS: PackedStringArray = [
	"attack_started", "attack_landed", "attack_missed", "damage_taken", "hero_attacked_hero",
	"ability_cast", "ability_finished", "effect_applied", "effect_removed", "unit_died",
	"kill_credited", "structure_destroyed", "unit_spawned", "gold_changed", "level_up",
	"skill_leveled", "talent_chosen", "dash_finished", "projectile_hit", "item_used",
	"knockback_finished", "dispelled", "attack_target_changed", "innate_ranked", "mana_burned",
	"lethal_damage", "reincarnated",
]

## EFF-09: dữ liệu sự kiện dùng được trong biểu thức (`event.damage`…).
const EVENT_FIELDS: PackedStringArray = ["damage", "burned_mana", "heal"]

## EFF-09: ngoài STATS, biểu thức đọc được các trường này của `self.` / `target.`.
const UNIT_FIELDS: PackedStringArray = ["current_hp", "current_mana", "level"]

## EFF-09: hàm cho phép trong biểu thức.
const FUNCTIONS: PackedStringArray = ["min", "max"]

## Điều kiện của trigger (EFF-08). Thêm điều kiện = thay đổi luật.
const TRIGGER_CONDITIONS: PackedStringArray = ["", "target_not_structure", "target_is_hero"]

## EFF-02, ST-09, ST-16…: tag hiệu ứng có ý nghĩa trong luật.
const EFFECT_TAGS: PackedStringArray = ["debuff", "buff", "passive", "unique", "dispellable"]


static func unit_field_ok(field: String) -> bool:
	return STATS.has(field) or UNIT_FIELDS.has(field)
