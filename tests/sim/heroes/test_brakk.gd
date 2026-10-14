extends TestCase
## M3.7: Brakk đúng bảng thiết kế (CONTENT.md) và mỗi kỹ năng một kịch bản.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot

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
	return _map.world_size() * 0.5 + Vector2(-700, 700)


func _brakk(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var b: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, b, Abilities.of(b, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	return b


func _dummy(w: World, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO, team: int = 1) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 100)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	e.attack_point = 0.1
	return w.add_entity(e)


func _values(slot: int) -> Dictionary:
	var d: AbilityDef = _lib.heroes[&"brakk"].abilities()[slot]
	return d.values


func _check_values(v: PackedFloat32Array, expected: Array) -> void:
	assert_eq(v.size(), expected.size())
	for i: int in range(mini(v.size(), expected.size())):
		assert_near(v[i], expected[i], 0.0001)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _stun_ticks(e: Entity) -> int:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(UnitState.Id.STUNNED):
			return inst.end_tick - inst.start_tick
	return -1


func test_brakk_data_matches_design_tables() -> void:
	_world()
	var innate: Dictionary = _values(Slot.INNATE)
	_check_values(innate[&"chance"], [0.15, 0.17, 0.19, 0.21, 0.23, 0.25])
	_check_values(innate[&"bonus_damage"], [30.0, 40.0, 50.0, 60.0, 70.0, 80.0])
	_check_values(innate[&"stun_duration"], [0.5, 0.6, 0.7, 0.8, 0.9, 1.0])
	var q: Dictionary = _values(Slot.Q)
	_check_values(q[&"damage"], [70.0, 110.0, 150.0, 190.0, 230.0])
	_check_values(q[&"stun_duration"], [0.8, 1.0, 1.2, 1.4, 1.6])
	_check_values(q[&"cooldown"], [14.0, 13.0, 12.0, 11.0, 10.0])
	_check_values(q[&"mana"], [90.0, 95.0, 100.0, 105.0, 110.0])
	var w: Dictionary = _values(Slot.W)
	_check_values(w[&"shield"], [120.0, 180.0, 240.0, 300.0, 360.0])
	_check_values(w[&"cooldown"], [18.0, 17.0, 16.0, 15.0, 14.0])
	_check_values(w[&"mana"], [80.0, 85.0, 90.0, 95.0, 100.0])
	var r: Dictionary = _values(Slot.R)
	_check_values(r[&"duration"], [4.0, 5.0, 6.0])
	_check_values(r[&"heal_fraction"], [0.2, 0.3, 0.4])
	_check_values(r[&"move_bonus"], [0.2, 0.25, 0.3])
	_check_values(r[&"cooldown"], [90.0, 80.0, 70.0])
	_check_values(r[&"mana"], [150.0, 175.0, 200.0])
	assert_near(_lib.heroes[&"brakk"].stats.attack_range, 150.0, EPS)


func test_brakk_innate_never_bashes_structures() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w)
	Abilities.set_rank(w, b, Abilities.of(b, Slot.INNATE), 6)
	var tower: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 90.0, Entity.Kind.TOWER)
	tower.stats.set_base(StatId.Id.ATTACK_RANGE, 0)
	tower.stats.recompute()
	w.submit(Command.attack(b.id, tower.id))
	var stuns: int = 0
	var amounts: Dictionary = {}
	for i: int in range(30 * 60):
		w.step()
		for ev: GameEvent in w.events:
			stuns += int(ev.type == &"effect_applied" and ev.target_id == tower.id)
			if ev.type == &"damage_taken" and ev.target_id == tower.id:
				amounts[snappedf(ev.amount, 0.01)] = true
	assert_eq(stuns, 0)
	assert_eq(amounts.size(), 1, "mọi đòn lên trụ cùng một lượng, không có sát thương thêm")


func test_brakk_innate_rate_by_rank() -> void:
	var w: World = _world(8)
	var b: Entity = _brakk(w)
	Abilities.set_rank(w, b, Abilities.of(b, Slot.INNATE), 6)
	var foe: Entity = _dummy(w, b.position + Vector2(1, -1).normalized() * 90.0)
	foe.stats.set_base(StatId.Id.ATTACK_RANGE, 0)
	foe.stats.recompute()
	w.submit(Command.attack(b.id, foe.id))
	var hits: int = 0
	var bashes: int = 0
	for i: int in range(30 * 600):
		w.step()
		for ev: GameEvent in w.events:
			hits += int(ev.type == &"attack_landed" and ev.source_id == b.id)
			bashes += int(ev.type == &"effect_applied" and ev.target_id == foe.id)
	assert_near(float(bashes) / hits, 0.25, 0.04, "bậc 6: 25%% (%d/%d)" % [bashes, hits])


func test_brakk_q_hits_enemies_in_300_not_towers_stun_by_rank() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, [3, 0, 0])
	var dir: Vector2 = Vector2(1, -1).normalized()
	var edge: Entity = _dummy(w, b.position + dir * (300.0 + 20.0))
	var out: Entity = _dummy(w, b.position + dir * (300.0 + 40.0))
	var creep: Entity = _dummy(w, b.position - dir * 150.0, Entity.Kind.LANE_CREEP)
	var tower: Entity = _dummy(w, b.position + dir.orthogonal() * 150.0, Entity.Kind.TOWER)
	for e: Entity in [edge, out, creep, tower]:
		e.stats.set_base(StatId.Id.ATTACK_RANGE, 0)
		e.stats.recompute()
	w.submit(Command.cast(b.id, Slot.Q))
	_steps(w, 11)
	assert_true(edge.health < 100000.0, "mép thân trong 300 thì trúng")
	assert_near(out.health, 100000.0, EPS)
	assert_true(creep.health < 100000.0, "trúng cả lính")
	assert_near(tower.health, 100000.0, EPS, "không trúng công trình")
	assert_eq(_stun_ticks(creep), 36, "cấp 3: choáng 1.2 s")


func test_brakk_w_shield_refresh_and_expire() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, [0, 2, 0])
	b.mana = 1000.0
	w.submit(Command.cast(b.id, Slot.W))
	_steps(w, 2)
	var shield: EffectInstance = b.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == &"brakk_iron_shield")[0]
	assert_near(shield.absorb_left, 180.0, EPS)
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = b.id
	r.raw = 100.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	var hp: float = b.health
	w.step()
	assert_near(b.health, minf(hp + b.stats.get_stat(StatId.Id.HP_REGEN) / 30.0, b.stats.get_stat(StatId.Id.MAX_HP)), 0.05, "khiên hút hết")
	assert_near(shield.absorb_left, 80.0, EPS)
	Abilities.of(b, Slot.W).ready_tick = 0
	w.submit(Command.cast(b.id, Slot.W))
	_steps(w, 2)
	assert_eq(b.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == &"brakk_iron_shield").size(), 1, "không chồng hai khiên")
	assert_near(shield.absorb_left, 180.0, EPS, "dùng lại thì làm mới khiên")
	_steps(w, 6 * 30)
	assert_eq(b.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == &"brakk_iron_shield").size(), 0, "hết 6 s thì mất")


func test_brakk_r_ghost_heal_and_speed() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, [0, 0, 1])
	b.mana = 1000.0
	var max_hp: float = b.stats.get_stat(StatId.Id.MAX_HP)
	b.health = max_hp * 0.4
	var speed: float = b.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(b.id, Slot.R))
	_steps(w, 2)
	assert_true(Rules.has_state(b, UnitState.Id.GHOST))
	assert_false(Rules.can_attack(b), "GHOST không đánh thường")
	assert_near(b.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed * 1.2, 0.5, "+20% tốc chạy")
	assert_near(Rules.damage_factor(w, b, DamageFormulas.DamageType.PHYSICAL), 0.0, EPS)
	assert_near(Rules.damage_factor(w, b, DamageFormulas.DamageType.MAGIC), 1.4, EPS)
	_steps(w, 4 * 30)
	assert_false(Rules.has_state(b, UnitState.Id.GHOST), "hết 4 s")
	var regen: float = b.stats.get_stat(StatId.Id.HP_REGEN)
	assert_near(b.health, max_hp * (0.4 + 0.2) + regen * (4 * 30 + 2) / 30.0, 2.0, "hồi đủ 20% máu trong thời gian GHOST")
	assert_near(b.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed, 0.5)
