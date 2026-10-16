extends TestCase
## M6.1: INVULNERABLE, MAGIC_IMMUNE, HEXED và kết hợp state (ST-07, ST-15..17, PRI-05, D-78).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot
const T := DamageFormulas.DamageType

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


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _unit(w: World, team: int, at: Vector2) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.radius = 24.0
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


func _effect(states: Array[UnitState.Id], tag: StringName = &"buff", id: StringName = &"test_state") -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.states = states
	d.tags = [tag]
	return d


func _hit(w: World, source: Entity, target: Entity, type: DamageFormulas.DamageType, amount: float = 100.0, pierce: bool = false) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = amount
	r.damage_type = type
	r.pierces_magic_immunity = pierce
	w.damage_requests.append(r)
	DamageSystem.resolve(w)


func _ability(targeting: AbilityDef.Targeting, actions: Array[ActionDef], pierce: bool = false) -> AbilityDef:
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_spell"
	d.slot = Slot.Q
	d.targeting = targeting
	d.pierces_magic_immunity = pierce
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0]), &"cast_range": PackedFloat32Array([800, 800, 800, 800, 800])}
	d.on_cast = actions
	return d


func _give(e: Entity, d: AbilityDef) -> void:
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	e.abilities.append(a)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_ST_07_invulnerable_blocks_all_damage_and_enemy_debuffs() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	var mate: Entity = _unit(w, 0, _center() - Vector2(200, 0))
	Effects.apply(w, me, _effect([UnitState.Id.INVULNERABLE]), me, {}, "5")
	for type: DamageFormulas.DamageType in [T.PHYSICAL, T.MAGIC, T.PURE]:
		_hit(w, foe, me, type)
	assert_near(me.health, 1000.0, EPS, "không nhận sát thương nào")
	assert_true(Effects.apply(w, me, _lib.effects[&"stun"], foe, {}, "1") == null, "chặn debuff mới từ địch")
	assert_true(Effects.apply(w, me, _lib.effects[&"stun"], mate, {}, "1") != null, "debuff của đồng minh vẫn áp")
	assert_true(Rules.is_targetable(foe, me), "INVULNERABLE vẫn bị nhắm (bảng ST)")


func test_ST_17_cyclone_keeps_its_own_states() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	Effects.apply(w, me, _lib.effects[&"cyclone"], foe, {}, "2.5")
	assert_true(Rules.has_state(me, UnitState.Id.STUNNED), "các state trong cùng hiệu ứng vẫn có tác dụng")
	assert_false(Rules.is_targetable(foe, me), "UNTARGETABLE")
	_hit(w, foe, me, T.PURE)
	assert_near(me.health, 1000.0, EPS)


func test_ST_15_magic_immune_damage_by_type_and_pierce() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	Effects.apply(w, me, _lib.effects[&"magic_immune"], me, {}, "5")
	_hit(w, foe, me, T.MAGIC)
	assert_near(me.health, 1000.0, EPS, "phép không vào")
	_hit(w, foe, me, T.PHYSICAL)
	var after_phys: float = me.health
	assert_true(after_phys < 1000.0, "vật lý vẫn vào")
	_hit(w, foe, me, T.PURE)
	assert_near(me.health, after_phys - 100.0, EPS, "pure vẫn vào")
	_hit(w, foe, me, T.MAGIC, 100.0, true)
	assert_true(me.health < after_phys - 100.0, "nguồn xuyên miễn phép gây đủ sát thương phép")


func test_ST_15_magic_immune_dispels_on_start_and_blocks_new_enemy_debuffs() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	var mate: Entity = _unit(w, 0, _center() - Vector2(200, 0))
	Effects.apply(w, me, _lib.effects[&"silence"], foe, {}, "5")
	assert_true(Rules.has_state(me, UnitState.Id.SILENCED))
	Effects.apply(w, me, _lib.effects[&"magic_immune"], me, {}, "5")
	assert_false(Rules.has_state(me, UnitState.Id.SILENCED), "bật miễn phép: thanh tẩy cơ bản")
	assert_true(Effects.apply(w, me, _lib.effects[&"stun"], foe, {}, "1") == null, "chặn debuff mới của địch (kể cả từ đòn đánh)")
	assert_true(Effects.apply(w, me, _lib.effects[&"stun"], foe, {}, "1", 0, true) != null, "trừ nguồn xuyên miễn phép")
	assert_true(Effects.apply(w, mate, _lib.effects[&"root"], mate, {}, "1") != null)
	var buff: EffectDef = _effect([], &"buff", &"test_buff")
	assert_true(Effects.apply(w, me, buff, mate, {}, "2") != null, "hiệu ứng có lợi của đồng minh vẫn áp")


func test_ST_15_targeted_spells_cannot_pick_magic_immune_unless_pierce() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(300, 0))
	Effects.apply(w, foe, _lib.effects[&"magic_immune"], foe, {}, "5")
	var spell: AbilityDef = _ability(AbilityDef.Targeting.UNIT, [])
	assert_false(Abilities.accepts(me, spell, foe), "chiêu nhắm đơn vị không chọn được")
	assert_true(Rules.is_attackable(me, foe), "đánh thường vẫn được")
	var piercing: AbilityDef = _ability(AbilityDef.Targeting.UNIT, [], true)
	assert_true(Abilities.accepts(me, piercing, foe), "xuyên miễn phép thì nhắm được")


func test_D_78_area_spell_on_magic_immune_blocks_magic_and_debuff_only() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(300, 0))
	Effects.apply(w, foe, _lib.effects[&"magic_immune"], foe, {}, "5")
	var magic: DamageAction = DamageAction.new()
	magic.damage_type = T.MAGIC
	magic.amount = "100"
	var phys: DamageAction = DamageAction.new()
	phys.damage_type = T.PURE
	phys.amount = "40"
	var root: ApplyEffectAction = ApplyEffectAction.new()
	root.effect = _lib.effects[&"root"]
	root.duration = "2"
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "200"
	area.actions = [magic, phys, root]
	_give(me, _ability(AbilityDef.Targeting.POINT, [area]))
	w.submit(Command.cast(me.id, Slot.Q, -1, foe.position))
	_steps(w, 2)
	assert_near(foe.health, 1000.0 - 40.0, EPS, "kiểu BKB: chặn phần phép, pure vẫn vào")
	assert_false(Rules.has_state(foe, UnitState.Id.ROOTED), "không dính trói")


func test_PRI_05_ghost_plus_magic_immune_only_pure() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	Effects.apply(w, me, _lib.effects[&"magic_immune"], me, {}, "5")
	Effects.apply(w, me, _lib.effects[&"ghost_form"], me, {}, "5")
	_hit(w, foe, me, T.PHYSICAL)
	_hit(w, foe, me, T.MAGIC)
	assert_near(me.health, 1000.0, EPS)
	_hit(w, foe, me, T.PURE)
	assert_near(me.health, 900.0, EPS, "GHOST + MAGIC_IMMUNE: chỉ còn nhận pure")


func test_ST_16_hex_fixed_speed_no_attack_no_cast_cancels_cast() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(300, 0))
	var fast: EffectDef = EffectDef.new()
	fast.id = &"test_fast"
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"movement_speed"
	m.value = "200"
	fast.modifiers = [m]
	Effects.apply(w, me, fast, me, {}, "10")
	var d: AbilityDef = _ability(AbilityDef.Targeting.NO_TARGET, [])
	d.cast_time = "0.5"
	_give(me, d)
	w.submit(Command.cast(me.id, Slot.Q))
	w.step()
	assert_true(me.cast != null, "đang tung chiêu")
	Effects.apply(w, me, _lib.effects[&"hex"], foe, {}, "3")
	w.step()
	assert_true(me.cast == null, "bị biến hình: hủy chiêu đang tung")
	assert_near(me.stats.get_stat(StatId.Id.MOVEMENT_SPEED), w.balance.hex_move_speed, EPS, "tốc chạy cố định, bỏ qua modifier")
	assert_false(Rules.can_attack(me))
	assert_false(Rules.can_cast(me))
	assert_true(Rules.can_move(me))
	_steps(w, 3 * 30 + 2)
	assert_near(me.stats.get_stat(StatId.Id.MOVEMENT_SPEED), 500.0, EPS, "hết biến hình: tốc cũ")


func test_ST_16_hex_disables_passive_triggers() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	var heal: HealAction = HealAction.new()
	heal.target = ActionDef.Target.SELF
	heal.amount = "50"
	var t: TriggerDef = TriggerDef.new()
	t.event = &"damage_taken"
	t.role = TriggerDef.Role.TARGET
	t.actions = [heal]
	var passive: EffectDef = EffectDef.new()
	passive.id = &"test_passive"
	passive.tags = [&"passive"]
	passive.triggers = [t]
	Effects.apply(w, me, passive, me, {}, "")
	_hit(w, foe, me, T.PURE, 100.0)
	w.step()
	assert_near(me.health, 950.0, 1.0, "bị động chạy bình thường")
	Effects.apply(w, me, _lib.effects[&"hex"], foe, {}, "3")
	_hit(w, foe, me, T.PURE, 100.0)
	w.step()
	assert_near(me.health, 850.0, 1.0, "biến hình: bị động tạm tắt")


func test_EFF_07_purge_on_magic_immune_needs_pierce() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + Vector2(200, 0))
	var haste: EffectDef = _effect([], &"buff", &"test_haste")
	Effects.apply(w, foe, haste, foe, {}, "5")
	Effects.apply(w, foe, _lib.effects[&"magic_immune"], foe, {}, "5")
	var purge: PurgeAction = PurgeAction.new()
	purge.target = ActionDef.Target.TARGET
	var ctx: ExprContext = ExprContext.make(me, foe)
	ctx.ability = _ability(AbilityDef.Targeting.UNIT, [])
	ActionRunner.run(w, [purge], ctx, me.id)
	assert_true(foe.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"test_haste"), "miễn phép: không tước được")
	ctx.ability = _ability(AbilityDef.Targeting.UNIT, [], true)
	ActionRunner.run(w, [purge], ctx, me.id)
	assert_false(foe.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"test_haste"), "nguồn xuyên miễn phép tước được")
	assert_true(Rules.has_state(foe, UnitState.Id.MAGIC_IMMUNE), "miễn phép (dispel NONE/STRONG) không bị tước bởi tước cơ bản")
