class_name DamageSystem
extends SimSystem
## Pha 9: trừ máu (CMB-02, CMB-03): sau giáp nhân `damage_taken_multiplier`. Phát
## `attack_landed`, `damage_taken`, và `unit_died` khi máu về 0. Chỉ hệ thống này trừ máu.


func run(world: World) -> void:
	resolve(world)


## Xử lý mọi yêu cầu đang chờ (TriggerSystem cũng gọi để sát thương của trigger có ngay).
static func resolve(world: World) -> void:
	var queue: Array[DamageRequest] = world.damage_requests
	world.damage_requests = []
	var i: int = 0
	while i < queue.size():
		var r: DamageRequest = queue[i]
		i += 1
		var target: Entity = world.find_entity(r.target_id)
		if _apply(world, r, target, queue, i) and target.alive:
			var back: DamageRequest = Duels.reflect_for(r, target)  # DUL-04/05: còn sống mới phản
			if back != null:
				queue.insert(i, back)


## Một yêu cầu; true nếu sát thương đã trừ vào máu (kể cả 0).
static func _apply(world: World, r: DamageRequest, target: Entity, queue: Array[DamageRequest], at: int) -> bool:
	if target == null or not target.alive or target.locked or target.reincarnate_tick >= 0:
		return false  # STR-02: công trình khóa không nhận sát thương; DTH-02: đang nằm chờ tái sinh
	var source: Entity = world.find_entity(r.source_id)
	if target.kind == Entity.Kind.WARD and not r.is_attack:
		return false  # WRD-04: chỉ đòn đánh phá được ward
	if r.is_attack and _misses(world, source, target):
		world.emit(&"attack_missed", r.source_id, r.target_id)
		world.note(&"miss", target.position)
		return false
	var deflected: DamageRequest = AttackDeflect.check(world, r, source, target)  # CMB-15
	if deflected != null:
		world.emit(&"attack_deflected", r.source_id, r.target_id)
		world.note(&"deflect", target.position)
		queue.insert(at, deflected)
		return false
	var amount: float = _amount(world, r, source, target)
	if amount < 0.0:
		return false
	if r.is_attack:
		world.emit(&"attack_landed", r.source_id, r.target_id, amount, &"crit" if r.crit else &"").raw = r.raw
		if source != null and source.kind == Entity.Kind.HERO and target.kind == Entity.Kind.HERO and source.team != target.team:
			world.emit(&"hero_attacked_hero", r.source_id, r.target_id)  # DEF-11
	if r.is_attack and not r.reflected and source != null and source.alive and not Rules.is_structure(target):
		var steal: float = source.stats.get_stat(StatId.Id.LIFESTEAL)
		if steal > 0.0:
			ActionRunner.heal(world, source, amount * steal, source.id)  # CMB-05b
	if r.heal_source > 0.0 and source != null and source.alive:
		ActionRunner.heal(world, source, amount * r.heal_source, source.id)  # DUL-04b
	amount = Effects.absorb(world, target, amount)  # EFF-06
	if source != null and source.kind == Entity.Kind.HERO and target.kind == Entity.Kind.HERO and source.team != target.team:
		target.damaged_by[source.id] = world.tick  # ECO-09
	target.health -= amount
	if amount > 0.0 and (target.kind == Entity.Kind.HERO or (source != null and source.kind == Entity.Kind.HERO)):
		world.note(&"crit" if r.crit else &"damage", target.position, amount)
	world.emit(&"damage_taken", r.source_id, r.target_id, amount, &"reflected" if r.reflected else &"")
	if target.health <= 0.0 and Reincarnation.try_prevent(world, target, r.source_id):
		return true  # DTH-01
	if target.health <= 0.0:
		target.health = 0.0
		target.alive = false
		target.killer_id = r.source_id
		world.emit(&"unit_died", r.source_id, r.target_id)
		Duels.on_death(world, target)  # DUL-05
	return true


## Sát thương sau giáp, hệ số nhận, state (PRI-05), ward (WRD-04); −1 = miễn hoàn toàn.
static func _amount(world: World, r: DamageRequest, source: Entity, target: Entity) -> float:
	var s: StatBlock = target.stats
	var raw: float = r.raw
	var amount: float = DamageFormulas.final_damage(raw * _structure_factor(world, source, target), r.damage_type,
		s.get_stat(StatId.Id.PHYSICAL_ARMOR), _magic_armor(source, target),
		s.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), world.balance)
	if r.damage_type == DamageFormulas.DamageType.PHYSICAL:
		amount *= 1.0 - s.get_stat(StatId.Id.PHYSICAL_DAMAGE_REDUCTION)  # CMB-16
	var factor: float = Rules.damage_factor(world, target, r.damage_type, r.pierces_magic_immunity)  # PRI-05
	if factor <= 0.0:
		return -1.0
	amount *= factor
	if target.kind == Entity.Kind.WARD:  # WRD-04: máu ward tính theo đòn
		amount = world.balance.ward_hero_hit if source != null and source.kind == Entity.Kind.HERO else world.balance.ward_other_hit
	return amount


## CMB-14 (D-132): giáp phép mục tiêu trừ `magic_armor_reduction` của kẻ gây (chỉ với sát thương của kẻ đó).
static func _magic_armor(source: Entity, target: Entity) -> float:
	var armor: float = target.stats.get_stat(StatId.Id.MAGIC_ARMOR)
	if source == null:
		return armor
	return DamageFormulas.effective_armor(armor, source.stats.get_stat(StatId.Id.MAGIC_ARMOR_REDUCTION), 0.0)


## CMB-04: hệ số sát thương lên công trình theo loại kẻ gây; CMB-04b: trụ lên lính đường.
static func _structure_factor(world: World, source: Entity, target: Entity) -> float:
	if source != null and source.kind == Entity.Kind.TOWER and target.kind == Entity.Kind.LANE_CREEP:
		return world.balance.tower_creep_damage  # CMB-04b
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
