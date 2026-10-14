class_name UnitFactory
extends RefCounted
## Dựng Entity từ dữ liệu content/ rồi thêm vào World (cấp id, đầy máu/mana).


static func hero(world: World, def: HeroDef, team: int, position: Vector2, level: int = 1) -> Entity:
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.HERO
	e.team = team
	e.position = position
	e.radius = def.stats.collision_radius
	e.art_id = def.art_id
	e.attack_point = def.stats.attack_point
	e.projectile_speed = def.stats.projectile_speed
	e.stats = stats_from(world.balance, def.stats)
	e.stats.set_attributes(def.primary_attribute,
		Vector3(def.base_strength, def.base_agility, def.base_intelligence),
		Vector3(def.strength_growth, def.agility_growth, def.intelligence_growth))
	e.stats.set_level(level, 0, world.balance.attribute_bonus)
	world.add_entity(e)
	Abilities.setup_hero(world, e, def)
	return e


## Lính, quái, công trình từ UnitDef.
static func unit(world: World, def: UnitDef, kind: Entity.Kind, team: int, position: Vector2) -> Entity:
	var e: Entity = Entity.new()
	e.kind = kind
	e.team = team
	e.position = position
	e.radius = def.stats.collision_radius
	e.art_id = def.art_id
	e.attack_point = def.stats.attack_point
	e.projectile_speed = def.stats.projectile_speed
	e.stats = stats_from(world.balance, def.stats)
	e.bounty_gold = def.bounty_gold
	return world.add_entity(e)


## Chỉ số gốc dùng chung cho hero và đơn vị khác (STAT-01).
static func stats_from(balance: BalanceSettings, s: CombatStatsDef) -> StatBlock:
	var b: StatBlock = StatBlock.new(balance)
	b.set_base(StatId.Id.MAX_HP, s.base_hp)
	b.set_base(StatId.Id.MAX_MANA, s.base_mana)
	b.set_base(StatId.Id.HP_REGEN, s.base_hp_regen)
	b.set_base(StatId.Id.MANA_REGEN, s.base_mana_regen)
	b.set_base(StatId.Id.PHYSICAL_DAMAGE, s.base_damage)
	b.set_base(StatId.Id.PHYSICAL_ARMOR, s.physical_armor)
	b.set_base(StatId.Id.MAGIC_ARMOR, s.magic_armor)
	b.set_base(StatId.Id.BASE_ATTACK_TIME, s.base_attack_time)
	b.set_base(StatId.Id.ATTACK_RANGE, s.attack_range)
	b.set_base(StatId.Id.MOVEMENT_SPEED, s.movement_speed)
	b.set_base(StatId.Id.VISION_RANGE, s.vision_range)
	return b
