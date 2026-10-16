class_name DeathSystem
extends SimSystem
## Pha 11: gỡ đơn vị đã chết. Công trình đổ → ghi vào `destroyed_structures`, phát
## `structure_destroyed`, tính lại khóa (STR-02); nhà chính đổ → kết thúc trận (STR-05).
## Hero không bị gỡ: chờ rồi hồi sinh ở fountain (ECO-04). Thưởng vàng ECO-01/07; XP ở M3.5.


func run(world: World) -> void:
	var structure_fell: bool = false
	var gone: Array[Entity] = []
	for e: Entity in world.entities:
		if e.kind == Entity.Kind.WARD and e.alive and e.expire_tick >= 0 and world.tick >= e.expire_tick:
			e.alive = false  # WRD-02: hết giờ, không ai được thưởng
			e.killer_id = -1
		if e.alive:
			if e.reincarnate_tick >= 0 and world.tick >= e.reincarnate_tick:
				Reincarnation.stand_up(world, e)  # DTH-02
			continue
		if e.kind == Entity.Kind.HERO:
			_hero_waits(world, e)
			continue
		Effects.remove_on_death(world, e)
		if Rules.is_structure(e):
			world.destroyed_structures[e.structure_id] = true
			world.emit(&"structure_destroyed", -1, e.id)
			structure_fell = true
		_reward(world, e)
		gone.append(e)
	for e: Entity in gone:
		world.remove_entity(e)
	if structure_fell:
		Objectives.refresh_locks(world)


func _hero_waits(world: World, e: Entity) -> void:
	if e.respawn_tick < 0:
		Effects.remove_on_death(world, e)  # D-56
		hero_kill_rewards(world, e)
		var wait: float = world.balance.respawn_base + world.balance.respawn_per_level * e.stats.level()
		e.respawn_tick = world.tick + SimClock.seconds_to_ticks(wait)
		e.order = Order.idle()
		e.path = PackedVector2Array()
		e.path_index = 0
		e.attack_phase = Entity.AttackPhase.NONE
		e.lock_target_id = -1
		world.emit(&"hero_died", -1, e.id)
	elif world.tick >= e.respawn_tick:
		_respawn(world, e)


func _respawn(world: World, e: Entity) -> void:
	e.respawn_tick = -1
	e.alive = true
	if world.map != null:
		e.position = world.map.fountain_point(e.team)
	e.health = e.stats.get_stat(StatId.Id.MAX_HP)
	e.mana = e.stats.get_stat(StatId.Id.MAX_MANA)
	e.order = Order.idle()
	world.emit(&"hero_respawned", -1, e.id)


## ECO-01: last hit của hero lấy vàng lính/quái. ECO-07: trụ đổ → mọi hero đội kia nhận
## vàng trụ. STR-05: nhà chính đổ → đội kia thắng.
func _reward(world: World, e: Entity) -> void:
	if e.kind == Entity.Kind.CORE:
		if world.winner < 0:
			world.winner = 1 - e.team
			world.emit(&"match_ended", -1, e.id)
		return
	if e.kind == Entity.Kind.TOWER:
		for hero: Entity in world.entities:
			if hero.kind == Entity.Kind.HERO and hero.team != e.team:
				hero.gold += e.bounty_gold
		return
	var killer: Entity = world.find_entity(e.killer_id)
	if e.kind == Entity.Kind.WARD:
		if killer != null and killer.kind == Entity.Kind.HERO and killer.team != e.team:
			killer.gold += e.bounty_gold  # WRD-05
		return
	if killer != null and killer.kind == Entity.Kind.HERO and killer.team != e.team:
		killer.gold += e.bounty_gold
		killer.last_hits += 1
	if e.kind == Entity.Kind.NEUTRAL:
		_share_neutral_xp(world, e, killer)  # JGL-07
		return
	_share_xp(world, e, e.bounty_xp, null)


## ECO-03: XP chia đều cho hero phe kia còn sống trong `xp_share_range` (kẻ hạ là hero thì
## luôn được tính). Trả về danh sách hero được chia, theo id.
static func _share_xp(world: World, dead: Entity, amount: float, killer: Entity) -> Array[Entity]:
	var takers: Array[Entity] = []
	for h: Entity in world.entities:
		if h.kind != Entity.Kind.HERO or not h.alive or h.team == dead.team:
			continue
		if h == killer or h.position.distance_to(dead.position) <= world.balance.xp_share_range:
			takers.append(h)
	for h: Entity in takers:
		if amount > 0.0:
			Progression.add_xp(world, h, amount / takers.size())
	return takers


## Hạ hero: XP và vàng cho kẻ hạ (hoặc chia cho hero phe kia gần đó nếu trụ/lính hạ);
## nạn nhân mất vàng (ECO-05) trừ khi tái sinh tại chỗ (`lose_gold` = false, DTH-03).
static func hero_kill_rewards(world: World, e: Entity, lose_gold: bool = true) -> void:
	var b: BalanceSettings = world.balance
	var level: int = e.stats.level()
	var killer: Entity = world.find_entity(e.killer_id)
	if killer != null and (killer.kind != Entity.Kind.HERO or killer.team == e.team):
		killer = null
	var takers: Array[Entity] = _share_xp(world, e, b.hero_kill_xp_base + b.hero_kill_xp_per_level * level, killer)
	var gold: int = b.hero_kill_gold_base + b.hero_kill_gold_per_level * level
	var paid: Array[Entity] = takers
	if killer != null:
		paid = [killer]
	for h: Entity in paid:
		h.gold += gold / paid.size()
	if not paid.is_empty():
		world.emit(&"kill_credited", paid[0].id, e.id, gold)
	_count_kda(world, e, killer)
	if lose_gold:
		e.gold = maxi(0, e.gold - b.death_gold_per_level * level)


## ECO-09: kẻ hạ (hero) +1 hạ; nạn nhân +1 chết; hero địch khác đã gây sát thương trong
## `assist_window` giây +1 hỗ trợ.
static func _count_kda(world: World, victim: Entity, killer: Entity) -> void:
	victim.deaths += 1
	if killer != null:
		killer.kills += 1
	var since: int = world.tick - SimClock.seconds_to_ticks(world.balance.assist_window)
	var ids: Array = victim.damaged_by.keys()
	ids.sort()
	for id: int in ids:
		var h: Entity = world.find_entity(id)
		if h != null and h != killer and victim.damaged_by[id] >= since:
			h.assists += 1
	victim.damaged_by.clear()


## JGL-07: XP quái rừng chia cho hero sống cùng phe kẻ hạ trong `xp_share_range`.
func _share_neutral_xp(world: World, dead: Entity, killer: Entity) -> void:
	if killer == null:
		return
	var takers: Array[Entity] = []
	for h: Entity in world.entities:
		if h.kind == Entity.Kind.HERO and h.alive and h.team == killer.team \
				and (h == killer or h.position.distance_to(dead.position) <= world.balance.xp_share_range):
			takers.append(h)
	for h: Entity in takers:
		Progression.add_xp(world, h, float(dead.bounty_xp) / takers.size())
