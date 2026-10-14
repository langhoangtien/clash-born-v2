extends TestCase
## M3.4: dùng chiêu — ABL-02 (điều kiện, mana, hồi chiêu lúc bắt đầu), ABL-03 (hủy khi bị
## khống chế), ABL-07 (lọc đối tượng vùng), ABL-11 (nội tại cấp 1), D-59 (tầm, điểm, lệnh chờ),
## hồi máu/mana theo giây.

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
	var w: World = World.new(3, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-700, 700)


func _brakk(w: World, team: int, at: Vector2) -> Entity:
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))


func _dummy(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = w.navigation(24.0).nearest_clear(at)
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 2000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _rejected(w: World, c: Command) -> Command.Reject:
	w.submit(c)
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


## Kỹ năng thử: gây `damage` thuần trong vùng tròn bán kính 150 quanh `center`.
func _test_ability(targeting: AbilityDef.Targeting, cast_range: float, cast_time: String = "0") -> AbilityDef:
	var hit: DamageAction = DamageAction.new()
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "damage"
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "150"
	area.actions = [hit]
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_q"
	d.slot = Slot.Q
	d.targeting = targeting
	d.cast_time = cast_time
	d.values = {&"damage": PackedFloat32Array([100, 200, 300, 400, 500]), &"mana": PackedFloat32Array([50, 50, 50, 50, 50]),
		&"cooldown": PackedFloat32Array([5, 5, 5, 5, 5]), &"cast_range": PackedFloat32Array([cast_range, cast_range, cast_range, cast_range, cast_range])}
	d.on_cast = [area]
	return d


func _give(w: World, e: Entity, d: AbilityDef, rank: int = 1) -> AbilityInstance:
	var a: AbilityInstance = Abilities.of(e, Slot.Q)
	a.def = d
	Abilities.set_rank(w, e, a, rank)
	return a


func test_ABL_11_hero_spawns_with_innate_rank_1_and_its_passive() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	assert_eq(b.abilities.size(), 4)
	assert_eq(Abilities.of(b, Slot.INNATE).rank, 1)
	assert_eq(Abilities.of(b, Slot.Q).rank, 0)
	assert_eq(b.effects.size(), 1)
	assert_eq(b.effects[0].def.id, &"brakk_bash_passive")
	assert_near(b.effects[0].values[&"chance"], 0.15, EPS)


func test_ABL_passive_rank_up_reapplies_with_new_values() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	Abilities.set_rank(w, b, Abilities.of(b, Slot.INNATE), 3)
	assert_eq(b.effects.size(), 1, "không chồng hai bản bị động")
	assert_near(b.effects[0].values[&"chance"], 0.19, EPS)


func test_ABL_02_rejections() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	assert_eq(_rejected(w, Command.cast(b.id, Slot.Q)), Command.Reject.NOT_LEARNED)
	assert_eq(_rejected(w, Command.cast(b.id, Slot.INNATE)), Command.Reject.CANNOT_CAST, "bị động không dùng được")
	Abilities.set_rank(w, b, Abilities.of(b, Slot.Q), 1)
	b.mana = 10.0
	assert_eq(_rejected(w, Command.cast(b.id, Slot.Q)), Command.Reject.NO_MANA)
	b.mana = 500.0
	var silence: EffectDef = EffectDef.new()
	silence.id = &"silence"
	silence.duration = "1"
	silence.states = [UnitState.Id.SILENCED]
	Effects.apply(w, b, silence, null)
	assert_eq(_rejected(w, Command.cast(b.id, Slot.Q)), Command.Reject.CANNOT_CAST)
	_steps(w, 31)
	assert_eq(_rejected(w, Command.cast(b.id, Slot.Q)), Command.Reject.NONE)
	_steps(w, 15)
	assert_eq(_rejected(w, Command.cast(b.id, Slot.Q)), Command.Reject.ON_COOLDOWN)


func test_ABL_02_brakk_q_mana_cooldown_at_start_effect_after_cast_time() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	var foe: Entity = _dummy(w, 1, _center() + Vector2(200, 0))
	var far: Entity = _dummy(w, 1, _center() + Vector2(0, 500))
	var ally: Entity = _dummy(w, 0, _center() + Vector2(-150, 0))
	var a: AbilityInstance = Abilities.of(b, Slot.Q)
	Abilities.set_rank(w, b, a, 1)
	var mana: float = b.mana
	w.submit(Command.cast(b.id, Slot.Q))
	w.step()
	var start: int = w.tick
	assert_true(b.cast != null, "đang tung")
	assert_near(b.mana, mana - 90.0, EPS, "trừ mana lúc bắt đầu (mana đang đầy nên hồi không cộng thêm)")
	assert_eq(a.ready_tick, start + 14 * 30, "hồi chiêu tính từ lúc bắt đầu")
	_steps(w, 8)
	assert_near(foe.health, 2000.0, EPS, "chưa hết 0.3 s")
	w.step()
	assert_true(foe.health < 2000.0, "hết 0.3 s thì nổ")
	assert_true(Rules.has_state(foe, UnitState.Id.STUNNED))
	assert_near(far.health, 2000.0, EPS)
	assert_near(ally.health, 2000.0, EPS, "không trúng đồng minh (ABL-07)")
	assert_true(b.cast == null and b.order.finished)


func test_ABL_03_stun_during_cast_cancels_without_refund() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	var foe: Entity = _dummy(w, 1, _center() + Vector2(200, 0))
	var a: AbilityInstance = Abilities.of(b, Slot.Q)
	Abilities.set_rank(w, b, a, 1)
	w.submit(Command.cast(b.id, Slot.Q))
	_steps(w, 3)
	var mana: float = b.mana
	var stun: EffectDef = EffectDef.new()
	stun.id = &"stun"
	stun.duration = "0.5"
	stun.states = [UnitState.Id.STUNNED]
	Effects.apply(w, b, stun, null)
	_steps(w, 20)
	assert_true(b.cast == null)
	assert_near(foe.health, 2000.0, EPS, "chiêu bị hủy")
	assert_true(b.mana < mana + 5.0, "không hoàn mana")
	assert_true(w.tick < a.ready_tick, "vẫn hồi chiêu")


func test_D_59_unit_target_out_of_range_walks_in_then_casts() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var foe: Entity = _dummy(w, 1, _center() + Vector2(1, -1).normalized() * 900.0)
	_give(w, me, _test_ability(AbilityDef.Targeting.UNIT, 400))
	w.submit(Command.cast(me.id, Slot.Q, foe.id))
	_steps(w, 5)
	assert_true(me.cast == null and foe.health == 2000.0, "đang đi tới")
	_steps(w, 60)
	assert_near(foe.health, 1900.0, EPS)
	assert_true(Rules.edge_distance(me, foe) <= 400.0 + 1.0, "dừng ở mép tầm")


func test_D_59_point_beyond_range_clamps_to_edge() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var edge: Entity = _dummy(w, 1, me.position + Vector2(600, 0))
	var asked: Entity = _dummy(w, 1, me.position + Vector2(0, -1500))
	edge.position = me.position + Vector2(600, 0)
	asked.position = me.position + Vector2(1500, 0)
	_give(w, me, _test_ability(AbilityDef.Targeting.POINT, 600))
	w.submit(Command.cast(me.id, Slot.Q, -1, me.position + Vector2(1500, 0)))
	_steps(w, 2)
	assert_near(edge.health, 1900.0, EPS, "điểm kéo về mép tầm 600")
	assert_near(asked.health, 2000.0, EPS)
	assert_true(me.position.distance_to(_map.world_size() * 0.5 + Vector2(-700, 700)) < 100.0, "không đi tới")


func test_D_59_orders_wait_until_cast_ends() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	_give(w, me, _test_ability(AbilityDef.Targeting.NO_TARGET, 0, "0.5"))
	w.submit(Command.cast(me.id, Slot.Q))
	w.step()
	var spot: Vector2 = me.position
	w.submit(Command.move_dir(me.id, Vector2.LEFT))
	_steps(w, 10)
	assert_eq(me.position, spot, "joystick không hủy chiêu đang tung")
	_steps(w, 10)
	assert_true(me.position.x < spot.x, "tung xong thì đi theo lệnh đã chờ")


func test_ITM_05_melee_ranged_named_values() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var d: AbilityDef = _test_ability(AbilityDef.Targeting.NO_TARGET, 0)
	d.values[&"chance_melee"] = PackedFloat32Array([0.2, 0.2, 0.2, 0.2, 0.2])
	d.values[&"chance_ranged"] = PackedFloat32Array([0.1, 0.1, 0.1, 0.1, 0.1])
	var a: AbilityInstance = _give(w, me, d)
	assert_near(Abilities.value(me, a, &"chance"), 0.2, EPS, "Brakk cận chiến")
	me.projectile_speed = 900.0
	assert_near(Abilities.value(me, a, &"chance"), 0.1, EPS)


func test_REGEN_hp_and_mana_per_second() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	me.health = 100.0
	me.mana = 0.0
	_steps(w, 30)
	assert_near(me.health, 100.0 + me.stats.get_stat(StatId.Id.HP_REGEN), EPS)
	assert_near(me.mana, me.stats.get_stat(StatId.Id.MANA_REGEN), EPS)


func test_D_30_casts_replay_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world()
		var me: Entity = _brakk(w, 0, _center())
		var foe: Entity = _brakk(w, 1, _center() + Vector2(150, 0))
		Abilities.set_rank(w, me, Abilities.of(me, Slot.Q), 2)
		w.submit(Command.attack(foe.id, me.id))
		for t: int in range(400):
			if t % 50 == 0:
				w.submit(Command.cast(me.id, Slot.Q))
			elif t % 50 == 20:
				w.submit(Command.attack(me.id, foe.id))
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return


func test_ABL_11_brakk_innate_bash_procs_in_fights() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	var foe: Entity = _dummy(w, 1, _center() + Vector2(1, -1).normalized() * 80.0)
	foe.stats.set_base(StatId.Id.MAX_HP, 100000)
	foe.stats.recompute()
	foe.health = 100000.0
	w.submit(Command.attack(b.id, foe.id))
	var stuns: int = 0
	var hits: int = 0
	for t: int in range(30 * 300):
		w.step()
		for ev: GameEvent in w.events:
			stuns += int(ev.type == &"effect_applied" and ev.target_id == foe.id)
			hits += int(ev.type == &"attack_landed" and ev.source_id == b.id)
	assert_true(stuns >= hits * 0.15 * 0.5 and stuns <= hits * 0.15 * 1.6, "nội tại choáng ~15%% được kích hoạt khi đánh (%d / %d đòn)" % [stuns, hits])
