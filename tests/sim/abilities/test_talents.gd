extends TestCase
## M3.6: talent cấp 20 (TAL-01..04) với talent thật của Brakk.

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
	var w: World = World.new(9, balance_without_spell_amp(BALANCE_PATH))
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-700, 700)


## Brakk cấp 20, Q/W/R tối đa, đầy mana.
func _brakk20(w: World, team: int = 0) -> Entity:
	var b: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(_center()))
	Progression.add_xp(w, b, 100000.0)
	b.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(b, slot)
		Abilities.set_rank(w, b, a, a.def.expected_ranks())
	b.mana = b.stats.get_stat(StatId.Id.MAX_MANA)
	return b


func _dummy(w: World, at: Vector2) -> Entity:
	var e: Entity = Entity.new()
	e.team = 1
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 5000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _choose(w: World, b: Entity, slot: int) -> Command.Reject:
	w.submit(Command.choose_talent(b.id, slot))
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


func _cast(w: World, b: Entity, slot: int, ticks: int) -> void:
	w.submit(Command.cast(b.id, slot))
	for i: int in range(ticks):
		w.step()


func _stun_ticks(e: Entity) -> int:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(UnitState.Id.STUNNED):
			return inst.end_tick - inst.start_tick
	return 0


func test_TAL_01_only_at_level_20_once() -> void:
	var w: World = _world()
	var low: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, _center())
	Abilities.set_rank(w, low, Abilities.of(low, Slot.Q), 1)
	assert_eq(_choose(w, low, Slot.Q), Command.Reject.CANNOT_CHOOSE_TALENT, "chưa cấp 20")
	var b: Entity = _brakk20(w)
	assert_eq(_choose(w, b, Slot.INNATE), Command.Reject.CANNOT_CHOOSE_TALENT, "nội tại không có talent")
	assert_eq(_choose(w, b, Slot.Q), Command.Reject.NONE)
	assert_eq(b.talent_slot, Slot.Q)
	assert_true(w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"talent_chosen"))
	assert_eq(_choose(w, b, Slot.W), Command.Reject.CANNOT_CHOOSE_TALENT, "chọn rồi không đổi")


func test_TAL_02a_brakk_q_ii_values() -> void:
	var w: World = _world()
	var b: Entity = _brakk20(w)
	var q: AbilityInstance = Abilities.of(b, Slot.Q)
	assert_near(Abilities.value(b, q, &"radius"), 300.0, EPS)
	_choose(w, b, Slot.Q)
	assert_near(Abilities.value(b, q, &"radius"), 400.0, EPS, "Động Đất: bán kính +100")
	assert_near(Abilities.value(b, q, &"stun_duration"), 1.6 + 0.6, EPS, "choáng +0.6 s")
	var foe: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 370.0)
	_cast(w, b, Slot.Q, 12)
	assert_true(foe.health < 5000.0, "trúng ở 370 nhờ bán kính mới")
	assert_eq(_stun_ticks(foe), roundi(2.2 * 30))


func test_TAL_02c_brakk_w_ii_shield_explodes_when_broken() -> void:
	for with_talent: bool in [false, true]:
		var w: World = _world()
		var b: Entity = _brakk20(w)
		var foe: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 200.0)
		if with_talent:
			_choose(w, b, Slot.W)
		_cast(w, b, Slot.W, 2)
		var shield: float = Abilities.value(b, Abilities.of(b, Slot.W), &"shield")
		var r: DamageRequest = DamageRequest.new()
		r.source_id = foe.id
		r.target_id = b.id
		r.raw = shield + 10.0
		r.damage_type = DamageFormulas.DamageType.PURE
		w.damage_requests.append(r)
		w.step()
		var expected: float = DamageFormulas.final_damage(shield, DamageFormulas.DamageType.MAGIC, 0.0, 0.0, 1.0, w.balance)
		assert_near(foe.health, 5000.0 - (expected if with_talent else 0.0), EPS, "Giáp Nổ chỉ khi có talent")


func test_TAL_02c_brakk_r_ii_longer_and_stuns_on_end() -> void:
	var w: World = _world()
	var b: Entity = _brakk20(w)
	var foe: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 200.0)
	_choose(w, b, Slot.R)
	_cast(w, b, Slot.R, 2)
	var undying: EffectInstance = null
	for inst: EffectInstance in b.effects:
		if inst.def.id == &"brakk_undying":
			undying = inst
	assert_true(undying != null)
	assert_eq(undying.end_tick - undying.start_tick, (6 + 2) * 30, "GHOST +2 s")
	for i: int in range(8 * 30):
		w.step()
	assert_true(Rules.has_state(foe, UnitState.Id.STUNNED), "hết Hồn Bất Diệt thì choáng địch quanh 300")


func test_TAL_04_active_effects_keep_old_definition() -> void:
	var w: World = _world()
	var b: Entity = _brakk20(w)
	var foe: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 200.0)
	_cast(w, b, Slot.W, 2)
	_choose(w, b, Slot.W)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = b.id
	r.raw = 10000.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()
	assert_near(foe.health, 5000.0, EPS, "khiên áp trước khi chọn talent: không nổ")


func test_TAL_04_passive_reapplied_and_extra_actions() -> void:
	var w: World = _world()
	var b: Entity = _brakk20(w)
	var passive: EffectDef = EffectDef.new()
	passive.id = &"aura"
	passive.duration = "0"
	passive.tags = [&"passive"]
	var learn: ApplyEffectAction = ApplyEffectAction.new()
	learn.target = ActionDef.Target.SELF
	learn.effect = passive
	var hit: DamageAction = DamageAction.new()
	hit.target = ActionDef.Target.SELF
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "bonus"
	var change: ValueChangeDef = ValueChangeDef.new()
	change.value_name = &"power"
	change.op = ValueChangeDef.Op.MULTIPLY
	change.amount = 2.0
	var talent: TalentDef = TalentDef.new()
	talent.id = &"t"
	talent.value_changes = [change]
	talent.extra_actions = [hit]
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_q"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.NO_TARGET
	d.values = {&"power": PackedFloat32Array([10, 10, 10, 10, 10]), &"bonus": PackedFloat32Array([7, 7, 7, 7, 7])}
	d.on_learn = [learn]
	d.talent = talent
	var q: AbilityInstance = Abilities.of(b, Slot.Q)
	q.def = d
	Abilities.set_rank(w, b, q, 5)
	assert_near(_values_of(b, &"aura")[&"power"], 10.0, EPS)
	_choose(w, b, Slot.Q)
	assert_near(_values_of(b, &"aura")[&"power"], 20.0, EPS, "bị động áp lại ngay với giá trị mới")
	var hp: float = b.health
	_cast(w, b, Slot.Q, 2)
	assert_near(b.health, hp - 7.0 + b.stats.get_stat(StatId.Id.HP_REGEN) / 30.0, 0.05, "hành động thêm của talent chạy")


func _values_of(e: Entity, id: StringName) -> Dictionary:
	for inst: EffectInstance in e.effects:
		if inst.def.id == id:
			return inst.values
	return {}


func test_TAL_01_auto_choose_follows_priority() -> void:
	var w: World = _world()
	var b: Entity = _brakk20(w)
	assert_eq(AutoSkill.pick_talent(b, _lib.heroes[&"brakk"].bot_talent_priority), Slot.Q)
	_choose(w, b, Slot.Q)
	assert_eq(AutoSkill.pick_talent(b, _lib.heroes[&"brakk"].bot_talent_priority), -2, "đã chọn thì thôi")
