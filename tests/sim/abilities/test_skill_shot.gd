extends TestCase
## M4.1: đạn kỹ năng định hướng (ABL-05).

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
	return w


## Điểm giữa lane mid, hướng dọc lane (thoáng).
func _origin() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _lane_dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _unit(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.MAX_MANA, 500)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _caster(w: World, at: Vector2, pierce: bool = false) -> Entity:
	var me: Entity = _unit(w, 0, at)
	var hit: DamageAction = DamageAction.new()
	hit.target = ActionDef.Target.TARGET
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "100"
	var shot: ProjectileAction = ProjectileAction.new()
	shot.travel_range = "1000"
	shot.width = "120"
	shot.speed = "1400"
	shot.pierce = "1" if pierce else "0"
	shot.on_hit = [hit]
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_shot"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.DIRECTION
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0])}
	d.on_cast = [shot]
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	me.abilities.append(a)
	return me


func _fire(w: World, me: Entity, dir: Vector2, ticks: int) -> Array[int]:
	w.submit(Command.cast(me.id, Slot.Q, -1, Vector2.INF, dir))
	var hits: Array[int] = []
	for i: int in range(ticks):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"projectile_hit":
				hits.append(ev.target_id)
	return hits


func test_ABL_05_first_enemy_only_then_stops() -> void:
	var w: World = _world()
	var me: Entity = _caster(w, _origin())
	var first: Entity = _unit(w, 1, _origin() + _lane_dir() * 400.0)
	var behind: Entity = _unit(w, 1, _origin() + _lane_dir() * 600.0)
	var hits: Array[int] = _fire(w, me, _lane_dir(), 30)
	assert_eq(hits, [first.id])
	assert_near(first.health, 900.0, EPS)
	assert_near(behind.health, 1000.0, EPS, "đạn dừng ở kẻ đầu tiên")
	assert_true(w.skill_shots.is_empty())


func test_ABL_05_pierce_hits_each_once() -> void:
	var w: World = _world()
	var me: Entity = _caster(w, _origin(), true)
	var a: Entity = _unit(w, 1, _origin() + _lane_dir() * 300.0)
	var b: Entity = _unit(w, 1, _origin() + _lane_dir() * 700.0 + _lane_dir().orthogonal() * 50.0)
	var hits: Array[int] = _fire(w, me, _lane_dir(), 30)
	assert_eq(hits, [a.id, b.id], "theo thứ tự trên đường bay")
	assert_near(a.health, 900.0, EPS, "mỗi kẻ một lần")


func test_ABL_05_width_range_allies_structures() -> void:
	var w: World = _world()
	var me: Entity = _caster(w, _origin())
	var side: Entity = _unit(w, 1, _origin() + _lane_dir() * 300.0 + _lane_dir().orthogonal() * (60.0 + 24.0 + 5.0))
	var edge: Entity = _unit(w, 1, _origin() + _lane_dir() * 500.0 + _lane_dir().orthogonal() * (60.0 + 24.0 - 5.0))
	var ally: Entity = _unit(w, 0, _origin() + _lane_dir() * 200.0)
	var tower: Entity = _unit(w, 1, _origin() + _lane_dir() * 250.0, Entity.Kind.TOWER)
	var far: Entity = _unit(w, 1, _origin() + _lane_dir() * 1100.0)
	var hits: Array[int] = _fire(w, me, _lane_dir(), 40)
	assert_eq(hits, [edge.id], "lệch quá bề rộng không trúng, mép thân chạm thì trúng; bỏ qua đồng minh và trụ")
	assert_near(side.health + ally.health + tower.health + far.health, 4000.0, EPS)


func test_ABL_05_flight_time_and_expires_at_range() -> void:
	var w: World = _world()
	var me: Entity = _caster(w, _origin())
	var target: Entity = _unit(w, 1, _origin() + _lane_dir() * (980.0))
	w.submit(Command.cast(me.id, Slot.Q, -1, Vector2.INF, _lane_dir()))
	var hit_tick: int = -1
	for i: int in range(40):
		w.step()
		if target.health < 1000.0 and hit_tick < 0:
			hit_tick = w.tick
	var expected: int = ceili((980.0 - 24.0) / (1400.0 / 30.0))
	assert_true(absi(hit_tick - expected) <= 1, "bay ~%d tick, trúng ở tick %d" % [expected, hit_tick])
	var w2: World = _world()
	var me2: Entity = _caster(w2, _origin())
	_fire(w2, me2, _lane_dir(), 10)
	assert_eq(w2.skill_shots.size(), 1, "đang bay")
	for i: int in range(15):
		w2.step()
	assert_true(w2.skill_shots.is_empty(), "hết tầm 1000 (~0.71 s) thì biến mất")


func test_ABL_05_blocked_by_terrain() -> void:
	var w: World = _world()
	var origin: Vector2 = _origin()
	var dir: Vector2 = Vector2.ZERO
	var wall: float = 0.0
	for k: int in range(32):
		var d: Vector2 = Vector2.from_angle(TAU * k / 32.0)
		for step: int in range(10, 50):
			if _map.clearance_at(origin + d * step * 16.0) <= 0.0:
				if step * 16.0 >= 200.0 and step * 16.0 <= 700.0:
					dir = d
					wall = step * 16.0
				break
		if dir != Vector2.ZERO:
			break
	assert_true(dir != Vector2.ZERO, "tìm được hướng có rừng/vách trong 200–700")
	var me: Entity = _caster(w, origin, true)
	var hidden: Entity = _unit(w, 1, origin + dir * (wall + 120.0))
	_fire(w, me, dir, 40)
	assert_near(hidden.health, 1000.0, EPS, "núp sau rừng/vách thì đạn không tới")
	assert_true(w.skill_shots.is_empty(), "đạn dừng ở vật cản")


func test_D_30_skill_shots_in_hash() -> void:
	var w: World = _world()
	var me: Entity = _caster(w, _origin())
	w.submit(Command.cast(me.id, Slot.Q, -1, Vector2.INF, _lane_dir()))
	w.step()
	var h1: PackedByteArray = w.state_hash()
	w.skill_shots[0].position += Vector2(1, 0)
	assert_true(w.state_hash() != h1)
