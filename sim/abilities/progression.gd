class_name Progression
extends RefCounted
## Lên cấp hero (ABL-04, ABL-11, STAT-04): XP, điểm kỹ năng, đổi điểm lấy thuộc tính, nội tại
## tự lên bậc. Lên cấp cộng máu/mana hiện tại đúng phần tối đa tăng thêm.

## ABL-11: cấp hero mở bậc nội tại 1..6.
const INNATE_LEVELS: Array[int] = [1, 4, 8, 12, 16, 20]
## ABL-04: cấp hero tối thiểu để R lên bậc 1..3.
const ULTIMATE_LEVELS: Array[int] = [6, 11, 16]


static func xp_to_next(world: World, level: int) -> int:
	return world.balance.xp_base + world.balance.xp_per_level * (level - 1)


static func add_xp(world: World, hero: Entity, amount: float) -> void:
	if hero.stats.level() >= world.balance.hero_max_level:
		return
	hero.xp += amount
	while hero.stats.level() < world.balance.hero_max_level and hero.xp >= xp_to_next(world, hero.stats.level()):
		hero.xp -= xp_to_next(world, hero.stats.level())
		_level_up(world, hero)
	if hero.stats.level() >= world.balance.hero_max_level:
		hero.xp = 0.0


static func _level_up(world: World, hero: Entity) -> void:
	_apply_level(hero, hero.stats.level() + 1, hero.attribute_bonus_count, world.balance.attribute_bonus)
	hero.skill_points += 1
	var innate: AbilityInstance = Abilities.of(hero, AbilityDef.Slot.INNATE)
	var rank: int = INNATE_LEVELS.filter(func(l: int) -> bool: return hero.stats.level() >= l).size()
	if innate != null and innate.rank != rank:
		Abilities.set_rank(world, hero, innate, rank)
	world.emit(&"level_up", hero.id, hero.id, hero.stats.level())


## Đổi cấp / số lần cộng thuộc tính; máu, mana hiện tại cộng phần tối đa tăng thêm.
static func _apply_level(hero: Entity, level: int, bonus_count: int, bonus: float) -> void:
	var max_hp: float = hero.stats.get_stat(StatId.Id.MAX_HP)
	var max_mana: float = hero.stats.get_stat(StatId.Id.MAX_MANA)
	hero.stats.set_level(level, bonus_count, bonus)
	hero.stats.recompute()
	hero.health += maxf(0.0, hero.stats.get_stat(StatId.Id.MAX_HP) - max_hp)
	hero.mana += maxf(0.0, hero.stats.get_stat(StatId.Id.MAX_MANA) - max_mana)


## Lý do không dùng điểm được (NONE = được).
static func level_problem(world: World, hero: Entity, slot: int) -> Command.Reject:
	if hero.skill_points <= 0:
		return Command.Reject.NO_SKILL_POINT
	if slot == Command.ATTRIBUTES:
		return Command.Reject.NONE if hero.attribute_bonus_count < world.balance.attribute_bonus_max else Command.Reject.CANNOT_LEVEL
	var a: AbilityInstance = Abilities.of(hero, slot)
	if a == null or slot == AbilityDef.Slot.INNATE or a.rank >= a.def.expected_ranks():
		return Command.Reject.CANNOT_LEVEL
	var need: int = ULTIMATE_LEVELS[a.rank] if slot == AbilityDef.Slot.R else 2 * (a.rank + 1) - 1
	return Command.Reject.NONE if hero.stats.level() >= need else Command.Reject.CANNOT_LEVEL


static func spend_point(world: World, hero: Entity, slot: int) -> void:
	hero.skill_points -= 1
	if slot == Command.ATTRIBUTES:
		hero.attribute_bonus_count += 1
		_apply_level(hero, hero.stats.level(), hero.attribute_bonus_count, world.balance.attribute_bonus)
	else:
		var a: AbilityInstance = Abilities.of(hero, slot)
		Abilities.set_rank(world, hero, a, a.rank + 1)
	world.emit(&"skill_leveled", hero.id, hero.id, slot)


## TAL-01: chọn được talent ô `slot` không.
static func talent_problem(world: World, hero: Entity, slot: int) -> Command.Reject:
	var a: AbilityInstance = Abilities.of(hero, slot)
	if hero.talent_slot >= 0 or hero.stats.level() < world.balance.talent_level:
		return Command.Reject.CANNOT_CHOOSE_TALENT
	if a == null or a.def.talent == null or a.rank <= 0:
		return Command.Reject.CANNOT_CHOOSE_TALENT
	return Command.Reject.NONE


## TAL-04: có hiệu lực ngay; bị động áp lại với giá trị mới, hiệu ứng đang chạy giữ nguyên.
static func choose_talent(world: World, hero: Entity, slot: int) -> void:
	var a: AbilityInstance = Abilities.of(hero, slot)
	hero.talent_slot = slot
	a.talent_active = true
	if not a.def.on_learn.is_empty():
		Abilities.set_rank(world, hero, a, a.rank)
	world.emit(&"talent_chosen", hero.id, hero.id, slot)
