extends TestCase
## M6.3: đẩy lùi (ABL-10).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _origin() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _unit(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.MAX_MANA, 500)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	return w.add_entity(e)


## Đẩy `target` ra xa `owner` 300 trong 0.3 s.
func _push(w: World, owner: Entity, target: Entity, pierce: bool = false) -> void:
	var p: PushAction = PushAction.new()
	p.target = ActionDef.Target.TARGET
	p.distance = "300"
	p.duration = "0.3"
	var ctx: ExprContext = ExprContext.make(owner, target)
	if pierce:
		var d: AbilityDef = AbilityDef.new()
		d.pierces_magic_immunity = true
		ctx.ability = d
	ActionRunner.run(w, [p], ctx, owner.id)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_ABL_10_pushed_distance_over_duration_stunned_meanwhile() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 200.0)
	var start: Vector2 = foe.position
	_push(w, me, foe)
	assert_true(Rules.has_state(foe, UnitState.Id.STUNNED), "đang bị dời: STUNNED")
	var finished: int = -1
	for i: int in range(20):
		w.step()
		if finished < 0 and w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"knockback_finished" and ev.target_id == foe.id):
			finished = i + 1
	assert_eq(finished, 9, "0.3 s = 9 tick")
	assert_near(foe.position.distance_to(start), 300.0, 0.5, "dời đúng 300")
	assert_near((foe.position - start).normalized().dot(_dir()), 1.0, 0.001, "theo hướng từ chủ kỹ năng ra mục tiêu")
	assert_false(Rules.has_state(foe, UnitState.Id.STUNNED), "hết bị dời thì hết choáng")


func test_ABL_10_cancels_order_and_cast() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 200.0)
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_slow_cast"
	d.slot = Slot.Q
	d.cast_time = "1"
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0])}
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	foe.abilities.append(a)
	w.submit(Command.cast(foe.id, Slot.Q))
	w.step()
	assert_true(foe.cast != null)
	_push(w, me, foe)
	w.step()
	assert_true(foe.cast == null, "chiêu đang tung bị hủy")
	_steps(w, 12)
	assert_eq(foe.order.type, Order.Type.IDLE, "lệnh bị hủy, không đi tiếp lệnh cũ")


func test_ABL_10_stops_at_terrain_never_through() -> void:
	var w: World = _world()
	var origin: Vector2 = _origin()
	var dir: Vector2 = Vector2.ZERO
	var wall: float = 0.0
	for k: int in range(32):
		var d: Vector2 = Vector2.from_angle(TAU * k / 32.0)
		for step: int in range(4, 30):
			if _map.clearance_at(origin + d * step * 16.0) <= 30.0:
				if step * 16.0 >= 150.0 and step * 16.0 <= 350.0:
					dir = d
					wall = step * 16.0
				break
		if dir != Vector2.ZERO:
			break
	assert_true(dir != Vector2.ZERO, "tìm được vách/rừng trong 150–350")
	var me: Entity = _unit(w, 0, origin - dir * 100.0)
	var foe: Entity = _unit(w, 1, origin)
	_push(w, me, foe)
	_steps(w, 12)
	assert_true(foe.position.distance_to(origin) < wall, "dừng trước vật cản")
	assert_true(w.navigation(foe.radius).point_is_clear(foe.position), "không đứng trong vật cản")
	assert_false(Rules.has_state(foe, UnitState.Id.STUNNED))


func test_ABL_10_blocked_by_tower_body() -> void:
	var w: World = _world()
	MatchSetup.spawn_structures(w, _lib)
	var tower: Entity = null
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.TOWER:
			tower = e
			break
	var nav: MapNavigation = w.navigation(24.0)
	var dir: Vector2 = Vector2.ZERO
	for k: int in range(16):
		var d: Vector2 = Vector2.from_angle(TAU * k / 16.0)
		if nav.point_is_clear(tower.position + d * 260.0) and nav.point_is_clear(tower.position + d * 400.0):
			dir = d
			break
	var me: Entity = _unit(w, 0, tower.position + dir * 400.0)
	var foe: Entity = _unit(w, 1, tower.position + dir * 260.0)
	_push(w, me, foe)
	_steps(w, 12)
	assert_true(foe.position.distance_to(tower.position) >= tower.radius + foe.radius - 1.0, "không đi xuyên thân trụ")
	assert_true(nav.point_is_clear(foe.position))


func test_ABL_10_magic_immune_blocks_unless_pierce() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 200.0)
	Effects.apply(w, foe, _lib.effects[&"magic_immune"], foe, {}, "5")
	var start: Vector2 = foe.position
	_push(w, me, foe)
	_steps(w, 12)
	assert_near(foe.position.distance_to(start), 0.0, 1.0, "miễn phép: không bị đẩy")
	_push(w, me, foe, true)
	_steps(w, 12)
	assert_near(foe.position.distance_to(start), 300.0, 1.0, "nguồn xuyên miễn phép: bị đẩy")


func test_D_30_knockback_in_hash() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + _dir() * 200.0)
	_push(w, me, foe)
	w.step()
	var h: PackedByteArray = w.state_hash()
	foe.knockback.end_tick += 1
	assert_true(w.state_hash() != h)
