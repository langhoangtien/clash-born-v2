extends TestCase
## M3.6c: viên gạch bị động — phản hồi CMB-09, đốt mana CMB-10, vùng giảm dần; bị động kiểu
## Centaur, Axe, Spectre, Anti-Mage chỉ bằng dữ liệu (hero thử nghiệm, không vào game).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01
const T := ActionDef.Target
const PURE := DamageFormulas.DamageType.PURE

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(2, Fixture.make())
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _origin() -> Vector2:
	return _map.fountain_point(0) + Vector2(300, -300)


func _unit(w: World, team: int, at: Vector2) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 10000)
	e.stats.set_base(StatId.Id.MAX_MANA, 300)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 100)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _damage(target: ActionDef.Target, amount: String, reflected: bool = false, type: DamageFormulas.DamageType = PURE) -> DamageAction:
	var a: DamageAction = DamageAction.new()
	a.target = target
	a.amount = amount
	a.reflected = reflected
	a.damage_type = type
	return a


func _passive(id: StringName, event: StringName, role: TriggerDef.Role, actions: Array[ActionDef], chance: String = "") -> EffectDef:
	var t: TriggerDef = TriggerDef.new()
	t.event = event
	t.role = role
	t.chance = chance
	t.actions = actions
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.duration = "0"
	d.tags = [&"passive"]
	d.triggers = [t]
	return d


func _area(radius: String, actions: Array[ActionDef], falloff: String = "") -> AreaAction:
	var a: AreaAction = AreaAction.new()
	a.target = T.SELF
	a.radius = radius
	a.falloff = falloff
	a.actions = actions
	return a


func _fight(w: World, a: Entity, b: Entity, ticks: int) -> void:
	w.submit(Command.attack(a.id, b.id))
	for i: int in range(ticks):
		w.step()


func _centaur_retaliate() -> EffectDef:
	return _passive(&"retaliate", &"attack_landed", TriggerDef.Role.TARGET,
		[_damage(T.EVENT_SOURCE, "20 + 0.3 * self.strength", true)])


func test_CMB_09_centaur_retaliate_reflects_strength_damage() -> void:
	var w: World = _world()
	var attacker: Entity = _unit(w, 0, _origin())
	var centaur: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	centaur.stats.set_base(StatId.Id.STRENGTH, 50)
	centaur.stats.recompute()
	Effects.apply(w, centaur, _centaur_retaliate(), centaur)
	_fight(w, attacker, centaur, 12)
	assert_near(attacker.health, 10000.0 - 35.0, EPS, "trả 20 + 0.3 × 50")


func test_CMB_09_two_reflectors_never_bounce() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var thorns: EffectDef = _passive(&"thorns", &"damage_taken", TriggerDef.Role.TARGET,
		[_damage(T.EVENT_SOURCE, "10", true)])
	Effects.apply(w, a, thorns, a)
	Effects.apply(w, b, thorns, b)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = a.id
	r.target_id = b.id
	r.raw = 100.0
	r.damage_type = PURE
	w.damage_requests.append(r)
	w.step()
	assert_near(b.health, 10000.0 - 100.0, EPS, "b chỉ nhận đòn gốc")
	assert_near(a.health, 10000.0 - 10.0, EPS, "a nhận một lần phản, phản hồi không phản tiếp")


func test_CMB_09_reflected_damage_is_not_hero_fight_but_credits_kill() -> void:
	var w: World = _world()
	var attacker: Entity = _unit(w, 0, _origin())
	attacker.health = 10.0
	var centaur: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	Effects.apply(w, centaur, _centaur_retaliate(), centaur)
	var fights: int = 0
	w.submit(Command.attack(attacker.id, centaur.id))
	for i: int in range(12):
		w.step()
		for ev: GameEvent in w.events:
			fights += int(ev.type == &"hero_attacked_hero" and ev.source_id == centaur.id)
	assert_eq(fights, 0, "phản hồi không tính giao tranh hero (DEF-11)")
	assert_false(attacker.alive)
	assert_eq(attacker.killer_id, centaur.id, "vẫn tính công hạ gục")


func test_AXE_counter_helix_on_being_hit_area() -> void:
	var w: World = _world()
	var axe: Entity = _unit(w, 1, _origin())
	var near: Entity = _unit(w, 0, _origin() + Vector2(100, 0))
	var far: Entity = _unit(w, 0, _origin() + Vector2(0, -500))
	Effects.apply(w, axe, _passive(&"helix", &"attack_landed", TriggerDef.Role.TARGET,
		[_area("275", [_damage(T.TARGET, "100")])], "1"), axe)
	_fight(w, near, axe, 12)
	assert_near(near.health, 10000.0 - 100.0, EPS)
	assert_near(far.health, 10000.0, EPS)


func test_AREA_falloff_scales_by_distance() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var center: Entity = _unit(w, 1, _origin())
	var half: Entity = _unit(w, 1, _origin() + Vector2(200, 0))
	ActionRunner.run(w, [_area("400", [_damage(T.TARGET, "100")], "1")], ExprContext.make(me, me), me.id)
	w.step()
	assert_near(center.health, 10000.0 - 100.0, EPS, "tâm nhận đủ")
	assert_near(half.health, 10000.0 - 50.0, EPS, "nửa bán kính nhận một nửa")


func test_SPECTRE_dispersion_splits_damage_with_falloff() -> void:
	var w: World = _world()
	var spectre: Entity = _unit(w, 1, _origin())
	var near: Entity = _unit(w, 0, _origin() + Vector2(100, 0))
	var mid: Entity = _unit(w, 0, _origin() + Vector2(350, 0))
	var dispersion: EffectDef = _passive(&"dispersion", &"damage_taken", TriggerDef.Role.TARGET,
		[_area("700", [_damage(T.TARGET, "event.damage * 0.25", true)], "1")])
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"damage_taken_multiplier"
	m.op = ModifierDef.Op.MULTIPLY
	m.value = "0.75"
	dispersion.modifiers = [m]
	Effects.apply(w, spectre, dispersion, spectre)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = near.id
	r.target_id = spectre.id
	r.raw = 400.0
	r.damage_type = PURE
	w.damage_requests.append(r)
	w.step()
	assert_near(spectre.health, 10000.0 - 300.0, EPS, "nhận 75%")
	assert_near(near.health, 10000.0 - 75.0 * (1.0 - 100.0 / 700.0), 0.5, "cách 100: 25% của 300 giảm theo khoảng cách")
	assert_near(mid.health, 10000.0 - 75.0 * 0.5, 0.5, "giữa bán kính: một nửa")


func test_CMB_10_antimage_mana_break_burns_and_damages_burned() -> void:
	var w: World = _world()
	var am: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	foe.mana = 20.0
	var burn: ManaBurnAction = ManaBurnAction.new()
	burn.target = T.TARGET
	burn.amount = "50"
	var on_hit: TriggerDef = TriggerDef.new()
	on_hit.event = &"attack_landed"
	on_hit.actions = [burn]
	var on_burn: TriggerDef = TriggerDef.new()
	on_burn.event = &"mana_burned"
	on_burn.actions = [_damage(T.TARGET, "event.burned_mana * 0.5", false, DamageFormulas.DamageType.PHYSICAL)]
	var mana_break: EffectDef = EffectDef.new()
	mana_break.id = &"mana_break"
	mana_break.duration = "0"
	mana_break.tags = [&"passive"]
	mana_break.triggers = [on_hit, on_burn]
	Effects.apply(w, am, mana_break, am)
	_fight(w, am, foe, 12)
	assert_near(foe.mana, 0.0, EPS, "không âm mana")
	assert_near(foe.health, 10000.0 - 100.0 - 10.0, EPS, "sát thương = 0.5 × mana đốt thực tế (20)")
