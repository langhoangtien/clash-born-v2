class_name BotSkills
extends RefCounted
## BOT-13..15: bot dùng chiêu và đồ chủ động theo LOẠI (`bot_usage`) cộng điều kiện dữ liệu
## (`bot_conditions`) — không có code riêng cho từng chiêu. Nhiều loại thì điều kiện thứ i đi
## với loại thứ i; một loại thì mọi điều kiện đều phải đúng (điều kiện "gợi ý" luôn đúng).

const U := AbilityDef.BotUsage
const Mode := BotState.Mode
## Điều kiện chỉ là gợi ý cách nhắm / chọn mục tiêu, không chặn việc dùng.
const HINTS: Array[StringName] = [&"predict_position", &"prefer_engaging_enemy", &"prefer_same_target"]


## Thử dùng một chiêu / món đồ; trả về true nếu đã gửi lệnh.
static func try_cast(world: World, e: Entity, foe: Entity) -> bool:
	if e.cast != null or not Rules.can_cast(e) and not Rules.can_use_item(e):
		return false
	var slots: Array[int] = [AbilityDef.Slot.R, AbilityDef.Slot.Q, AbilityDef.Slot.W]
	for it: ItemInstance in Items.slots(e):
		if it != null and it.ability != null:
			slots.append(Items.SLOT_BASE + it.index)
	for slot: int in slots:
		var a: AbilityInstance = Abilities.of(e, slot)
		if a == null or a.def.bot_usages.is_empty() or Abilities.problem(world, e, a) != Abilities.Problem.NONE:
			continue
		for i: int in range(a.def.bot_usages.size()):
			var usage: U = a.def.bot_usages[i]
			if not _wants(world, e, a, usage, foe) or not _conditions_hold(world, e, a, i, foe):
				continue
			var c: Command = _command(world, e, a, slot, usage, foe)
			if c != null:
				world.submit(c)
				return true
	return false


## Điều kiện chung của từng loại.
static func _wants(world: World, e: Entity, a: AbilityInstance, usage: U, foe: Entity) -> bool:
	var mode: Mode = e.bot.mode
	var fighting: bool = mode == Mode.TRADE or mode == Mode.KILL
	match usage:
		U.DISABLE, U.FINISH, U.TEAMFIGHT:
			return foe != null and _in_reach(e, a, foe)
		U.POKE:
			return foe != null and _in_reach(e, a, foe) and mode != Mode.RETREAT \
				and e.mana >= e.stats.get_stat(StatId.Id.MAX_MANA) * 0.4
		U.ENGAGE:
			return foe != null and fighting and BotController.safe(world, e, foe.position)  # BOT-15
		U.ESCAPE:
			return mode == Mode.RETREAT or mode == Mode.ESCAPE_TOWER or _hp(e) < 0.3  # BOT-15: bất kể an toàn
		U.SELF_DEFENSE:
			return world.tick - e.bot.last_hurt_tick <= 60
	return false


static func _conditions_hold(world: World, e: Entity, a: AbilityInstance, index: int, foe: Entity) -> bool:
	var conds: Array[StringName] = a.def.bot_conditions
	if conds.is_empty():
		return true
	if a.def.bot_usages.size() > 1 and conds.size() == a.def.bot_usages.size():
		return check(world, e, a, conds[index], foe)
	for c: StringName in conds:
		if not check(world, e, a, c, foe):
			return false
	return true


## Điều kiện dữ liệu theo tên (CONTENT "Cách bot dùng skill"). Tên lạ → sai.
static func check(world: World, e: Entity, a: AbilityInstance, name: StringName, foe: Entity) -> bool:
	if HINTS.has(name):
		return true
	var v: Dictionary = Abilities.values(e, a)
	match name:
		&"enemy_hero_in_range":
			return foe != null and _in_reach(e, a, foe)
		&"enemy_hero_in_radius":
			return foe != null and e.position.distance_to(foe.position) <= v.get(&"radius", 300.0) + foe.radius
		&"enemy_hero_too_close":
			return foe != null and e.position.distance_to(foe.position) <= 350.0
		&"enemy_hp_below_damage":
			return foe != null and foe.health <= v.get(&"damage", 0.0) * 0.9
		&"two_enemies_in_area", &"hits_multiple":
			return foe != null and _enemies_near(world, e, foe.position, maxf(v.get(&"radius", 0.0), v.get(&"width", 250.0))) >= 2
		&"hp_below_70":
			return _hp(e) < 0.7
		&"hp_below_30":
			return _hp(e) < 0.3
		&"hp_below_30_or_tower_targeted":
			return _hp(e) < 0.3 or e.bot.mode == Mode.ESCAPE_TOWER
		&"taking_damage":
			return world.tick - e.bot.last_hurt_tick <= 30
		&"target_hp_below_50":
			return foe != null and _hp(foe) < 0.5
		&"destination_safe":
			return foe != null and BotController.safe(world, e, foe.position)
		&"before_engage", &"preparing_engage":
			return foe != null and (e.bot.mode == Mode.KILL or e.bot.mode == Mode.TRADE) \
				and e.position.distance_to(foe.position) > e.stats.get_stat(StatId.Id.ATTACK_RANGE) + e.radius + foe.radius
		&"enemy_hero_still_or_disabled":
			return foe != null and (not Rules.can_move(foe) or foe.order.type != Order.Type.MOVE or foe.attack_phase != Entity.AttackPhase.NONE)
		&"has_dispellable_debuff":
			return e.effects.any(func(i: EffectInstance) -> bool: return i.def.tags.has(&"debuff") and i.def.dispel == EffectDef.Dispel.BASIC)
		&"enemy_has_purgeable_buff_or_fleeing":
			return foe != null and (_purgeable(foe) or _fleeing(e, foe))
	return false


## Lệnh dùng: nhắm hero địch (dự đoán vị trí theo độ khó) hoặc bản thân; thoát thân không có
## địch thì hướng về nhà.
static func _command(world: World, e: Entity, a: AbilityInstance, slot: int, usage: U, foe: Entity) -> Command:
	match a.def.targeting:
		AbilityDef.Targeting.NO_TARGET:
			return Command.cast(e.id, slot)
		AbilityDef.Targeting.UNIT:
			var self_cast: bool = a.def.target_team != AbilityDef.Team.ENEMY and (usage == U.ESCAPE or usage == U.SELF_DEFENSE or foe == null)
			var t: Entity = e if self_cast else foe
			if t == null or not Abilities.accepts(e, a.def, t):
				return null
			return Command.cast(e.id, slot, t.id)
		AbilityDef.Targeting.POINT, AbilityDef.Targeting.DIRECTION:
			var at: Vector2 = aim_point(world, e, foe) if foe != null else world.map.fountain_point(e.team)
			if a.def.targeting == AbilityDef.Targeting.POINT:
				return Command.cast(e.id, slot, -1, at)
			var dir: Vector2 = at - e.position
			return Command.cast(e.id, slot, -1, Vector2.INF, dir.normalized() if dir.length() > 0.001 else e.facing)
	return null


## D-94: chỗ nhắm theo độ khó — Khó đoán trước 0.4 s đường chạy, Thường 0.2 s, Dễ không đoán
## và lệch ngẫu nhiên (world.rng, xác định theo seed).
static func aim_point(world: World, e: Entity, foe: Entity) -> Vector2:
	var lead: float = [0.0, 0.2, 0.4][e.bot.difficulty]
	var p: Vector2 = foe.position
	if foe.order.type == Order.Type.MOVE and not foe.order.finished:
		p += foe.facing * foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED) * lead
	var spread: float = [140.0, 50.0, 0.0][e.bot.difficulty]
	if spread > 0.0:
		p += Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf() * spread
	return p


static func reach(e: Entity, a: AbilityInstance) -> float:
	var v: Dictionary = Abilities.values(e, a)
	for key: StringName in [&"cast_range", &"length", &"radius"]:
		if v.get(key, 0.0) > 0.0:
			return v[key]
	return 600.0


static func _in_reach(e: Entity, a: AbilityInstance, foe: Entity) -> bool:
	return Rules.edge_distance(e, foe) <= reach(e, a)


static func _hp(e: Entity) -> float:
	return e.health / maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))


static func _enemies_near(world: World, e: Entity, at: Vector2, radius: float) -> int:
	var n: int = 0
	for o: Entity in world.spatial_near(at, radius + 40.0, World.Phase.CONTROLLER, false):
		if o.alive and o.team != e.team and o.team < 2 and (o.kind == Entity.Kind.HERO or o.kind == Entity.Kind.LANE_CREEP) \
				and Rules.is_visible(e.team, o) and o.position.distance_to(at) <= radius:
			n += 1
	return n


static func _purgeable(foe: Entity) -> bool:
	for inst: EffectInstance in foe.effects:
		if inst.def.tags.has(&"buff") and inst.def.dispel == EffectDef.Dispel.BASIC:
			return true
	return false


static func _fleeing(e: Entity, foe: Entity) -> bool:
	return foe.order.type == Order.Type.MOVE and foe.facing.dot((foe.position - e.position).normalized()) > 0.5
