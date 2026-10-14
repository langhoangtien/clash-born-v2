class_name AutoSkill
extends RefCounted
## Tầng APP (tạm tới M3.8): tự dùng điểm kỹ năng của hero người chơi theo thứ tự gợi ý trong
## HeroDef (bot_skill_order). Chọn mục đầu tiên chưa đạt và đang nâng được.

const UPGRADE_SLOTS: Dictionary = {
	HeroDef.Upgrade.Q: AbilityDef.Slot.Q,
	HeroDef.Upgrade.W: AbilityDef.Slot.W,
	HeroDef.Upgrade.R: AbilityDef.Slot.R,
	HeroDef.Upgrade.ATTRIBUTES: Command.ATTRIBUTES,
}


## Ô nên nâng tiếp (AbilityDef.Slot hoặc Command.ATTRIBUTES); -2 nếu không có gì nâng được.
static func pick(world: World, hero: Entity, order: Array[HeroDef.Upgrade]) -> int:
	if hero.skill_points <= 0:
		return -2
	var wanted: Dictionary = {}
	for u: HeroDef.Upgrade in order:
		var slot: int = UPGRADE_SLOTS[u]
		wanted[slot] = wanted.get(slot, 0) + 1
		if _current(hero, slot) < wanted[slot] and Progression.level_problem(world, hero, slot) == Command.Reject.NONE:
			return slot
	for slot: int in [AbilityDef.Slot.R, AbilityDef.Slot.Q, AbilityDef.Slot.W, Command.ATTRIBUTES]:
		if Progression.level_problem(world, hero, slot) == Command.Reject.NONE:
			return slot
	return -2


static func _current(hero: Entity, slot: int) -> int:
	if slot == Command.ATTRIBUTES:
		return hero.attribute_bonus_count
	var a: AbilityInstance = Abilities.of(hero, slot)
	return a.rank if a != null else 0


## TAL-01 (tạm tới M3.8): talent theo thứ tự ưu tiên của hero; -2 nếu chưa / đã chọn.
static func pick_talent(hero: Entity, priority: Array[AbilityDef.Slot]) -> int:
	if hero.talent_slot >= 0:
		return -2
	for slot: AbilityDef.Slot in priority:
		var a: AbilityInstance = Abilities.of(hero, slot)
		if a != null and a.rank > 0 and a.def.talent != null:
			return slot
	return -2
