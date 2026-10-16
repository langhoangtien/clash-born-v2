extends TestCase
## M5.1b: bụi cỏ (VIS-06, VIS-07, D-72).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	MatchSetup.add_vision(w)
	return w


## Tâm của bụi `i` (trung bình các đỉnh).
func _bush(i: int) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in _map.bushes.polygons[i]:
		sum += p
	return sum / _map.bushes.polygons[i].size()


func _unit(w: World, team: int, at: Vector2, sight: float = 1200.0, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	e.stats.set_base(StatId.Id.VISION_RANGE, sight)
	return w.add_entity(e)


## Điểm ngoài mọi bụi, cách tâm bụi `i` khoảng `d`.
func _outside(i: int, d: float) -> Vector2:
	for k: int in range(16):
		var p: Vector2 = _bush(i) + Vector2.from_angle(TAU * k / 16.0) * d
		if _map.bushes.at(p) < 0:
			return p
	return Vector2.INF


func test_D_72_map_has_14_symmetric_bushes_outside_tower_range() -> void:
	_world()
	assert_eq(_map.bushes.polygons.size(), 14)
	var size: Vector2 = _map.world_size()
	for i: int in range(14):
		var c: Vector2 = _bush(i)
		assert_eq(_map.bushes.at(c), i)
		assert_true(_map.bushes.at(size - c) >= 0, "đối xứng xoay 180°")
		for p: Vector2 in _map.bushes.polygons[i]:
			for t: Vector2 in _map.tower_points:
				assert_true(p.distance_to(t) > 550.0, "bụi %d không lấn tầm bắn trụ" % i)
	assert_eq(_map.bushes.at(Vector2(10, 10)), -1)


func test_VIS_06_unit_in_bush_hidden_from_enemy_in_range() -> void:
	var w: World = _world()
	var hider: Entity = _unit(w, 1, _bush(0))
	var watcher: Entity = _unit(w, 0, _outside(0, 400.0))
	w.step()
	assert_false(Rules.is_visible(0, hider), "trong bụi, địch đứng ngoài không thấy dù trong tầm")
	assert_true(Rules.is_visible(1, watcher), "người trong bụi vẫn thấy ra ngoài")
	hider.position = _outside(0, 300.0)
	w.step()
	assert_true(Rules.is_visible(0, hider), "ra khỏi bụi thì lộ")


func test_VIS_06_same_bush_sees_whole_bush_other_bush_does_not() -> void:
	var w: World = _world()
	var hider: Entity = _unit(w, 1, _bush(0))
	var scout: Entity = _unit(w, 0, _bush(0) + Vector2(30, 0), 0.0)
	var other: Entity = _unit(w, 0, _bush(2))
	w.step()
	assert_true(Rules.is_visible(0, hider), "đồng đội cùng bụi cho cả đội thấy, kể cả tầm nhìn 0")
	scout.position = _bush(1)
	w.step()
	assert_false(Rules.is_visible(0, hider), "đứng bụi khác thì không thấy")
	assert_true(other.alive)


func test_VIS_07_attacking_from_bush_reveals_for_1s() -> void:
	var w: World = _world()
	var hider: Entity = _unit(w, 1, _bush(0))
	var victim: Entity = _unit(w, 0, _outside(0, 350.0))
	w.step()
	assert_false(Rules.is_visible(0, hider))
	w.submit(Command.attack(hider.id, victim.id))
	var started: int = -1
	for i: int in range(10):
		w.step()
		if started < 0 and w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"attack_started" and ev.source_id == hider.id):
			started = w.tick
	assert_true(started > 0)
	assert_true(Rules.is_visible(0, hider), "ra tay thì lộ")
	w.submit(Command.stop(hider.id))
	while w.tick < started + 30:
		w.step()
	assert_true(Rules.is_visible(0, hider), "còn lộ tới hết 1 s")
	_steps(w, 2)
	assert_false(Rules.is_visible(0, hider), "hết 1 s thì bụi che lại")


func test_VIS_03_towers_see_into_bushes_only_within_attack_range_and_areas_hit() -> void:
	var w: World = _world()
	var hider: Entity = _unit(w, 1, _bush(0))
	var tower: Entity = _unit(w, 0, _outside(0, 450.0), 1200.0, Entity.Kind.TOWER)
	tower.stats.set_base(StatId.Id.ATTACK_RANGE, 300)
	tower.stats.recompute()
	w.step()
	assert_false(Rules.is_targetable(tower, hider), "ngoài tầm bắn trụ: bụi vẫn che")
	tower.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	tower.stats.recompute()
	w.step()
	assert_true(Rules.is_targetable(tower, hider), "trong tầm bắn trụ: trụ thấy cả trong bụi (D-83)")
	var hit: DamageAction = DamageAction.new()
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "100"
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "150"
	area.actions = [hit]
	var ctx: ExprContext = ExprContext.make(tower, tower, {})
	ctx.point = _bush(0)
	ActionRunner.run(w, [area], ctx, tower.id)
	DamageSystem.resolve(w)
	assert_near(hider.health, 100000.0 - 100.0, EPS, "vùng kỹ năng vẫn trúng trong bụi")


func test_D_30_bush_state_in_hash() -> void:
	var w: World = _world()
	var hider: Entity = _unit(w, 1, _bush(0))
	w.step()
	var h: PackedByteArray = w.state_hash()
	hider.reveal_until_tick = w.tick + 5
	assert_true(w.state_hash() != h)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()
