extends TestCase
## M4.2: vùng có độ trễ hiện cho hai đội (ABL-06) và vùng tồn tại (ZoneAction, ABL-17).

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


func _hit(amount: String) -> DamageAction:
	var hit: DamageAction = DamageAction.new()
	hit.target = ActionDef.Target.TARGET
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = amount
	return hit


## Chủ kỹ năng có Q chọn điểm, tầm 900, chạy `on_cast`; `values` thêm vào giá trị có tên.
func _caster(w: World, on_cast: Array[ActionDef], values: Dictionary = {}) -> AbilityInstance:
	var me: Entity = _unit(w, 0, _origin())
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_zone"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.POINT
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0]), &"cast_range": PackedFloat32Array([900, 900, 900, 900, 900])}
	for k: StringName in values:
		d.values[k] = values[k]
	d.on_cast = on_cast
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	me.abilities.append(a)
	return a


func _delayed_area(delay: String = "delay") -> AreaAction:
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "280"
	area.delay = delay
	area.actions = [_hit("100")]
	return area


func _zone(delay: String, duration: String = "4", interval: String = "1") -> ZoneAction:
	var z: ZoneAction = ZoneAction.new()
	z.target = ActionDef.Target.TARGET
	z.delay = delay
	z.radius = "200"
	z.duration = duration
	z.interval = interval
	z.actions = [_hit("60")]
	return z


func _owner(w: World) -> Entity:
	return w.entities[0]


func _cast_at(w: World, point: Vector2) -> void:
	w.submit(Command.cast(_owner(w).id, Slot.Q, -1, point))


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_ABL_06_dodge_by_leaving_and_hit_by_walking_in() -> void:
	var w: World = _world()
	_caster(w, [_delayed_area()], {&"delay": PackedFloat32Array([0.8, 0.8, 0.8, 0.8, 0.8])})
	var spot: Vector2 = _origin() + _lane_dir() * 600.0
	var leaver: Entity = _unit(w, 1, spot)
	var comer: Entity = _unit(w, 1, spot + _lane_dir().orthogonal() * 600.0)
	_cast_at(w, spot)
	_steps(w, 10)
	assert_near(leaver.health, 1000.0, EPS, "chưa tới 0.8 s thì chưa tác dụng")
	leaver.position = spot + _lane_dir().orthogonal() * 500.0
	comer.position = spot + _lane_dir().orthogonal() * 100.0
	_steps(w, 20)
	assert_near(leaver.health, 1000.0, EPS, "ra khỏi vòng trước lúc nổ thì né được")
	assert_near(comer.health, 900.0, EPS, "bước vào lúc nổ thì trúng")
	assert_true(w.pending_areas.is_empty())


func test_ABL_06_pending_area_known_to_both_teams_from_cast() -> void:
	var w: World = _world()
	_caster(w, [_delayed_area()], {&"delay": PackedFloat32Array([0.8, 0.8, 0.8, 0.8, 0.8])})
	var spot: Vector2 = _origin() + _lane_dir() * 600.0
	_cast_at(w, spot)
	w.step()
	assert_eq(w.pending_areas.size(), 1)
	var p: PendingArea = w.pending_areas[0]
	assert_near(p.center.distance_to(spot), 0.0, EPS)
	assert_near(p.radius, 280.0, EPS, "bán kính chốt lúc tung để vẽ vòng báo trước")
	assert_eq(p.team, 0)
	assert_eq(p.due_tick - p.start_tick, 24, "0.8 s")


func test_ABL_06_delay_is_named_value_changed_by_talent() -> void:
	var w: World = _world()
	var a: AbilityInstance = _caster(w, [_delayed_area()], {&"delay": PackedFloat32Array([0.8, 0.8, 0.8, 0.8, 0.8])})
	var change: ValueChangeDef = ValueChangeDef.new()
	change.value_name = &"delay"
	change.op = ValueChangeDef.Op.SET
	change.amount = 0.3
	a.def.talent = TalentDef.new()
	a.def.talent.value_changes = [change]
	a.talent_active = true
	var spot: Vector2 = _origin() + _lane_dir() * 600.0
	var foe: Entity = _unit(w, 1, spot)
	_cast_at(w, spot)
	var hit_tick: int = -1
	var cast_tick: int = w.tick + 1
	for i: int in range(30):
		w.step()
		if foe.health < 1000.0 and hit_tick < 0:
			hit_tick = w.tick
	assert_eq(hit_tick - cast_tick, 9, "talent: độ trễ 0.3 s")


func test_ABL_17_zone_runs_each_interval_for_duration() -> void:
	var w: World = _world()
	_caster(w, [_zone("0")])
	var spot: Vector2 = _origin() + _lane_dir() * 600.0
	var foe: Entity = _unit(w, 1, spot)
	var creep: Entity = _unit(w, 1, spot + Vector2(50, 0), Entity.Kind.LANE_CREEP)
	var ally: Entity = _unit(w, 0, spot + Vector2(-50, 0))
	var tower: Entity = _unit(w, 1, spot + Vector2(0, 60), Entity.Kind.TOWER)
	_cast_at(w, spot)
	var pulses: int = 0
	for i: int in range(6 * 30):
		w.step()
		for ev: GameEvent in w.events:
			pulses += int(ev.type == &"damage_taken" and ev.target_id == foe.id)
	assert_eq(pulses, 4, "đứng trong vùng 4 s, mỗi 1 s một lần: đúng 4 lần")
	assert_near(foe.health, 1000.0 - 4 * 60.0, EPS)
	assert_near(creep.health, 1000.0 - 4 * 60.0, EPS, "trúng cả lính")
	assert_near(ally.health, 1000.0, EPS, "không trúng đồng minh")
	assert_near(tower.health, 1000.0, EPS, "không trúng công trình")
	assert_true(w.zones.is_empty(), "hết 4 s thì mất")


func test_ABL_17_zone_after_delay_hits_only_who_is_inside() -> void:
	var w: World = _world()
	_caster(w, [_delayed_area("1"), _zone("1")])
	var spot: Vector2 = _origin() + _lane_dir() * 600.0
	var foe: Entity = _unit(w, 1, spot)
	_cast_at(w, spot)
	w.step()
	assert_eq(w.zones.size(), 1, "vùng có ngay từ lúc tung để vẽ, chưa tác dụng")
	assert_eq(w.zones[0].start_tick - w.tick, 30)
	_steps(w, 29)
	assert_near(foe.health, 1000.0, EPS, "chưa tới 1 s")
	w.step()
	assert_near(foe.health, 1000.0 - 100.0 - 60.0, EPS, "sao băng rơi rồi vùng cháy tác dụng lần đầu")
	_steps(w, 45)
	foe.position = spot + Vector2(500, 0)
	_steps(w, 90)
	assert_near(foe.health, 1000.0 - 100.0 - 2 * 60.0, EPS, "ra khỏi vùng thì thôi bị đốt")


func test_D_30_pending_areas_and_zones_in_hash() -> void:
	var w: World = _world()
	_caster(w, [_delayed_area("1"), _zone("1")])
	_cast_at(w, _origin() + _lane_dir() * 600.0)
	w.step()
	var h1: PackedByteArray = w.state_hash()
	w.pending_areas[0].due_tick += 1
	var h2: PackedByteArray = w.state_hash()
	assert_true(h2 != h1, "vùng chờ nổ thuộc trạng thái")
	w.zones[0].next_tick += 1
	assert_true(w.state_hash() != h2, "vùng tồn tại thuộc trạng thái")
