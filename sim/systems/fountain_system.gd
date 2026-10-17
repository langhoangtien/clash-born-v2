class_name FountainSystem
extends SimSystem
## Pha 8 (sau AttackSystem): fountain hồi máu/mana phe mình và bắn hero địch trong
## `fountain_radius` (STR-04). Fountain không phải đơn vị; không có map thì không làm gì.


func run(world: World) -> void:
	if world.map == null or world.balance.fountain_radius <= 0.0:
		return
	var interval: int = maxi(1, SimClock.seconds_to_ticks(world.balance.fountain_attack_interval))
	var fires: bool = world.tick % interval == 0
	for team: int in range(2):
		var spot: Vector2 = world.map.fountain_point(team)
		for e: Entity in world.entities:  # theo id; ít đơn vị nên duyệt thẳng, khỏi dựng lại lưới
			if not e.alive or e.stats == null or Rules.is_structure(e) or e.position.distance_to(spot) > world.balance.fountain_radius:
				continue
			if e.team == team:
				_heal(world, e)
			elif fires and e.kind == Entity.Kind.HERO and e.team != 2 and e.position.distance_to(spot) <= world.balance.fountain_attack_radius:
				_shoot(world, e)


func _heal(world: World, e: Entity) -> void:
	var rate: float = world.balance.fountain_regen * SimClock.TICK_SECONDS
	e.health = minf(e.stats.get_stat(StatId.Id.MAX_HP), e.health + e.stats.get_stat(StatId.Id.MAX_HP) * rate)
	e.mana = minf(e.stats.get_stat(StatId.Id.MAX_MANA), e.mana + e.stats.get_stat(StatId.Id.MAX_MANA) * rate)


func _shoot(world: World, e: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = e.id
	r.raw = world.balance.fountain_damage
	r.damage_type = DamageFormulas.DamageType.PURE
	world.damage_requests.append(r)
	world.emit(&"fountain_shot", -1, e.id)
