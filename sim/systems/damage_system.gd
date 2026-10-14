class_name DamageSystem
extends SimSystem
## Pha 9: trừ máu (CMB-02, CMB-03): sau giáp nhân `damage_taken_multiplier`. Phát
## `attack_landed`, `damage_taken`, và `unit_died` khi máu về 0. Chỉ hệ thống này trừ máu.


func run(world: World) -> void:
	resolve(world)


## Xử lý mọi yêu cầu đang chờ (TriggerSystem cũng gọi để sát thương của trigger có ngay).
static func resolve(world: World) -> void:
	var requests: Array[DamageRequest] = world.damage_requests
	world.damage_requests = []
	for r: DamageRequest in requests:
		var target: Entity = world.find_entity(r.target_id)
		if target == null or not target.alive or target.locked:
			continue  # STR-02: công trình khóa không nhận sát thương
		var source: Entity = world.find_entity(r.source_id)
		if r.is_attack and _misses(world, source, target):
			world.emit(&"attack_missed", r.source_id, r.target_id)
			world.note(&"miss", target.position)
			continue
		var s: StatBlock = target.stats
		var amount: float = DamageFormulas.final_damage(r.raw * _structure_factor(world, source, target), r.damage_type,
			s.get_stat(StatId.Id.PHYSICAL_ARMOR), s.get_stat(StatId.Id.MAGIC_ARMOR),
			s.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), world.balance)
		var factor: float = Rules.damage_factor(world, target, r.damage_type)  # ST-07, ST-11
		if factor <= 0.0:
			continue
		amount *= factor
		if r.is_attack:
			world.emit(&"attack_landed", r.source_id, r.target_id, amount, &"crit" if r.crit else &"")
			if source != null and source.kind == Entity.Kind.HERO and target.kind == Entity.Kind.HERO and source.team != target.team:
				world.emit(&"hero_attacked_hero", r.source_id, r.target_id)  # DEF-11
		amount = Effects.absorb(world, target, amount)  # EFF-06
		target.health -= amount
		if amount > 0.0 and (target.kind == Entity.Kind.HERO or (source != null and source.kind == Entity.Kind.HERO)):
			world.note(&"crit" if r.crit else &"damage", target.position, amount)
		world.emit(&"damage_taken", r.source_id, r.target_id, amount, &"reflected" if r.reflected else &"")
		if target.health <= 0.0:
			target.health = 0.0
			target.alive = false
			target.killer_id = r.source_id
			world.emit(&"unit_died", r.source_id, r.target_id)


## CMB-04: hệ số sát thương lên công trình theo loại kẻ gây.
static func _structure_factor(world: World, source: Entity, target: Entity) -> float:
	if not Rules.is_structure(target) or source == null:
		return 1.0
	match source.kind:
		Entity.Kind.HERO:
			return world.balance.hero_structure_damage
		Entity.Kind.LANE_CREEP:
			return world.balance.siege_structure_damage if source.siege else world.balance.creep_structure_damage  # CRP-10
	return 1.0


## CMB-11: trượt = né × (1 − chính xác), tung PRD theo mục tiêu lúc đòn chạm. Công trình không né.
static func _misses(world: World, source: Entity, target: Entity) -> bool:
	if Rules.is_structure(target):
		return false
	var accuracy: float = source.stats.get_stat(StatId.Id.ACCURACY) if source != null and source.stats != null else 0.0
	var chance: float = HitFormulas.miss_chance(target.stats.get_stat(StatId.Id.EVASION), accuracy)
	return chance > 0.0 and Prd.roll(world, Prd.key(target.id, 999), chance)
