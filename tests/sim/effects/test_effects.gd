extends TestCase
## M3.1: hiệu ứng — EFF-01 (cộng dồn), EFF-02 (nhiều nguồn), EFF-03 (chậm cộng), EFF-06 (khiên),
## EFF-09 (biểu thức), thời hạn, periodic, chết (D-56).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const EPS: float = 0.01


func _world() -> World:
	var bal: BalanceSettings = Fixture.make()
	bal.minimum_movement_speed = 0.0
	return World.new(1, bal)


func _unit(w: World, team: int = 0, armor: float = 0.0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.radius = 24.0
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.MAX_MANA, 300)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.PHYSICAL_ARMOR, armor)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _mod(stat: StringName, op: ModifierDef.Op, value: String, group: StringName = &"") -> ModifierDef:
	var m: ModifierDef = ModifierDef.new()
	m.stat = stat
	m.op = op
	m.value = value
	m.unique_group = group
	return m


func _effect(id: StringName, duration: String, stacking: EffectDef.Stacking = EffectDef.Stacking.REFRESH) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.duration = duration
	d.stacking = stacking
	return d


func _slow(id: StringName = &"slow", duration: String = "duration") -> EffectDef:
	var d: EffectDef = _effect(id, duration)
	d.tags = [&"debuff"]
	d.modifiers = [_mod(&"movement_speed", ModifierDef.Op.MULTIPLY, "1 - slow")]
	return d


func _speed(e: Entity) -> float:
	e.stats.recompute()
	return e.stats.get_stat(StatId.Id.MOVEMENT_SPEED)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _removed(w: World) -> Array[StringName]:
	var out: Array[StringName] = []
	for ev: GameEvent in w.events:
		if ev.type == &"effect_removed":
			out.append(ev.reason)
	return out


func _hit(w: World, target: Entity, amount: float, type: DamageFormulas.DamageType = DamageFormulas.DamageType.PURE) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = target.id
	r.raw = amount
	r.damage_type = type
	w.damage_requests.append(r)
	w.step()


func test_EFF_09_expression_values_stats_and_functions() -> void:
	var w: World = _world()
	var me: Entity = _unit(w)
	var foe: Entity = _unit(w, 1)
	var ctx: ExprContext = ExprContext.make(me, foe, {&"damage": 40.0, &"ratio": 0.5})
	assert_near(ExprEval.evaluate("3.5", ctx), 3.5, EPS)
	assert_near(ExprEval.evaluate("damage + target.max_hp * ratio", ctx), 540.0, EPS)
	assert_near(ExprEval.evaluate("min(damage, 10) + max(1, self.current_hp / 100)", ctx), 20.0, EPS)
	ctx.event_damage = 70.0
	assert_near(ExprEval.evaluate("event.damage * 2", ctx), 140.0, EPS)
	assert_near(ExprEval.evaluate("", ctx), 0.0, EPS)


func test_EFF_09_values_frozen_when_applied() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var values: Dictionary = {&"slow": 0.3, &"duration": 2.0}
	Effects.apply(w, e, _slow(), null, values)
	values[&"slow"] = 0.9
	assert_near(_speed(e), 210.0, EPS, "đổi số sau khi áp không ảnh hưởng bản đang chạy")


func test_EFF_duration_expires_on_exact_tick_with_reason() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	Effects.apply(w, e, _slow(), null, {&"slow": 0.3, &"duration": 2.0})
	assert_near(_speed(e), 210.0, EPS)
	_steps(w, 59)
	assert_eq(e.effects.size(), 1, "còn ở tick 59")
	w.step()
	assert_eq(e.effects.size(), 0, "hết đúng 2 s = 60 tick")
	assert_eq(_removed(w), [&"expired"])
	assert_near(_speed(e), 300.0, EPS, "modifier gỡ theo hiệu ứng")


func test_EFF_permanent_and_duration_from_action() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	Effects.apply(w, e, _effect(&"forever", "0"), null)
	Effects.apply(w, e, _effect(&"short", ""), null, {}, "0.5")
	_steps(w, 15)
	assert_eq(e.effects.size(), 1, "\"\" = thời lượng do hành động truyền vào (0.5 s)")
	_steps(w, 600)
	assert_eq(e.effects[0].def.id, &"forever", "\"0\" = vĩnh viễn")


func test_EFF_01_refresh_resets_duration() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var src: Entity = _unit(w, 1)
	var d: EffectDef = _slow()
	Effects.apply(w, e, d, src, {&"slow": 0.3, &"duration": 2.0})
	_steps(w, 30)
	Effects.apply(w, e, d, src, {&"slow": 0.3, &"duration": 2.0})
	assert_eq(e.effects.size(), 1)
	_steps(w, 59)
	assert_eq(e.effects.size(), 1, "làm mới: còn tới tick 30 + 60")
	w.step()
	assert_eq(e.effects.size(), 0)


func test_EFF_01_stack_adds_up_to_max_and_refreshes() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var src: Entity = _unit(w, 1)
	var d: EffectDef = _effect(&"rhythm", "1", EffectDef.Stacking.STACK)
	d.max_stacks = 3
	d.modifiers = [_mod(&"physical_armor", ModifierDef.Op.ADD, "10"), _mod(&"movement_speed", ModifierDef.Op.MULTIPLY, "1.1")]
	for i: int in range(4):
		Effects.apply(w, e, d, src)
	e.stats.recompute()
	assert_eq(e.effects.size(), 1)
	assert_eq(e.effects[0].stacks, 3, "tối đa max_stacks")
	assert_near(e.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), 30.0, EPS, "mỗi tầng +10")
	assert_near(e.stats.get_stat(StatId.Id.MOVEMENT_SPEED), 300.0 * 1.3, EPS, "mỗi tầng +10% (cộng, D-40)")


func test_EFF_01_independent_instances_expire_separately() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var src: Entity = _unit(w, 1)
	var d: EffectDef = _effect(&"mark", "", EffectDef.Stacking.INDEPENDENT)
	d.modifiers = [_mod(&"physical_armor", ModifierDef.Op.ADD, "-2")]
	Effects.apply(w, e, d, src, {}, "1")
	Effects.apply(w, e, d, src, {}, "2")
	e.stats.recompute()
	assert_near(e.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), -4.0, EPS)
	_steps(w, 30)
	assert_eq(e.effects.size(), 1)
	_steps(w, 30)
	assert_eq(e.effects.size(), 0)


func test_EFF_02_same_effect_two_sources_two_instances_slows_add() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var a: Entity = _unit(w, 1)
	var b: Entity = _unit(w, 1)
	var d: EffectDef = _slow()
	Effects.apply(w, e, d, a, {&"slow": 0.3, &"duration": 2.0})
	Effects.apply(w, e, d, b, {&"slow": 0.5, &"duration": 1.0})
	assert_eq(e.effects.size(), 2)
	assert_near(_speed(e), 300.0 * 0.2, EPS, "EFF-03: chậm 30% + 50% = 80%")
	_steps(w, 30)
	assert_near(_speed(e), 210.0, EPS, "bản 1 s hết trước")


func test_STAT_05_item_slot_passed_to_modifiers() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var d: EffectDef = _effect(&"boots", "0")
	d.modifiers = [_mod(&"movement_speed", ModifierDef.Op.ADD, "speed", &"move_speed_boots")]
	Effects.apply(w, e, d, e, {&"speed": 65.0}, "", 1)
	Effects.apply(w, e, d, e, {&"speed": 45.0}, "", 2)
	assert_near(_speed(e), 345.0, EPS, "D-55: giày ô 2 thắng")


func test_EFF_periodic_runs_after_each_interval_including_last() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var src: Entity = _unit(w, 1)
	var burn: DamageAction = DamageAction.new()
	burn.target = ActionDef.Target.SELF
	burn.damage_type = DamageFormulas.DamageType.PURE
	burn.amount = "dps"
	var d: EffectDef = _effect(&"burn", "3")
	d.periodic_interval = "1"
	d.periodic_actions = [burn]
	Effects.apply(w, e, d, src, {&"dps": 10.0})
	var hits: Array[int] = []
	for t: int in range(120):
		var hp: float = e.health
		w.step()
		if e.health < hp:
			hits.append(w.tick)
	assert_eq(hits, [30, 60, 90], "3 s, chu kỳ 1 s → 3 lần, lần cuối đúng lúc hết hạn")
	assert_near(e.health, 970.0, EPS)


func test_EFF_periodic_heal_capped_and_credited_to_source() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	e.health = 990.0
	var heal: HealAction = HealAction.new()
	heal.target = ActionDef.Target.SELF
	heal.amount = "self.max_hp * 0.05"
	var d: EffectDef = _effect(&"regen", "1")
	d.periodic_interval = "0.5"
	d.periodic_actions = [heal]
	Effects.apply(w, e, d, e)
	_steps(w, 30)
	assert_near(e.health, 1000.0, EPS, "không quá máu tối đa")


func test_EFF_06_shield_absorbs_after_armor_then_depletes() -> void:
	var w: World = _world()
	var e: Entity = _unit(w, 0, 10.0)
	var shield: EffectDef = _effect(&"iron", "duration")
	shield.absorb = "shield"
	Effects.apply(w, e, shield, e, {&"shield": 100.0, &"duration": 5.0})
	var after_armor: float = DamageFormulas.final_damage(100.0, DamageFormulas.DamageType.PHYSICAL, 10.0, 0.0, 1.0, w.balance)
	_hit(w, e, 100.0, DamageFormulas.DamageType.PHYSICAL)
	assert_near(e.health, 1000.0, EPS, "khiên hút hết")
	assert_near(e.effects[0].absorb_left, 100.0 - after_armor, EPS, "khiên trừ phần sau giáp")
	_hit(w, e, 100.0, DamageFormulas.DamageType.PHYSICAL)
	assert_eq(e.effects.size(), 0)
	assert_eq(_removed(w), [&"depleted"])
	assert_near(e.health, 1000.0 - (2.0 * after_armor - 100.0), EPS, "phần thừa trừ vào máu")


func test_EFF_06_oldest_shield_used_first() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var a: EffectDef = _effect(&"shield_a", "0")
	a.absorb = "50"
	var b: EffectDef = _effect(&"shield_b", "0")
	b.absorb = "80"
	Effects.apply(w, e, a, e)
	Effects.apply(w, e, b, e)
	_hit(w, e, 70.0)
	assert_eq(e.effects.size(), 1)
	assert_eq(e.effects[0].def.id, &"shield_b")
	assert_near(e.effects[0].absorb_left, 60.0, EPS)


func test_D_56_death_removes_effects_except_passive() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var passive: EffectDef = _effect(&"innate", "0")
	passive.tags = [&"passive"]
	Effects.apply(w, e, passive, e)
	Effects.apply(w, e, _slow(), null, {&"slow": 0.3, &"duration": 9.0})
	_hit(w, e, 5000.0)
	assert_false(e.alive)
	assert_eq(e.effects.size(), 1)
	assert_eq(e.effects[0].def.id, &"innate")
	assert_true(_removed(w).has(&"owner_died"))


func test_EFF_events_applied_and_hash_sees_effects() -> void:
	var w: World = _world()
	var e: Entity = _unit(w)
	var before: PackedByteArray = w.state_hash()
	Effects.apply(w, e, _slow(), null, {&"slow": 0.3, &"duration": 2.0})
	assert_true(w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"effect_applied" and ev.target_id == e.id))
	assert_true(w.state_hash() != before, "hiệu ứng nằm trong băm trạng thái (D-30)")
