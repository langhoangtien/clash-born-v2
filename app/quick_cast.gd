class_name QuickCast
extends RefCounted
## Tầng APP: dựng lệnh CAST từ nút chiêu kiểu Liên Quân. Chạm (command): tự nhắm vào hero địch
## gần nhất trong tầm chiêu + tầm tìm, không có thì đơn vị địch gần nhất, không có ai thì theo
## hướng đang nhìn. Kéo (aimed): hướng + khoảng kéo (0..1 của tầm). PC (at_point): nhắm vào con trỏ.


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
			if ward_of(a) != null:
				return Command.cast(hero.id, slot, -1, hero.position)  # D-92: chạm nút mắt = cắm dưới chân
			var t: Entity = target(world, hero, a, reach)
			var at: Vector2 = t.position if t != null else hero.position + hero.facing * maxf(reach, 300.0)
			return Command.cast(hero.id, slot, -1, at)
		AbilityDef.Targeting.DIRECTION:
			var t: Entity = target(world, hero, a, reach)
			var dir: Vector2 = (t.position - hero.position) if t != null else hero.facing
			return Command.cast(hero.id, slot, -1, Vector2.INF, dir if dir.length() > 0.001 else hero.facing)
	return Command.cast(hero.id, slot)


## CTL-06: mục tiêu đang khóa / đang đánh (D-75), rồi hero địch gần nhất trong tầm, rồi đơn vị
## địch hợp lệ gần nhất.
static func target(world: World, hero: Entity, a: AbilityInstance, reach: float) -> Entity:
	var search: float = (reach if reach > 0.0 else 600.0) + world.balance.attack_search_bonus
	var focus: int = hero.lock_target_id
	if focus < 0 and hero.order.type == Order.Type.ATTACK and not hero.order.finished:
		focus = hero.order.target_id
	var preferred: Entity = world.find_entity(focus) if focus >= 0 else null
	if preferred != null and Abilities.accepts(hero, a.def, preferred) and Rules.edge_distance(hero, preferred) <= search:
		return preferred
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


## Kéo nút để nhắm: `aim` dài 0..1 = tỉ lệ tầm chiêu theo hướng kéo (D-59: không quá tầm).
## Chiêu chọn đơn vị (D-108, kiểu Liên Quân): chọn kẻ địch lệch ít nhất so với hướng kéo.
static func aimed(world: World, hero: Entity, slot: int, aim: Vector2) -> Command:
	var a: AbilityInstance = Abilities.of(hero, slot)
	if a == null or aim.length() < 0.001:
		return command(world, hero, slot)
	if a.def.targeting == AbilityDef.Targeting.UNIT and a.def.target_team == AbilityDef.Team.ENEMY:
		var t: Entity = unit_for_aim(world, hero, a, aim)
		return Command.cast(hero.id, slot, t.id) if t != null else command(world, hero, slot)
	return at_point(world, hero, slot, hero.position + aim.limit_length(1.0) * reach_of(hero, a))


## Nhắm vào một điểm trên map (con trỏ chuột / điểm kéo tới).
static func at_point(world: World, hero: Entity, slot: int, point: Vector2) -> Command:
	var a: AbilityInstance = Abilities.of(hero, slot)
	if a == null:
		return Command.cast(hero.id, slot)
	var dir: Vector2 = point - hero.position
	match a.def.targeting:
		AbilityDef.Targeting.POINT:
			return Command.cast(hero.id, slot, -1, point)
		AbilityDef.Targeting.DIRECTION:
			return Command.cast(hero.id, slot, -1, Vector2.INF, dir if dir.length() > 0.001 else hero.facing)
		AbilityDef.Targeting.UNIT:
			var best: Entity = null
			for e: Entity in world.entities:
				if Abilities.accepts(hero, a.def, e) and Rules.edge_distance(hero, e) <= reach_of(hero, a) + world.balance.attack_search_bonus:
					if best == null or e.position.distance_to(point) < best.position.distance_to(point):
						best = e
			return Command.cast(hero.id, slot, best.id) if best != null else command(world, hero, slot)
	return Command.cast(hero.id, slot)


## Tầm nhắm hiển thị / kéo: cast_range, không có thì bán kính vùng, không có nữa thì 600.
static func reach_of(hero: Entity, a: AbilityInstance) -> float:
	var v: Dictionary = Abilities.values(hero, a)
	for name: StringName in [&"cast_range", &"length", &"radius"]:
		if v.get(name, 0.0) > 0.0:
			return v[name]
	return 600.0


## WRD-01: loại ward mà kỹ năng `a` cắm, null nếu không phải đồ cắm mắt.
static func ward_of(a: AbilityInstance) -> UnitDef:
	if a == null:
		return null
	for action: ActionDef in a.def.on_cast:
		if action is PlaceWardAction:
			return (action as PlaceWardAction).ward
	return null


## D-108: mục tiêu của chiêu chọn đơn vị khi kéo theo hướng `aim`: trong tầm chiêu + tầm tìm,
## góc lệch với hướng kéo nhỏ nhất (hero địch được ưu tiên 25°); kéo quá ngắn → tự chọn như chạm.
static func unit_for_aim(world: World, hero: Entity, a: AbilityInstance, aim: Vector2) -> Entity:
	var reach: float = Abilities.value(hero, a, &"cast_range")
	if aim.length() < 0.15:
		return target(world, hero, a, reach)
	var search: float = (reach if reach > 0.0 else 600.0) + world.balance.attack_search_bonus
	var best: Entity = null
	var best_score: float = INF
	for e: Entity in world.entities:
		if e == hero or not Abilities.accepts(hero, a.def, e) or Rules.edge_distance(hero, e) > search:
			continue
		var to: Vector2 = e.position - hero.position
		var angle: float = absf(aim.angle_to(to)) if to.length() > 1.0 else 0.0
		var score: float = angle - (deg_to_rad(25.0) if e.kind == Entity.Kind.HERO else 0.0)
		if score < best_score:
			best = e
			best_score = score
	return best
