class_name QuickCast
extends RefCounted
## Tầng APP: bấm nút chiêu là tung ngay, tự nhắm kiểu Liên Quân (tạm tới khi có kéo nhắm ở
## M3.8). Đơn vị / điểm / hướng nhắm vào hero địch gần nhất trong tầm chiêu + tầm tìm; không có
## thì đơn vị địch gần nhất; không có ai thì điểm/hướng theo hướng đang nhìn.


static func command(world: World, hero: Entity, slot: int) -> Command:
	var a: AbilityInstance = Abilities.of(hero, slot)
	if a == null:
		return Command.cast(hero.id, slot)
	var reach: float = Abilities.value(hero, a, &"cast_range")
	match a.def.targeting:
		AbilityDef.Targeting.UNIT:
			if a.def.target_team != AbilityDef.Team.ENEMY:
				return Command.cast(hero.id, slot, hero.id)
			var t: Entity = target(world, hero, a, reach)
			return Command.cast(hero.id, slot, t.id if t != null else -1)
		AbilityDef.Targeting.POINT:
			var t: Entity = target(world, hero, a, reach)
			var at: Vector2 = t.position if t != null else hero.position + hero.facing * maxf(reach, 300.0)
			return Command.cast(hero.id, slot, -1, at)
		AbilityDef.Targeting.DIRECTION:
			var t: Entity = target(world, hero, a, reach)
			var dir: Vector2 = (t.position - hero.position) if t != null else hero.facing
			return Command.cast(hero.id, slot, -1, Vector2.INF, dir if dir.length() > 0.001 else hero.facing)
	return Command.cast(hero.id, slot)


## Hero địch gần nhất trong tầm, rồi đơn vị địch hợp lệ gần nhất.
static func target(world: World, hero: Entity, a: AbilityInstance, reach: float) -> Entity:
	var search: float = (reach if reach > 0.0 else 600.0) + world.balance.attack_search_bonus
	var best: Entity = null
	for e: Entity in world.entities:
		if not Abilities.accepts(hero, a.def, e) or Rules.edge_distance(hero, e) > search:
			continue
		if best == null or (e.kind == Entity.Kind.HERO) != (best.kind == Entity.Kind.HERO):
			if best == null or e.kind == Entity.Kind.HERO:
				best = e
			continue
		if Rules.edge_distance(hero, e) < Rules.edge_distance(hero, best):
			best = e
	return best
