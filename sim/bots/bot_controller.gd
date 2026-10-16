class_name BotController
extends SimSystem
## Pha CONTROLLER (BOT-01..15): mỗi hero có Entity.bot gửi Command như người chơi. Chọn state
## theo thứ tự ưu tiên của bảng BOT; mọi điểm tới / đứng đánh qua Rules.is_safe_for_hero
## (BOT-10); chỉ dùng đơn vị đội mình đang thấy (BOT-12).

const Mode := BotState.Mode
## Tới gần điểm đích chừng này thì coi như đã tới.
const ARRIVE: float = 60.0
## BOT-07: tìm lính để farm trong chừng này quanh bot và quanh điểm neo lane.
const FARM_RANGE: float = 1100.0
## D-96: bot chủ động cấu khi máu mình hơn địch chừng này (Dễ / Thường / Khó) và địch ở gần.
const AHEAD: Array[float] = [0.3, 0.15, 0.05]
## D-94: chỉ đi farm trại rừng trong chừng này.
const JUNGLE_RANGE: float = 1600.0


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.kind != Entity.Kind.HERO or e.bot == null or not e.alive or e.reincarnate_tick >= 0:
			continue
		_note_fights(world, e)  # mỗi tick, để không lỡ sự kiện giữa hai lần nghĩ
		if (world.tick + e.id) % e.bot.think_ticks() != 0:
			continue
		think(world, e)


## Một lần nghĩ: nâng điểm, mua đồ, chọn state, dùng chiêu / đồ, rồi đi / đánh.
func think(world: World, e: Entity) -> void:
	var b: BotState = e.bot
	var target: Entity = null
	_level_up(world, e)
	_shop(world, e)
	b.mode = choose(world, e)
	if b.mode != Mode.RECOVER and BotSkills.try_cast(world, e, _enemy_hero(world, e)):
		return  # BOT-13
	match b.mode:
		Mode.ESCAPE_TOWER:
			_go(world, e, escape_point(world, e))
		Mode.RETREAT:
			_go(world, e, world.map.fountain_point(e.team))
		Mode.RECOVER:
			_hold(world, e)
		Mode.TRADE, Mode.KILL:
			target = _enemy_hero(world, e)
		Mode.DEFEND_BASE:
			target = _base_invader(world, e)
		Mode.FARM:
			target = farm_target(world, e)
		Mode.JUNGLE:
			target = jungle_target(world, e)
		Mode.PUSH:
			target = Objectives.next_for_lane(world, e.team, b.lane)
		Mode.SHOP:
			_go(world, e, _shop_spot(world, e))
		Mode.WARD:
			_ward(world, e)
		_:
			_go(world, e, rally_point(world, e))
	if target != null and Rules.can_attack(e):
		_attack(world, e, target)
	elif target != null:  # bị biến hình / tước vũ khí: lùi ra xa mục tiêu, không đứng yên (BOT-11)
		var away: Vector2 = (e.position - target.position).normalized() if e.position != target.position else Vector2.RIGHT
		_go(world, e, _safe_back(world, e, world.navigation(e.radius).nearest_clear(e.position + away * 300.0)))
	if b.mode != Mode.TRADE and b.mode != Mode.KILL:
		b.chase_origin = Vector2.INF


## Thứ tự ưu tiên của bảng BOT.
func choose(world: World, e: Entity) -> Mode:
	var b: BotState = e.bot
	var hp: float = _hp(e)
	if _targeted_by_structure(world, e) or not Rules.is_safe_for_hero(world, e, e.position):
		return Mode.ESCAPE_TOWER  # BOT-01, BOT-10: lỡ đứng chỗ không an toàn thì lùi ra
	var home: Vector2 = world.map.fountain_point(e.team)
	var at_home: bool = e.position.distance_to(home) <= world.balance.fountain_radius * 0.6
	if at_home and (hp < world.balance.bot_recover_hp or (b.mode == Mode.RETREAT and hp < 0.999)) :
		return Mode.RECOVER  # BOT-03
	if b.mode == Mode.RECOVER and at_home and hp < world.balance.bot_recover_hp:
		return Mode.RECOVER
	if hp < world.balance.bot_retreat_hp or (b.mode == Mode.RETREAT and not at_home):
		return Mode.RETREAT  # BOT-02
	var foe: Entity = _enemy_hero(world, e)
	if foe != null and _may_chase(world, e, foe):
		if world.tick <= b.trade_until_tick:
			return Mode.TRADE  # BOT-04
		var near: bool = e.position.distance_to(foe.position) <= world.balance.bot_kill_range
		if near and (_hp(foe) < world.balance.bot_kill_hp or _hp(foe) < hp - AHEAD[b.difficulty] * 2.0):
			return Mode.KILL  # BOT-05 (D-96: cả khi máu mình hơn hẳn)
		if _wants_trade(e, foe):
			b.trade_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.bot_trade_window)
			return Mode.TRADE  # D-96: chủ động cấu
	if _base_invader(world, e) != null:
		return Mode.DEFEND_BASE  # BOT-06
	if farm_target(world, e) != null:
		return Mode.FARM  # BOT-07
	if push_ready(world, e):
		return Mode.PUSH  # BOT-08
	if _wants_secret_shop(world, e):
		return Mode.SHOP  # D-94: đủ vàng mua món shop ẩn kế tiếp, shop gần và an toàn
	if ward_spot(world, e).is_finite():
		return Mode.WARD  # D-94: cắm mắt vàng ở điểm định sẵn
	if hp >= 0.5 and not _own_wave(world, e) and jungle_target(world, e) != null:
		return Mode.JUNGLE  # D-94: lane trống (không lính địch, không đợt lính phe mình để theo) thì farm rừng
	return Mode.RALLY  # BOT-09


## BOT-04: hero địch vừa gây giao tranh với bot (DEF-11) → mở cửa sổ đánh trả.
func _note_fights(world: World, e: Entity) -> void:
	for ev: GameEvent in world.previous_hero_fights():
		if ev.target_id == e.id:
			e.bot.trade_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.bot_trade_window)
	for ev: GameEvent in world.previous_events:
		if ev.type == &"damage_taken" and ev.target_id == e.id and ev.amount > 0.0:
			e.bot.last_hurt_tick = world.tick - 1
			break


## D-96: chủ động cấu — địch trong tầm đánh + 250, máu mình ≥ 50% và hơn địch AHEAD.
func _wants_trade(e: Entity, foe: Entity) -> bool:
	var reach: float = e.stats.get_stat(StatId.Id.ATTACK_RANGE) + e.radius + foe.radius + 250.0
	return e.position.distance_to(foe.position) <= reach and _hp(e) >= 0.5 and _hp(e) >= _hp(foe) + AHEAD[e.bot.difficulty]


## Hero địch gần nhất mà đội bot đang thấy và đánh được (BOT-12), null nếu không có.
func _enemy_hero(world: World, e: Entity) -> Entity:
	var best: Entity = null
	for o: Entity in world.entities:
		if o.kind == Entity.Kind.HERO and o.alive and o.team != e.team and o.reincarnate_tick < 0 and Rules.is_attackable(e, o):
			if best == null or e.position.distance_to(o.position) < e.position.distance_to(best.position):
				best = o
	return best


## BOT-04/05: đuổi được — chỗ đứng đánh an toàn (BOT-10) và chưa quá leash tính từ chỗ bắt đầu đuổi (DEF-08).
func _may_chase(world: World, e: Entity, foe: Entity) -> bool:
	if not _reach_safe(world, e, _stand_point(e, foe)):
		return false
	var origin: Vector2 = e.bot.chase_origin if e.bot.chase_origin.is_finite() else e.position
	return foe.position.distance_to(origin) <= world.balance.bot_chase_leash


## BOT-10: chỗ đứng `to` an toàn và đường thẳng tới đó không cắt qua vùng nguy hiểm.
func _reach_safe(world: World, e: Entity, to: Vector2) -> bool:
	if not Rules.is_safe_for_hero(world, e, to):
		return false
	var d: float = e.position.distance_to(to)
	var steps: int = int(d / 200.0)
	for i: int in range(1, steps + 1):
		if not Rules.is_safe_for_hero(world, e, e.position.lerp(to, float(i) / (steps + 1))):
			return false
	return true


## Chỗ bot sẽ đứng để đánh `t`: trên đường nối, cách `t` đúng tầm đánh.
func _stand_point(e: Entity, t: Entity) -> Vector2:
	var reach: float = e.stats.get_stat(StatId.Id.ATTACK_RANGE) + e.radius + t.radius
	var d: float = e.position.distance_to(t.position)
	return e.position if d <= reach else t.position + (e.position - t.position).normalized() * reach


## BOT-06: lính địch (đang thấy) trong base phe bot.
func _base_invader(world: World, e: Entity) -> Entity:
	var best: Entity = null
	for c: Entity in world.entities:
		if c.kind == Entity.Kind.LANE_CREEP and c.alive and c.team != e.team and world.map.is_in_base(c.position, e.team) \
				and Rules.is_attackable(e, c) and _reach_safe(world, e, _stand_point(e, c)):
			if best == null or e.position.distance_to(c.position) < e.position.distance_to(best.position):
				best = c
	return best


## BOT-07: lính địch đang thấy gần lane của bot, chỗ đứng đánh an toàn. Ưu tiên last hit: con
## nào máu ≤ một đòn của bot thì đánh ngay; không có thì con ít máu nhất (Dễ: con gần nhất).
func farm_target(world: World, e: Entity) -> Entity:
	var hit: float = _hit_damage(world, e)
	var best: Entity = null
	var kill: Entity = null
	var near: Vector2 = rally_anchor(world, e)
	for c: Entity in world.spatial_near(e.position, FARM_RANGE, World.Phase.CONTROLLER, true):
		if c.kind != Entity.Kind.LANE_CREEP or not c.alive or c.team == e.team or not Rules.is_attackable(e, c):
			continue
		if (c.position.distance_to(near) > FARM_RANGE and c.position.distance_to(e.position) > FARM_RANGE * 0.7) or not _reach_safe(world, e, _stand_point(e, c)):
			continue
		if c.health <= hit * _last_hit_margin(e) and (kill == null or c.health < kill.health):
			kill = c
		if best == null or (e.bot.difficulty == BotState.Difficulty.EASY and e.position.distance_to(c.position) < e.position.distance_to(best.position)) \
				or (e.bot.difficulty != BotState.Difficulty.EASY and c.health < best.health):
			best = c
	return kill if kill != null else best


## Sát thương một đòn đánh của bot lên lính (sau giáp lính cận chiến) — ước lượng cho last hit.
func _hit_damage(world: World, e: Entity) -> float:
	var armor: float = 2.0
	return DamageFormulas.final_damage(e.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), DamageFormulas.DamageType.PHYSICAL,
		armor, 0.0, 1.0, world.balance)


## D-94: độ chính xác last hit theo độ khó (Khó canh sát nút hơn).
func _last_hit_margin(e: Entity) -> float:
	return [0.8, 1.0, 1.15][e.bot.difficulty]


## BOT-08: công trình kế tiếp của lane mở khóa, đứng đánh được an toàn.
func push_ready(world: World, e: Entity) -> bool:
	var t: Entity = Objectives.next_for_lane(world, e.team, e.bot.lane)
	return t != null and not t.locked and Rules.is_attackable(e, t) and _reach_safe(world, e, _stand_point(e, t))


## Đợt lính phe mình đang áp sát công trình kế tiếp của địch (trong 1500) — theo đẩy, không đi rừng.
func _own_wave(world: World, e: Entity) -> bool:
	var t: Entity = Objectives.next_for_lane(world, e.team, e.bot.lane)
	if t == null:
		return false
	for c: Entity in world.spatial_near(t.position, 1500.0, World.Phase.CONTROLLER, false):
		if c.kind == Entity.Kind.LANE_CREEP and c.alive and c.team == e.team:
			return true
	return false


## D-94: lane trống → quái ở trại rừng phe mình gần nhất còn quái, chỗ đánh an toàn.
func jungle_target(world: World, e: Entity) -> Entity:
	var best: Entity = null
	var best_d: float = INF
	for c: CampState in world.camps:
		if world.map.camp_sides[c.index] != e.team or c.unit_ids.is_empty():
			continue
		var d: float = e.position.distance_to(c.center)
		if d >= best_d or d > JUNGLE_RANGE:
			continue
		for id: int in c.unit_ids:
			var n: Entity = world.find_entity(id)
			if n != null and n.alive and Rules.is_attackable(e, n) and _reach_safe(world, e, _stand_point(e, n)):
				best = n
				best_d = d
				break
	return best


func _attack(world: World, e: Entity, t: Entity) -> void:
	var b: BotState = e.bot
	if (b.mode == Mode.TRADE or b.mode == Mode.KILL) and not b.chase_origin.is_finite():
		b.chase_origin = e.position  # DEF-08
	var busy: bool = e.order.type == Order.Type.ATTACK and not e.order.finished and e.order.target_id == t.id
	if busy:
		return
	b.target_id = t.id
	b.goal = Vector2.INF
	world.submit(Command.attack(e.id, t.id))


## BOT-01: điểm an toàn gần nhất phía nhà (lùi ra khỏi vùng mọi trụ đang đe dọa, rồi về nhà).
func escape_point(world: World, e: Entity) -> Vector2:
	var home: Vector2 = world.map.fountain_point(e.team)
	var nav: MapNavigation = world.navigation(e.radius)
	var step: Vector2 = (home - e.position).normalized()
	for d: float in [300.0, 500.0, 700.0, 900.0, 1200.0, 1600.0]:
		var p: Vector2 = nav.nearest_clear(e.position + step * d)
		if Rules.is_safe_for_hero(world, e, p) and not _threatened_by_targeting(world, e, p):
			return p
	return home


## BOT-09: sau hàng lính phe mình `bot_lane_offset` (lính xa nhất trên lane); không có lính thì
## điểm xa nhất còn an toàn tính từ công trình kế tiếp của địch lùi về. Tới nơi thì đi qua lại
## nhẹ (BOT-11: không đứng yên).
func rally_point(world: World, e: Entity) -> Vector2:
	var route: LaneRoute = LaneRoute.of(world, e.bot.lane, e.team)
	var p: float = _rally_progress(world, e, route)
	if (world.tick / SimClock.seconds_to_ticks(2.0)) % 2 == 1:
		p -= 120.0
	return _safe_along(world, e, route, p)


## Điểm neo của lane (chỗ đứng chờ) — dùng để biết lính nào thuộc lane của bot.
func rally_anchor(world: World, e: Entity) -> Vector2:
	var route: LaneRoute = LaneRoute.of(world, e.bot.lane, e.team)
	return route.point_at(_rally_progress(world, e, route))


func _rally_progress(world: World, e: Entity, route: LaneRoute) -> float:
	var front: float = -1.0
	for c: Entity in world.entities:
		if c.kind == Entity.Kind.LANE_CREEP and c.alive and c.team == e.team and c.lane == e.bot.lane:
			front = maxf(front, route.progress_of(c.position))
	if front >= 0.0:
		return maxf(0.0, front - world.balance.bot_lane_offset)
	var next: Entity = Objectives.next_for_lane(world, e.team, e.bot.lane)
	return route.progress_of(next.position) if next != null else route.length()


## Lùi dọc route từ tiến độ `p` tới điểm đầu tiên an toàn (BOT-10).
func _safe_along(world: World, e: Entity, route: LaneRoute, p: float) -> Vector2:
	var nav: MapNavigation = world.navigation(e.radius)
	while p > 0.0:
		var q: Vector2 = nav.nearest_clear(route.point_at(p))
		if Rules.is_safe_for_hero(world, e, q):
			return q
		p -= 100.0
	return nav.nearest_clear(route.point_at(0.0))


## Lùi điểm `p` về phía nhà tới khi an toàn (BOT-10).
func _safe_back(world: World, e: Entity, p: Vector2) -> Vector2:
	var home: Vector2 = world.map.fountain_point(e.team)
	var nav: MapNavigation = world.navigation(e.radius)
	var q: Vector2 = p
	for i: int in range(12):
		if Rules.is_safe_for_hero(world, e, q):
			return q
		q = nav.nearest_clear(q + (home - q).normalized() * 200.0)
	return home


func _go(world: World, e: Entity, point: Vector2) -> void:
	var b: BotState = e.bot
	if _stuck(world, e):  # D-96: kẹt giữa đơn vị đi ngược chiều → bước tránh sang ngang
		var side: Vector2 = (point - e.position).normalized().orthogonal() * (1.0 if (world.tick / 30) % 2 == 0 else -1.0)
		b.goal = world.navigation(e.radius).nearest_clear(e.position + side * 160.0)
		world.submit(Command.move_to(e.id, b.goal))
		return
	if e.position.distance_to(point) <= ARRIVE * 0.5 and e.order.type != Order.Type.MOVE:
		b.goal = point
		return
	var moving: bool = e.order.type == Order.Type.MOVE and not e.order.finished
	if moving and b.goal.is_finite() and b.goal.distance_to(point) < ARRIVE:
		return
	b.goal = point
	b.target_id = -1
	world.submit(Command.move_to(e.id, point))


## Đang có lệnh đi mà gần như không nhích trong 1 s.
func _stuck(world: World, e: Entity) -> bool:
	var b: BotState = e.bot
	var moving: bool = e.order.type == Order.Type.MOVE and not e.order.finished
	if not moving or e.position.distance_to(b.last_pos) > 20.0:
		b.last_pos = e.position
		b.last_pos_tick = world.tick
		return false
	return world.tick - b.last_pos_tick >= 30


func _hold(world: World, e: Entity) -> void:
	if e.order.type != Order.Type.IDLE:
		world.submit(Command.stop(e.id))
	e.bot.goal = Vector2.INF
	e.bot.target_id = -1


func _hp(e: Entity) -> float:
	return e.health / maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))


## BOT-01: trụ địch đang nhắm bot (mục tiêu lệnh đánh của trụ).
func _targeted_by_structure(world: World, e: Entity) -> bool:
	for t: Entity in Rules.tower_threat_at(world, e.team, e.position, e.radius):
		if t.order.type == Order.Type.ATTACK and not t.order.finished and t.order.target_id == e.id:
			return true
	return false


## Điểm `p` còn trong vùng một trụ đang nhắm bot.
func _threatened_by_targeting(world: World, e: Entity, p: Vector2) -> bool:
	for t: Entity in Rules.tower_threat_at(world, e.team, p, e.radius):
		if t.order.target_id == e.id:
			return true
	return false


## BOT-14: nâng điểm theo bot_skill_order (bỏ qua bước chưa làm được, thử bước sau), chọn
## talent theo bot_talent_priority.
func _level_up(world: World, e: Entity) -> void:
	var def: HeroDef = e.hero_def
	if def == null:
		return
	if e.skill_points > 0 and not def.bot_skill_order.is_empty():
		for i: int in range(e.bot.upgrades_done, def.bot_skill_order.size()):
			var slot: int = _upgrade_slot(def.bot_skill_order[i])
			if Progression.level_problem(world, e, slot) == Command.Reject.NONE:
				world.submit(Command.level_up(e.id, slot))
				e.bot.upgrades_done = i + 1
				break
	if e.talent_slot < 0 and e.skill_points == 0 and e.stats.level() >= world.balance.talent_level:
		for slot: AbilityDef.Slot in def.bot_talent_priority:
			if Progression.talent_problem(world, e, slot) == Command.Reject.NONE:
				world.submit(Command.choose_talent(e.id, slot))
				break


static func _upgrade_slot(u: HeroDef.Upgrade) -> int:
	match u:
		HeroDef.Upgrade.Q:
			return AbilityDef.Slot.Q
		HeroDef.Upgrade.W:
			return AbilityDef.Slot.W
		HeroDef.Upgrade.R:
			return AbilityDef.Slot.R
	return Command.ATTRIBUTES


## D-94: món kế tiếp trong thứ tự lên đồ chưa có, null nếu đã đủ.
func next_item(world: World, e: Entity) -> ItemDef:
	if e.hero_def == null:
		return null
	for id: StringName in e.hero_def.bot_item_build:
		var owned: bool = Items.slots(e).any(func(it: ItemInstance) -> bool: return it != null and it.def.id == id)
		if not owned and world.item_catalog.has(id):
			return world.item_catalog[id]
	return null


## D-94: mua món kế tiếp (mọi nơi, hoặc khi đang ở shop ẩn), mua mắt vàng khi kho còn.
func _shop(world: World, e: Entity) -> void:
	if world.item_catalog.is_empty():
		return
	var d: ItemDef = next_item(world, e)
	if d != null and Shop.buy_problem(world, e, d.id) == Command.Reject.NONE:
		world.submit(Command.buy(e.id, d.id))
		return
	var obs: ItemDef = world.item_catalog.get(&"observer_ward")
	if obs != null and _charges_of(e, obs) == 0 and Shop.buy_problem(world, e, obs.id) == Command.Reject.NONE:
		world.submit(Command.buy(e.id, obs.id))


func _charges_of(e: Entity, d: ItemDef) -> int:
	for it: ItemInstance in Items.slots(e):
		if it != null and it.def == d:
			return it.charges
	return 0


func _wants_secret_shop(world: World, e: Entity) -> bool:
	var d: ItemDef = next_item(world, e)
	if d == null or d.shop != ItemDef.ShopKind.SECRET or e.gold < d.cost or Shop.buy_problem(world, e, d.id) != Command.Reject.NOT_IN_SHOP:
		return false
	var spot: Vector2 = _shop_spot(world, e)
	return e.position.distance_to(spot) <= 5000.0 and _reach_safe(world, e, spot)


func _shop_spot(world: World, e: Entity) -> Vector2:
	var best: Vector2 = Vector2.INF
	for p: Vector2 in world.map.shop_points:
		if not best.is_finite() or e.position.distance_to(p) < e.position.distance_to(best):
			best = p
	return world.navigation(e.radius).nearest_clear(best)


## D-94: điểm cắm mắt vàng định sẵn — 2 bụi gần giữa map nhất trên nửa map phe bot; trả về
## điểm chưa có mắt phe mình (trong 700), an toàn, trong 3000; INF nếu không cần cắm.
func ward_spot(world: World, e: Entity) -> Vector2:
	var obs: ItemDef = world.item_catalog.get(&"observer_ward")
	if obs == null or _charges_of(e, obs) == 0:
		return Vector2.INF
	for p: Vector2 in ward_spots(world, e.team):
		if e.position.distance_to(p) > 3000.0 or not _reach_safe(world, e, p):
			continue
		var covered: bool = false
		for w: Entity in world.entities:
			if w.kind == Entity.Kind.WARD and w.alive and w.team == e.team and w.true_sight_range <= 0.0 and w.position.distance_to(p) < 700.0:
				covered = true
		if not covered:
			return p
	return Vector2.INF


static func ward_spots(world: World, team: int) -> Array[Vector2]:
	var mid: Vector2 = world.map.world_size() * 0.5
	var home: Vector2 = world.map.fountain_point(team)
	var away: Vector2 = world.map.fountain_point(1 - team)
	var spots: Array[Vector2] = []
	for poly: PackedVector2Array in world.map.bushes.polygons:
		var c: Vector2 = Vector2.ZERO
		for p: Vector2 in poly:
			c += p
		c /= poly.size()
		if c.distance_to(home) < c.distance_to(away):
			spots.append(c)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(mid) < b.distance_to(mid))
	return spots.slice(0, 2)


func _ward(world: World, e: Entity) -> void:
	var spot: Vector2 = ward_spot(world, e)
	if not spot.is_finite():
		return
	if e.position.distance_to(spot) > 450.0:
		_go(world, e, world.navigation(e.radius).nearest_clear(spot))
		return
	for it: ItemInstance in Items.slots(e):
		if it != null and it.def.id == &"observer_ward" and it.ability != null \
				and Abilities.problem(world, e, it.ability) == Abilities.Problem.NONE:
			world.submit(Command.cast(e.id, Items.SLOT_BASE + it.index, -1, spot))
			return
