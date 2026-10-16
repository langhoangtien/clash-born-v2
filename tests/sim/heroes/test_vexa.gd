extends TestCase
## M6.4: Vexa đúng bảng thiết kế (CONTENT.md): hút Trí tuệ, Q hóa ếch, W sóng gió (đẩy lùi),
## R tước phép xuyên miễn phép, ba talent.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot
const MAGIC := DamageFormulas.DamageType.MAGIC

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(seed_value: int = 4) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(seed_value, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _vexa(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var v: Entity = UnitFactory.hero(w, _lib.heroes[&"vexa"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, v, Abilities.of(v, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	v.mana = 5000.0
	return v


func _vexa20(w: World, talent: int) -> Entity:
	var v: Entity = _vexa(w)
	Progression.add_xp(w, v, 100000.0)
	v.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(v, slot)
		Abilities.set_rank(w, v, a, a.def.expected_ranks())
	v.mana = 5000.0
	w.submit(Command.choose_talent(v.id, talent))
	w.step()
	return v


func _foe(w: World, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity
	if kind == Entity.Kind.HERO:
		e = UnitFactory.hero(w, _lib.heroes[&"brakk"], 1, at)
		e.stats.set_base(StatId.Id.MAX_HP, 100000)
		e.stats.recompute()
		e.health = e.stats.get_stat(StatId.Id.MAX_HP)
		return e
	e = Entity.new()
	e.team = 1
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


## Sát thương phép thực nhận (sau kháng phép, hệ số nhận, miễn theo trạng thái).
func _magic(w: World, e: Entity, amount: float, pierce: bool = false) -> float:
	var st: StatBlock = e.stats
	return DamageFormulas.final_damage(amount, MAGIC, st.get_stat(StatId.Id.PHYSICAL_ARMOR), st.get_stat(StatId.Id.MAGIC_ARMOR),
		st.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), w.balance) * Rules.damage_factor(w, e, MAGIC, pierce)


func _values(slot: int) -> Dictionary:
	return (_lib.heroes[&"vexa"].abilities()[slot] as AbilityDef).values


func _check_values(v: PackedFloat32Array, expected: Array) -> void:
	assert_eq(v.size(), expected.size())
	for i: int in range(mini(v.size(), expected.size())):
		assert_near(v[i], expected[i], 0.0001)


## Bước `n` tick, trả về tổng sát thương `e` nhận (theo sự kiện, không lẫn hồi máu).
func _taken(w: World, e: Entity, n: int) -> float:
	var sum: float = 0.0
	for i: int in range(n):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"damage_taken" and ev.target_id == e.id:
				sum += ev.amount
	return sum


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _has(e: Entity, id: StringName) -> EffectInstance:
	for inst: EffectInstance in e.effects:
		if inst.def.id == id:
			return inst
	return null


func test_vexa_data_matches_design_tables() -> void:
	_world()
	var innate: Dictionary = _values(Slot.INNATE)
	_check_values(innate[&"drain"], [1.0, 1.0, 2.0, 2.0, 3.0, 3.0])
	_check_values(innate[&"duration"], [20.0, 20.0, 25.0, 25.0, 30.0, 30.0])
	var q: Dictionary = _values(Slot.Q)
	_check_values(q[&"hex_duration"], [1.5, 2.0, 2.5, 3.0, 3.5])
	_check_values(q[&"cooldown"], [20.0, 18.0, 16.0, 14.0, 12.0])
	_check_values(q[&"mana"], [100.0, 110.0, 120.0, 130.0, 140.0])
	_check_values(q[&"cast_range"], [600.0, 600.0, 600.0, 600.0, 600.0])
	var wv: Dictionary = _values(Slot.W)
	_check_values(wv[&"damage"], [60.0, 100.0, 140.0, 180.0, 220.0])
	_check_values(wv[&"push"], [300.0, 300.0, 300.0, 300.0, 300.0])
	_check_values(wv[&"length"], [700.0, 700.0, 700.0, 700.0, 700.0])
	_check_values(wv[&"width"], [250.0, 250.0, 250.0, 250.0, 250.0])
	_check_values(wv[&"cooldown"], [14.0, 13.0, 12.0, 11.0, 10.0])
	_check_values(wv[&"mana"], [90.0, 95.0, 100.0, 105.0, 110.0])
	var r: Dictionary = _values(Slot.R)
	_check_values(r[&"slow"], [0.5, 0.6, 0.7])
	_check_values(r[&"slow_duration"], [3.0, 3.5, 4.0])
	_check_values(r[&"damage_per_buff"], [80.0, 120.0, 160.0])
	_check_values(r[&"cooldown"], [70.0, 60.0, 50.0])
	_check_values(r[&"mana"], [150.0, 175.0, 200.0])
	_check_values(r[&"cast_range"], [700.0, 700.0, 700.0])
	assert_true((_lib.heroes[&"vexa"].abilities()[Slot.R] as AbilityDef).pierces_magic_immunity, "R xuyên miễn phép")
	assert_near(_lib.heroes[&"vexa"].stats.attack_range, 550.0, EPS)


func test_vexa_innate_drains_intelligence_from_heroes_only() -> void:
	var w: World = _world()
	var v: Entity = _vexa(w)
	var foe: Entity = _foe(w, v.position + _dir() * 400.0)
	var creep: Entity = _foe(w, v.position - _dir() * 400.0, Entity.Kind.LANE_CREEP)
	var my_int: float = v.stats.get_stat(StatId.Id.INTELLIGENCE)
	var foe_int: float = foe.stats.get_stat(StatId.Id.INTELLIGENCE)
	w.submit(Command.attack(v.id, foe.id))
	var hits: int = 0
	while hits < 3:
		w.step()
		for ev: GameEvent in w.events:
			hits += int(ev.type == &"attack_landed" and ev.source_id == v.id)
	w.submit(Command.stop(v.id))
	w.step()
	assert_near(v.stats.get_stat(StatId.Id.INTELLIGENCE), my_int + 3.0, EPS, "bậc 1: +1 mỗi đòn, mỗi đòn một bản riêng")
	assert_near(foe.stats.get_stat(StatId.Id.INTELLIGENCE), foe_int - 3.0, EPS)
	var basic: DispelAction = DispelAction.new()
	basic.target = ActionDef.Target.SELF
	basic.level = EffectDef.Dispel.STRONG
	ActionRunner.run(w, [basic], ExprContext.make(foe, foe), foe.id)
	w.step()
	assert_near(foe.stats.get_stat(StatId.Id.INTELLIGENCE), foe_int - 3.0, EPS, "không bị thanh tẩy")
	w.submit(Command.attack(v.id, creep.id))
	_steps(w, 90)
	assert_near(v.stats.get_stat(StatId.Id.INTELLIGENCE), my_int + 3.0, EPS, "đánh lính không hút")
	_steps(w, 20 * 30)
	assert_near(v.stats.get_stat(StatId.Id.INTELLIGENCE), my_int, EPS, "hết 20 s thì trả lại")
	assert_near(foe.stats.get_stat(StatId.Id.INTELLIGENCE), foe_int, EPS)


func test_vexa_q_hex_by_rank() -> void:
	var w: World = _world()
	var v: Entity = _vexa(w, [3, 0, 0])
	var foe: Entity = _foe(w, v.position + _dir() * 400.0)
	w.submit(Command.cast(v.id, Slot.Q, foe.id))
	_steps(w, 2)
	assert_true(Rules.has_state(foe, UnitState.Id.HEXED))
	var hex: EffectInstance = _has(foe, &"vexa_frog")
	assert_eq(hex.end_tick - hex.start_tick, 75, "cấp 3: 2.5 s")
	assert_false(Rules.can_attack(foe))
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), w.balance.hex_move_speed, EPS)


func test_vexa_w_rect_damage_and_push_away() -> void:
	var w: World = _world()
	var v: Entity = _vexa(w, [0, 2, 0])
	var near: Entity = _foe(w, v.position + _dir() * 300.0)
	var edge: Entity = _foe(w, v.position + _dir() * 500.0 + _dir().orthogonal() * (125.0 + 20.0))
	var wide: Entity = _foe(w, v.position + _dir() * 500.0 + _dir().orthogonal() * (125.0 + 60.0))
	var tower: Entity = _foe(w, v.position + _dir() * 150.0 + _dir().orthogonal() * 80.0, Entity.Kind.TOWER)
	var start: Vector2 = near.position
	w.submit(Command.cast(v.id, Slot.W, -1, Vector2.INF, _dir()))
	assert_near(_taken(w, near, 14), _magic(w, near, 100.0), 0.01, "cấp 2: 100 phép")
	assert_true(edge.health < edge.stats.get_stat(StatId.Id.MAX_HP), "mép thân chạm vùng rộng 250 thì trúng")
	assert_near(wide.health, wide.stats.get_stat(StatId.Id.MAX_HP), EPS, "ngoài bề rộng không trúng")
	assert_near(tower.health, 100000.0, EPS, "không trúng công trình")
	assert_near(near.position.distance_to(start), 300.0, 2.0, "bị đẩy 300")
	assert_true(near.position.distance_to(v.position) > start.distance_to(v.position), "ra xa Vexa")


func test_vexa_r_purges_through_bkb_damage_per_buff_then_slow() -> void:
	var w: World = _world()
	var v: Entity = _vexa(w, [0, 0, 1])
	var foe: Entity = _foe(w, v.position + _dir() * 500.0)
	var haste: EffectDef = EffectDef.new()
	haste.id = &"test_haste"
	haste.tags = [&"buff"]
	var guard: EffectDef = EffectDef.new()
	guard.id = &"test_guard"
	guard.tags = [&"buff"]
	Effects.apply(w, foe, haste, foe, {}, "10")
	Effects.apply(w, foe, guard, foe, {}, "10")
	Effects.apply(w, foe, _lib.effects[&"magic_immune"], foe, {}, "10")
	var speed: float = foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(v.id, Slot.R, foe.id))
	_steps(w, 2)
	assert_true(_has(foe, &"test_haste") == null and _has(foe, &"test_guard") == null, "tước hiệu ứng có lợi, kể cả đang miễn phép")
	assert_true(_has(foe, &"magic_immune") != null, "miễn phép (không thanh tẩy được) không bị tước")
	assert_near(foe.stats.get_stat(StatId.Id.MAX_HP) - foe.health, 2 * _magic(w, foe, 80.0, true), 1.0, "80 phép mỗi hiệu ứng bị tước, xuyên miễn phép")
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed * 0.5, 1.0, "chậm 50%")
	var slow: EffectInstance = _has(foe, &"vexa_purge_slow")
	assert_eq(slow.end_tick - slow.start_tick, 90, "3 s")


func test_vexa_q_ii_hexed_takes_more_damage() -> void:
	var w: World = _world()
	var v: Entity = _vexa20(w, Slot.Q)
	var foe: Entity = _foe(w, v.position + _dir() * 400.0)
	w.submit(Command.cast(v.id, Slot.Q, foe.id))
	_steps(w, 2)
	assert_near(foe.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.2, EPS, "ếch nhận thêm 20%")


func test_vexa_w_ii_wider_stronger_further() -> void:
	var w: World = _world()
	var v: Entity = _vexa20(w, Slot.W)
	var near: Entity = _foe(w, v.position + _dir() * 300.0)
	var edge: Entity = _foe(w, v.position + _dir() * 500.0 + _dir().orthogonal() * (175.0 + 20.0))
	var start: Vector2 = near.position
	w.submit(Command.cast(v.id, Slot.W, -1, Vector2.INF, _dir()))
	assert_near(_taken(w, near, 20), _magic(w, near, 320.0), 0.01, "cấp 5 + 100")
	assert_true(edge.health < edge.stats.get_stat(StatId.Id.MAX_HP), "rộng 350")
	assert_near(near.position.distance_to(start), 450.0, 3.0, "đẩy 450")


func test_vexa_r_ii_root_instead_of_slow_and_shorter_cooldown() -> void:
	var w: World = _world()
	var v: Entity = _vexa20(w, Slot.R)
	var foe: Entity = _foe(w, v.position + _dir() * 500.0)
	var speed: float = foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(v.id, Slot.R, foe.id))
	_steps(w, 2)
	assert_true(Rules.has_state(foe, UnitState.Id.ROOTED), "trói")
	var root: EffectInstance = _has(foe, &"root")
	assert_eq(root.end_tick - root.start_tick, 60, "2 s")
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed, 1.0, "không làm chậm")
	var r: AbilityInstance = Abilities.of(v, Slot.R)
	assert_near(Abilities.value(v, r, &"cooldown"), 30.0, EPS, "50 − 20")
