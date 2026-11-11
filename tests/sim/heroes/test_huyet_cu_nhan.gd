extends TestCase
## D-347: Huyết Cự Nhân · Khổng Lồ (tank STR) — nội tại máu theo STR (STAT-06), Q Huyết Chấn (tự mất máu), W Phản Huyết
## (phản sát thương theo STR), R Đại Địa Chấn (vùng trễ 0,6 s có cảnh báo, choáng), talent.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot
const ID: StringName = &"huyet_cu_nhan"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(4, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-700, 700)


func _hero(w: World, ranks: Array[int] = [0, 0, 0, 0]) -> Entity:
	var h: Entity = UnitFactory.hero(w, _lib.heroes[ID], 0, w.navigation(36.0).nearest_clear(_center()))
	for i: int in range(4):
		if ranks[i] > 0:
			Abilities.set_rank(w, h, Abilities.of(h, [Slot.INNATE, Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	h.mana = 5000.0
	h.stats.recompute()
	return h


func _dummy(w: World, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO, team: int = 1) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 10)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 0)
	e.attack_point = 0.1
	e.stats.recompute()
	e.health = 100000.0
	return w.add_entity(e)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _stunned(e: Entity) -> bool:
	return e.effects.any(func(i: EffectInstance) -> bool: return i.def.states.has(UnitState.Id.STUNNED))


func test_D_347_huyet_innate_hp_per_strength_follows_level() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var hp0: float = h.stats.get_stat(StatId.Id.MAX_HP)
	Abilities.set_rank(w, h, Abilities.of(h, Slot.INNATE), 1)
	h.stats.recompute()
	var strength: float = h.stats.get_stat(StatId.Id.STRENGTH)
	assert_near(h.stats.get_stat(StatId.Id.MAX_HP) - hp0, 4.0 * strength, EPS, "bậc 1: +4 máu mỗi STR")
	Abilities.set_rank(w, h, Abilities.of(h, Slot.INNATE), 5)
	Progression.add_xp(w, h, 100000.0)
	w.step()
	var s20: float = h.stats.get_stat(StatId.Id.STRENGTH)
	assert_true(s20 > strength + 50.0, "cấp 20 STR tăng nhiều")
	var natural: float = h.stats.natural(StatId.Id.MAX_HP)
	assert_true(h.stats.get_stat(StatId.Id.MAX_HP) >= 11.0 * s20 + 1.0, "bậc 5: +11 máu mỗi STR theo STR hiện tại (STAT-06)")
	assert_true(natural > 0.0)


func test_D_347_huyet_q_damage_by_strength_and_self_damage() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, [0, 3, 0, 0])
	var dir: Vector2 = Vector2(1, -1).normalized()
	var near: Entity = _dummy(w, h.position + dir * 200.0)
	var far: Entity = _dummy(w, h.position + dir * 420.0)
	var tower: Entity = _dummy(w, h.position - dir * 150.0, Entity.Kind.TOWER)
	var hp: float = h.health
	var strength: float = h.stats.get_stat(StatId.Id.STRENGTH)
	w.submit(Command.cast(h.id, Slot.Q))
	_steps(w, 12)  # tung 0,3 s
	var amp: float = 1.0 + h.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION)  # CMB-13: chiêu nhân khuếch đại phép (INT)
	assert_near(100000.0 - near.health, (110.0 + 0.8 * strength) * amp, 1.0, "cấp 3: 110 + 0,8 × STR (giáp 0)")
	assert_near(far.health, 100000.0, EPS, "ngoài 325")
	assert_near(tower.health, 100000.0, EPS, "không trúng công trình")
	assert_near(hp - h.health, 50.0, 1.0, "tự mất 50 máu (thuần)")


func test_D_347_huyet_w_reflects_strength_on_each_hit_not_towers() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, [0, 0, 5, 0])
	var strength: float = h.stats.get_stat(StatId.Id.STRENGTH)
	var foe: Entity = _dummy(w, h.position + Vector2(60, 0))
	var tower: Entity = _dummy(w, h.position + Vector2(-60, 0), Entity.Kind.TOWER)
	for e: Entity in [foe, tower]:
		e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
		e.stats.recompute()
		w.submit(Command.attack(e.id, h.id))
	var hits: Dictionary = {foe.id: 0, tower.id: 0}
	for i: int in 30 * 5:
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"attack_landed" and ev.target_id == h.id and hits.has(ev.source_id):
				hits[ev.source_id] += 1
	assert_true(int(hits[foe.id]) >= 3, "kẻ địch đã đánh vài đòn")
	assert_near(100000.0 - foe.health, int(hits[foe.id]) * 0.25 * strength, 1.0, "mỗi đòn phản 25% STR (vật lý, giáp 0)")
	assert_near(tower.health, 100000.0, EPS, "trụ đánh không bị phản")


func test_D_347_huyet_r_delayed_stun_area() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, [0, 0, 0, 2])
	var dir: Vector2 = Vector2(0, -1)
	var inside: Entity = _dummy(w, h.position + dir * 500.0)
	var outside: Entity = _dummy(w, h.position + dir * 620.0)
	var strength: float = h.stats.get_stat(StatId.Id.STRENGTH)
	w.submit(Command.cast(h.id, Slot.R))
	_steps(w, 10)
	assert_near(inside.health, 100000.0, EPS, "chưa nổ trước 0,6 s (cảnh báo)")
	assert_false(_stunned(inside))
	_steps(w, 12)
	var amp: float = 1.0 + h.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION)  # CMB-13
	assert_near(100000.0 - inside.health, (250.0 + strength) * amp, 1.0, "cấp 2: 250 + 100% STR")
	assert_true(_stunned(inside), "choáng trong 550")
	assert_near(outside.health, 100000.0, EPS)
	assert_false(_stunned(outside))


func test_D_347_huyet_q_talent_removes_self_damage() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	Progression.add_xp(w, h, 100000.0)
	h.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(h, slot)
		Abilities.set_rank(w, h, a, a.def.expected_ranks())
	h.mana = 5000.0
	w.submit(Command.choose_talent(h.id, Slot.Q))
	w.step()
	var hp: float = h.health
	w.submit(Command.cast(h.id, Slot.Q))
	_steps(w, 12)
	assert_true(h.health >= hp - EPS, "talent Q II: không tự mất máu")
