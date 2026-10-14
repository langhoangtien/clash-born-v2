extends TestCase
## M3.3: trigger (EFF-04, EFF-05, EFF-08), hành động ApplyEffect, RemoveEffect, Area, Dispel,
## Purge (EFF-07), nhóm duy nhất cho trigger (STAT-05).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01
const T := ActionDef.Target

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, Fixture.make())
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
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _effect(id: StringName, duration: String = "0", tags: Array[StringName] = []) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.duration = duration
	d.tags = tags
	return d


func _damage(target: ActionDef.Target, amount: String, type: DamageFormulas.DamageType = DamageFormulas.DamageType.PURE) -> DamageAction:
	var a: DamageAction = DamageAction.new()
	a.target = target
	a.amount = amount
	a.damage_type = type
	return a


func _apply(target: ActionDef.Target, effect: EffectDef, duration: String = "") -> ApplyEffectAction:
	var a: ApplyEffectAction = ApplyEffectAction.new()
	a.target = target
	a.effect = effect
	a.duration = duration
	return a


func _trigger(event: StringName, role: TriggerDef.Role, actions: Array[ActionDef], condition: StringName = &"") -> TriggerDef:
	var t: TriggerDef = TriggerDef.new()
	t.event = event
	t.role = role
	t.condition = condition
	t.actions = actions
	return t


func _passive(id: StringName, triggers: Array[TriggerDef]) -> EffectDef:
	var d: EffectDef = _effect(id, "0", [&"passive"])
	d.triggers = triggers
	return d


func _stun() -> EffectDef:
	var d: EffectDef = _effect(&"stun", "", [&"debuff"])
	d.states = [UnitState.Id.STUNNED]
	d.dispel = EffectDef.Dispel.STRONG
	return d


func _fight(w: World, a: Entity, b: Entity, ticks: int) -> void:
	w.submit(Command.attack(a.id, b.id))
	for i: int in range(ticks):
		w.step()


func test_EFF_08_source_role_on_hit_applies_effect_to_victim() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	Effects.apply(w, a, _passive(&"bash", [_trigger(&"attack_landed", TriggerDef.Role.SOURCE,
		[_apply(T.TARGET, _stun(), "1"), _damage(T.TARGET, "25")])]), a)
	_fight(w, a, b, 12)
	assert_true(Rules.has_state(b, UnitState.Id.STUNNED), "đánh trúng thì mục tiêu bị choáng")
	assert_near(b.health, 1000.0 - 50.0 - 25.0, EPS, "đòn đánh + sát thương thêm")
	assert_false(Rules.has_state(a, UnitState.Id.STUNNED))


func test_EFF_08_target_role_reacts_when_hit() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	Effects.apply(w, b, _passive(&"retaliate", [_trigger(&"attack_landed", TriggerDef.Role.TARGET,
		[_damage(T.EVENT_SOURCE, "20 + 0.1 * event.damage")])]), b)
	_fight(w, a, b, 12)
	assert_near(a.health, 1000.0 - 25.0, EPS, "bị đánh 50 → trả 20 + 5")


func test_EFF_08_conditions_target_is_hero_and_not_structure() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var creep: Entity = _unit(w, 1, _origin() + Vector2(100, 0), Entity.Kind.LANE_CREEP)
	Effects.apply(w, a, _passive(&"hero_only", [_trigger(&"attack_landed", TriggerDef.Role.SOURCE,
		[_damage(T.TARGET, "100")], &"target_is_hero")]), a)
	_fight(w, a, creep, 12)
	assert_near(creep.health, 950.0, EPS, "lính không phải hero → không kích hoạt")
	var w2: World = _world()
	var b: Entity = _unit(w2, 0, _origin())
	var tower: Entity = _unit(w2, 1, _origin() + Vector2(100, 0), Entity.Kind.TOWER)
	Effects.apply(w2, b, _passive(&"no_struct", [_trigger(&"attack_landed", TriggerDef.Role.SOURCE,
		[_damage(T.TARGET, "100")], &"target_not_structure")]), b)
	_fight(w2, b, tower, 12)
	assert_near(tower.health, 1000.0 - 50.0 * w2.balance.hero_structure_damage, EPS)


func test_EFF_08_this_effect_depleted_fires_only_on_shield_break() -> void:
	var w: World = _world()
	var e: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var shield: EffectDef = _effect(&"iron", "3")
	shield.absorb = "60"
	shield.triggers = [_trigger(&"effect_removed", TriggerDef.Role.TARGET, [_damage(T.SELF, "-0")], &"this_effect_depleted")]
	var burst: DamageAction = _damage(T.TARGET, "30")
	var area: AreaAction = AreaAction.new()
	area.target = T.SELF
	area.radius = "300"
	area.actions = [burst]
	shield.triggers[0].actions = [area]
	Effects.apply(w, e, shield, e)
	_fight(w, foe, e, 12)
	assert_near(foe.health, 1000.0, EPS, "khiên còn → chưa nổ")
	for i: int in range(30):
		w.step()
	assert_near(foe.health, 970.0, EPS, "khiên vỡ → nổ vùng quanh chủ")
	var w2: World = _world()
	var e2: Entity = _unit(w2, 0, _origin())
	var foe2: Entity = _unit(w2, 1, _origin() + Vector2(100, 0))
	Effects.apply(w2, e2, shield, e2)
	for i: int in range(100):
		w2.step()
	assert_near(foe2.health, 1000.0, EPS, "hết giờ (không vỡ) → không nổ")


func test_EFF_08_this_effect_ended_fires_on_expire_not_on_death() -> void:
	var w: World = _world()
	var e: Entity = _unit(w, 0, _origin())
	var heal_end: HealAction = HealAction.new()
	heal_end.target = T.SELF
	heal_end.amount = "200"
	var d: EffectDef = _effect(&"undying", "1", [&"buff"])
	d.triggers = [_trigger(&"effect_removed", TriggerDef.Role.TARGET, [heal_end], &"this_effect_ended")]
	e.health = 500.0
	Effects.apply(w, e, d, e)
	for i: int in range(32):
		w.step()
	assert_near(e.health, 700.0, EPS)


func test_EFF_04_mutual_reflect_stops_after_four_layers() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	for e: Entity in [a, b]:
		Effects.apply(w, e, _passive(&"thorns", [_trigger(&"damage_taken", TriggerDef.Role.TARGET,
			[_damage(T.EVENT_SOURCE, "1")])]), e)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = a.id
	r.target_id = b.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()
	assert_near(a.health, 1000.0 - 2.0, EPS, "a nhận phản tầng 1 và 3")
	assert_near(b.health, 1000.0 - 10.0 - 2.0, EPS, "b nhận 10 gốc + phản tầng 2 và 4; sau tầng 4 dừng")


func test_EFF_trigger_cooldown() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var t: TriggerDef = _trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "100")])
	t.cooldown = "2.5"
	Effects.apply(w, a, _passive(&"cd", [t]), a)
	_fight(w, a, b, 100)
	assert_near(b.health, 1000.0 - 4 * 50.0 - 2 * 100.0, EPS, "4 đòn trong ~3.3 s, bị động kích hoạt 2 lần")


func test_STAT_05_trigger_group_item_beats_skill() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var innate: TriggerDef = _trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "300")])
	innate.unique_group = &"bash"
	var hammer: TriggerDef = _trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "10")])
	hammer.unique_group = &"bash"
	Effects.apply(w, a, _passive(&"innate", [innate]), a)
	Effects.apply(w, a, _passive(&"item:hammer", [hammer]), a, {}, "", 2)
	_fight(w, a, b, 12)
	assert_near(b.health, 1000.0 - 50.0 - 10.0, EPS, "D-55: chỉ bash của đồ tung")


func test_EFF_trigger_chance_uses_seeded_rng() -> void:
	var counts: Array[float] = []
	for run: int in range(2):
		var w: World = _world()
		var a: Entity = _unit(w, 0, _origin())
		var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
		b.stats.set_base(StatId.Id.MAX_HP, 100000)
		b.stats.recompute()
		b.health = 100000.0
		var t: TriggerDef = _trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "1000")])
		t.chance = "0.25"
		Effects.apply(w, a, _passive(&"luck", [t]), a)
		_fight(w, a, b, 30 * 200)
		counts.append(b.health)
	var procs: float = (100000.0 - counts[0] - 200.0 * 50.0) / 1000.0
	assert_true(procs > 30 and procs < 70, "khoảng 25%% của 200 đòn: %d" % procs)
	assert_eq(counts[0], counts[1], "cùng seed → cùng kết quả")


func test_EFF_05_removed_by_own_events_after_apply_trigger_first() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var veil: EffectDef = _effect(&"veil", "10", [&"buff"])
	veil.removed_by = [&"attack_landed"]
	veil.triggers = [_trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "40")])]
	Effects.apply(w, a, veil, a)
	w.submit(Command.attack(b.id, a.id))
	for i: int in range(12):
		w.step()
	assert_eq(a.effects.size(), 1, "bị đánh không làm mất (chỉ sự kiện mình gây ra)")
	w.submit(Command.attack(a.id, b.id))
	var reasons: Array[StringName] = []
	for i: int in range(12):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"effect_removed":
				reasons.append(ev.reason)
	assert_eq(a.effects.size(), 0)
	assert_eq(reasons, [&"removed_by_event"])
	assert_near(b.health, 1000.0 - 50.0 - 40.0, EPS, "trigger của cùng sự kiện chạy trước khi mất")


func test_ACTION_remove_effect() -> void:
	var w: World = _world()
	var a: Entity = _unit(w, 0, _origin())
	var b: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var ready: EffectDef = _effect(&"ambush_ready", "10", [&"buff"])
	var remove: RemoveEffectAction = RemoveEffectAction.new()
	remove.target = T.SELF
	remove.effect = ready
	ready.triggers = [_trigger(&"attack_landed", TriggerDef.Role.SOURCE, [_damage(T.TARGET, "60"), remove])]
	Effects.apply(w, a, ready, a)
	_fight(w, a, b, 45)
	assert_eq(a.effects.size(), 0)
	assert_near(b.health, 1000.0 - 2 * 50.0 - 60.0, EPS, "chỉ đòn đầu có thêm 60")


func test_ACTION_area_circle_hits_enemies_only_after_delay() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var near: Entity = _unit(w, 1, _origin() + Vector2(150, 0))
	var far: Entity = _unit(w, 1, _origin() + Vector2(0, -600))
	var ally: Entity = _unit(w, 0, _origin() + Vector2(-100, 0))
	var tower: Entity = _unit(w, 1, _origin() + Vector2(0, 200), Entity.Kind.TOWER)
	var area: AreaAction = AreaAction.new()
	area.target = T.SELF
	area.radius = "radius"
	area.delay = "0.5"
	area.actions = [_damage(T.TARGET, "dmg")]
	ActionRunner.run(w, [area], ExprContext.make(me, me, {&"radius": 300.0, &"dmg": 70.0}), me.id)
	for i: int in range(14):
		w.step()
	assert_near(near.health, 1000.0, EPS, "chưa tới 0.5 s")
	w.step()
	assert_near(near.health, 930.0, EPS)
	assert_near(far.health, 1000.0, EPS)
	assert_near(ally.health, 1000.0, EPS)
	assert_near(tower.health, 1000.0, EPS, "kỹ năng vùng không đánh công trình")


func test_ACTION_area_rect_along_direction() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var ahead: Entity = _unit(w, 1, _origin() + Vector2(0, -400))
	var side: Entity = _unit(w, 1, _origin() + Vector2(250, -200))
	var behind: Entity = _unit(w, 1, _origin() + Vector2(0, 200))
	var area: AreaAction = AreaAction.new()
	area.shape = AreaAction.Shape.RECT
	area.target = T.SELF
	area.length = "700"
	area.width = "200"
	area.actions = [_damage(T.TARGET, "50")]
	var ctx: ExprContext = ExprContext.make(me, me)
	ctx.direction = Vector2.UP
	ActionRunner.run(w, [area], ctx, me.id)
	w.step()
	assert_near(ahead.health, 950.0, EPS)
	assert_near(side.health, 1000.0, EPS)
	assert_near(behind.health, 1000.0, EPS)


func test_EFF_07_dispel_levels_and_purge_on_each() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _origin())
	var foe: Entity = _unit(w, 1, _origin() + Vector2(100, 0))
	var slow: EffectDef = _effect(&"slow", "5", [&"debuff"])
	Effects.apply(w, me, slow, foe)
	Effects.apply(w, me, _stun(), foe, {}, "5")
	var dispel: DispelAction = DispelAction.new()
	dispel.target = T.SELF
	dispel.level = EffectDef.Dispel.BASIC
	ActionRunner.run(w, [dispel], ExprContext.make(me, me), me.id)
	assert_eq(me.effects.size(), 1, "cơ bản gỡ chậm, không gỡ choáng")
	dispel.level = EffectDef.Dispel.STRONG
	ActionRunner.run(w, [dispel], ExprContext.make(me, me), me.id)
	assert_eq(me.effects.size(), 0, "mạnh gỡ cả choáng")
	var haste: EffectDef = _effect(&"haste", "5", [&"buff"])
	var ult: EffectDef = _effect(&"ult", "5", [&"buff"])
	ult.dispel = EffectDef.Dispel.NONE
	Effects.apply(w, foe, haste, foe)
	Effects.apply(w, foe, ult, foe)
	var purge: PurgeAction = PurgeAction.new()
	purge.target = T.TARGET
	purge.on_each = [_damage(T.TARGET, "100")]
	ActionRunner.run(w, [purge], ExprContext.make(me, foe), me.id)
	w.step()
	assert_eq(foe.effects.size(), 1, "NONE không tước được")
	assert_near(foe.health, 900.0, EPS, "mỗi buff tước được gây 100")
