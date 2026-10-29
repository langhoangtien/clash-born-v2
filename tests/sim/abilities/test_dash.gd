extends TestCase
## M5.3: lướt (ABL-08, D-74) và chỉnh hồi chiêu (ABL-18).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


## Bán kính thân mọi đơn vị trong test (_unit, cả người lướt).
const DASHER_RADIUS: float = 24.0


func _origin() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _unit(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = DASHER_RADIUS
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.MAX_MANA, 500)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


## Chủ kỹ năng có Q nhắm đơn vị: lướt tốc 2000 rồi gây 100 sát thương thuần.
func _dasher(w: World, at: Vector2) -> Entity:
	var me: Entity = _unit(w, 0, at)
	var hit: DamageAction = DamageAction.new()
	hit.target = ActionDef.Target.TARGET
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "100"
	var dash: DashAction = DashAction.new()
	dash.target = ActionDef.Target.TARGET
	dash.speed = "2000"
	dash.on_arrive = [hit]
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_dash"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.UNIT
	d.values = {&"mana": PackedFloat32Array([50, 50, 50, 50, 50]), &"cooldown": PackedFloat32Array([10, 10, 10, 10, 10]),
		&"cast_range": PackedFloat32Array([1000, 1000, 1000, 1000, 1000])}
	d.on_cast = [dash]
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	me.abilities.append(a)
	return me


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _dash_until_done(w: World, me: Entity, limit: int = 60) -> int:
	for i: int in range(limit):
		w.step()
		if me.dash == null and i > 0:
			return i + 1
	return -1


func test_ABL_08_dash_to_edge_then_hit_once() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 800.0)
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	w.step()
	assert_true(me.dash != null, "đang lướt")
	var ticks: int = _dash_until_done(w, me)
	var expected: int = ceili((800.0 - 48.0) / (2000.0 / 30.0))
	assert_true(absi(ticks - expected) <= 1, "lướt ~%d tick, thực tế %d" % [expected, ticks])
	assert_near(Rules.edge_distance(me, foe), 0.0, 1.0, "dừng ở mép mục tiêu")
	assert_near(foe.health, 900.0, EPS, "tới nơi thì gây sát thương một lần")
	assert_near(me.mana, 450.0, EPS)


func test_ABL_08_untargetable_and_locked_out_while_dashing() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 900.0)
	var watcher: Entity = _unit(w, 1, _origin() + _dir().orthogonal() * 300.0)
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_steps(w, 2)
	assert_true(Rules.has_state(me, UnitState.Id.UNTARGETABLE), "lướt: không thể bị nhắm")
	assert_false(Rules.is_targetable(watcher, me))
	w.submit(Command.move_dir(me.id, Vector2.LEFT))
	_steps(w, 2)
	assert_true(me.dash != null, "lệnh mới không cắt ngang cú lướt")
	_dash_until_done(w, me)
	assert_false(Rules.has_state(me, UnitState.Id.UNTARGETABLE))
	assert_eq(me.order.type, Order.Type.DIRECT, "lướt xong thì làm lệnh đã chờ")


func test_ABL_08_passes_through_units() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 800.0)
	var block: Entity = _unit(w, 1, _origin() + _dir() * 400.0, Entity.Kind.LANE_CREEP)
	var spot: Vector2 = block.position
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_dash_until_done(w, me)
	assert_near(foe.health, 900.0, EPS, "xuyên qua lính đứng giữa đường")
	assert_near(block.health, 1000.0, EPS)
	assert_true(block.position.distance_to(spot) < 1.0, "không đẩy lính đang đứng")


func test_ABL_08_follows_moving_target() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 600.0)
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	w.submit(Command.move_dir(foe.id, _dir().orthogonal()))
	_dash_until_done(w, me)
	assert_near(foe.health, 900.0, EPS, "bám theo mục tiêu đang chạy")


func test_ABL_08_stops_at_terrain_without_hitting() -> void:
	var w: World = _world()
	var origin: Vector2 = _origin()
	var dir: Vector2 = Vector2.ZERO
	var wall: float = 0.0
	for k: int in range(32):
		var d: Vector2 = Vector2.from_angle(TAU * k / 32.0)
		for step: int in range(4, 40):
			if _map.clearance_at(origin + d * step * 16.0) < DASHER_RADIUS:  # chỗ thân người lướt (24) không lọt
				if step * 16.0 >= 200.0 and step * 16.0 <= 600.0:
					dir = d
					wall = step * 16.0
				break
		if dir != Vector2.ZERO:
			break
	assert_true(dir != Vector2.ZERO, "tìm được vách/rừng trong 200–600")
	var me: Entity = _dasher(w, origin)
	var foe: Entity = _unit(w, 1, origin + dir * (wall + 250.0))
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_dash_until_done(w, me)
	assert_near(foe.health, 1000.0, EPS, "vướng địa hình: không tới nơi, không gây sát thương")
	assert_true(me.position.distance_to(origin) < wall + 1.0, "dừng trước vật cản")
	assert_true(w.navigation(me.radius).point_is_clear(me.position), "không đứng trong vật cản")


func test_ABL_08_stun_or_target_lost_stops_without_hit_or_refund() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 900.0)
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_steps(w, 3)
	var stun: EffectDef = EffectDef.new()
	stun.id = &"test_stun"
	stun.states = [UnitState.Id.STUNNED]
	Effects.apply(w, me, stun, foe, {}, "1")
	var spot: Vector2 = me.position
	_steps(w, 2)
	assert_true(me.dash == null, "bị choáng thì hết lướt")
	assert_true(me.position.distance_to(spot) < 70.0, "dừng tại chỗ")
	_steps(w, 40)
	assert_near(foe.health, 1000.0, EPS)
	assert_near(me.mana, 450.0, EPS, "không hoàn mana")
	var w2: World = _world()
	var me2: Entity = _dasher(w2, _origin())
	var foe2: Entity = _unit(w2, 1, _origin() + _dir() * 900.0)
	w2.submit(Command.cast(me2.id, Slot.Q, foe2.id))
	_steps(w2, 3)
	var lift: EffectDef = EffectDef.new()
	lift.id = &"test_lift"
	lift.states = [UnitState.Id.UNTARGETABLE]
	Effects.apply(w2, foe2, lift, foe2, {}, "2")
	_steps(w2, 2)
	assert_true(me2.dash == null, "mục tiêu không còn nhắm được thì dừng")
	_steps(w2, 30)
	assert_near(foe2.health, 1000.0, EPS)


func test_ABL_18_modify_cooldown() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var a: AbilityInstance = Abilities.of(me, Slot.Q)
	a.ready_tick = w.tick + 300
	var cut: ModifyCooldownAction = ModifyCooldownAction.new()
	cut.target = ActionDef.Target.SELF
	cut.slot = Slot.Q
	cut.amount = "-4"
	ActionRunner.run(w, [cut], ExprContext.make(me, me, {}), me.id)
	assert_eq(a.ready_tick, w.tick + 180, "giảm 4 s")
	cut.amount = "-999"
	ActionRunner.run(w, [cut], ExprContext.make(me, me, {}), me.id)
	assert_eq(a.ready_tick, w.tick, "không xuống dưới 0: sẵn sàng ngay")
	cut.amount = "2"
	ActionRunner.run(w, [cut], ExprContext.make(me, me, {}), me.id)
	assert_eq(a.ready_tick, w.tick + 60, "cộng thêm 2 s")


func test_D_30_dash_in_hash() -> void:
	var w: World = _world()
	var me: Entity = _dasher(w, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 900.0)
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_steps(w, 2)
	var h: PackedByteArray = w.state_hash()
	me.dash.speed += 1.0
	assert_true(w.state_hash() != h)
