extends TestCase
## M3.6b: PRD (RNG-01), chí mạng (CMB-07), bash (CMB-08, D-63), né/trượt (CMB-11).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01

static var _map: MapLayout


func _world(seed_value: int = 1) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(seed_value, Fixture.make())
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _origin() -> Vector2:
	return _map.fountain_point(0) + Vector2(300, -300)


func _unit(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 100)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _passive(id: StringName) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.duration = "0"
	d.tags = [&"passive"]
	return d


func _crit(id: StringName, chance: String, mult: String) -> EffectDef:
	var d: EffectDef = _passive(id)
	d.crit_chance = chance
	d.crit_multiplier = mult
	return d


func _hits(w: World, a: Entity, b: Entity, ticks: int) -> Array[float]:
	w.submit(Command.attack(a.id, b.id))
	var out: Array[float] = []
	for i: int in range(ticks):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"attack_landed" and ev.source_id == a.id:
				out.append(ev.amount)
	return out


func test_RNG_01_prd_rate_matches_within_one_percent() -> void:
	for p: float in [0.15, 0.25, 0.5]:
		var w: World = _world(7)
		var procs: int = 0
		for i: int in range(10000):
			procs += int(Prd.roll(w, 1, p))
		assert_near(procs / 10000.0, p, 0.01, "PRD %.2f" % p)


func test_RNG_01_prd_caps_failure_streaks() -> void:
	var w: World = _world(3)
	var c: float = Prd.constant(0.25)
	assert_true(c > 0.05 and c < 0.25, "C(25%%) ≈ 0.085")
	var streak: int = 0
	var worst: int = 0
	for i: int in range(10000):
		if Prd.roll(w, 2, 0.25):
			streak = 0
		else:
			streak += 1
			worst = maxi(worst, streak)
	assert_true(worst < ceili(1.0 / c), "không bao giờ trượt quá 1/C lần liền (%d)" % worst)


func test_RNG_01_counters_separate_per_key_and_in_hash() -> void:
	var w: World = _world()
	var before: PackedByteArray = w.state_hash()
	Prd.roll(w, 5, 0.1)
	assert_true(w.state_hash() != before, "bộ đếm PRD nằm trong băm trạng thái")


func test_CMB_07_crit_multiplies_attack_highest_wins() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	Effects.apply(w, a, _crit(&"c1", "1", "1.5"), a)
	Effects.apply(w, a, _crit(&"c2", "1", "2.2"), a)
	var hits: Array[float] = _hits(w, a, b, 12)
	assert_eq(hits.size(), 1)
	assert_near(hits[0], 220.0, EPS, "hai nguồn cùng trúng → lấy 2.2, không nhân nhau")


func test_CMB_07_no_crit_on_structures_and_not_on_trigger_damage() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var tower: Entity = _unit(w, 1, _origin() + Vector2(100, 0), Entity.Kind.TOWER)
	Effects.apply(w, a, _crit(&"c", "1", "3"), a)
	var hits: Array[float] = _hits(w, a, tower, 12)
	assert_near(hits[0], 100.0 * w.balance.hero_structure_damage, EPS, "không chí mạng lên công trình")
	var w2: World = _world()
	var a2: Entity = _unit(w2, 0, _origin())
	var b2: Entity = _unit(w2, 1, _origin() + Vector2(100, 0))
	Effects.apply(w2, a2, _crit(&"c", "1", "2"), a2)
	var extra: DamageAction = DamageAction.new()
	extra.target = ActionDef.Target.TARGET
	extra.damage_type = DamageFormulas.DamageType.PHYSICAL
	extra.amount = "40"
	var on_hit: TriggerDef = TriggerDef.new()
	on_hit.event = &"attack_landed"
	on_hit.actions = [extra]
	var bash: EffectDef = _passive(&"bash")
	bash.triggers = [on_hit]
	Effects.apply(w2, a2, bash, a2)
	_hits(w2, a2, b2, 12)
	assert_near(b2.health, 100000.0 - 200.0 - 40.0, EPS, "sát thương thêm của trigger không nhân chí mạng")


func test_CMB_07_crit_rate_follows_prd() -> void:
	var w: World = _world(11)
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	Effects.apply(w, a, _crit(&"c", "0.25", "2"), a)
	var hits: Array[float] = _hits(w, a, b, 30 * 400)
	var crits: int = hits.filter(func(x: float) -> bool: return x > 150.0).size()
	assert_near(float(crits) / hits.size(), 0.25, 0.05, "%d/%d" % [crits, hits.size()])


func test_CMB_11_full_evasion_vs_accuracy() -> void:
	var w: World = _world(5)
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	b.stats.set_base(StatId.Id.EVASION, 1.0)
	b.stats.recompute()
	var missed: int = 0
	w.submit(Command.attack(a.id, b.id))
	for i: int in range(30 * 20):
		w.step()
		for ev: GameEvent in w.events:
			missed += int(ev.type == &"attack_missed")
	assert_eq(b.health, 100000.0, "né 100%, không chính xác → trượt hết")
	assert_eq(missed, 20)
	a.stats.set_base(StatId.Id.ACCURACY, 0.8)
	a.stats.recompute()
	var hits: Array[float] = _hits(w, a, b, 30 * 500)
	assert_near(hits.size() / 500.0, 0.8, 0.04, "chính xác 80% → trúng ~80%")


func test_CMB_11_miss_does_not_trigger_on_hit() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	b.stats.set_base(StatId.Id.EVASION, 1.0)
	b.stats.recompute()
	var stun: EffectDef = EffectDef.new()
	stun.id = &"stun"
	stun.duration = "1"
	stun.states = [UnitState.Id.STUNNED]
	var apply: ApplyEffectAction = ApplyEffectAction.new()
	apply.target = ActionDef.Target.TARGET
	apply.effect = stun
	var on_hit: TriggerDef = TriggerDef.new()
	on_hit.event = &"attack_landed"
	on_hit.actions = [apply]
	var bash: EffectDef = _passive(&"bash")
	bash.triggers = [on_hit]
	Effects.apply(w, a, bash, a)
	_hits(w, a, b, 60)
	assert_false(Rules.has_state(b, UnitState.Id.STUNNED), "đòn trượt không bash")


func test_D_63_bash_cooldown_is_per_source_data() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var extra: DamageAction = DamageAction.new()
	extra.target = ActionDef.Target.TARGET
	extra.damage_type = DamageFormulas.DamageType.PURE
	extra.amount = "10"
	var free: TriggerDef = TriggerDef.new()
	free.event = &"attack_landed"
	free.chance = "1"
	free.unique_group = &"bash"
	free.actions = [extra]
	var bash: EffectDef = _passive(&"bash")
	bash.triggers = [free]
	Effects.apply(w, a, bash, a)
	var hits: Array[float] = _hits(w, a, b, 30 * 5)
	assert_near(b.health, 100000.0 - hits.size() * 110.0, EPS, "bash không khai báo chờ thì đòn nào cũng tung")
