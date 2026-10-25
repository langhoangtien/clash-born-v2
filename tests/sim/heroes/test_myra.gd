extends TestCase
## M4.4: Myra đúng bảng thiết kế (CONTENT.md), nội tại Nhịp Phép, Q/W/R và ba talent.

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
	var w: World = World.new(seed_value, balance_without_spell_amp(BALANCE_PATH))
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _lane_dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _myra(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var m: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, m, Abilities.of(m, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	m.mana = 5000.0
	return m


## Myra cấp 20, Q/W/R tối đa.
func _myra20(w: World) -> Entity:
	var m: Entity = _myra(w)
	Progression.add_xp(w, m, 100000.0)
	m.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(m, slot)
		Abilities.set_rank(w, m, a, a.def.expected_ranks())
	m.mana = 5000.0
	return m


func _dummy(w: World, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = 1
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


func _values(slot: int) -> Dictionary:
	return (_lib.heroes[&"myra"].abilities()[slot] as AbilityDef).values


func _check_values(v: PackedFloat32Array, expected: Array) -> void:
	assert_eq(v.size(), expected.size())
	for i: int in range(mini(v.size(), expected.size())):
		assert_near(v[i], expected[i], 0.0001)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _stacks(m: Entity) -> int:
	for inst: EffectInstance in m.effects:
		if inst.def.id == &"myra_rhythm_stack":
			return inst.stacks
	return 0


func _effect_ticks(e: Entity, state: UnitState.Id) -> int:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(state):
			return inst.end_tick - inst.start_tick
	return -1


func _lost(w: World, e: Entity, amount: float) -> float:
	return amount * Rules.damage_factor(w, e, MAGIC)


func _choose(w: World, m: Entity, slot: int) -> void:
	w.submit(Command.choose_talent(m.id, slot))
	w.step()


func test_myra_data_matches_design_tables() -> void:
	_world()
	_check_values(_values(Slot.INNATE)[&"attack_speed_per_stack"], [0.05, 0.06, 0.07, 0.08, 0.09, 0.10])
	var q: Dictionary = _values(Slot.Q)
	_check_values(q[&"damage"], [90.0, 140.0, 190.0, 240.0, 290.0])
	_check_values(q[&"slow"], [0.3, 0.3, 0.3, 0.3, 0.3])
	_check_values(q[&"slow_duration"], [1.5, 1.75, 2.0, 2.25, 2.5])
	_check_values(q[&"cooldown"], [8.0, 7.5, 7.0, 6.5, 6.0])
	_check_values(q[&"mana"], [80.0, 90.0, 100.0, 110.0, 120.0])
	var wv: Dictionary = _values(Slot.W)
	_check_values(wv[&"damage"], [40.0, 80.0, 120.0, 160.0, 200.0])  # D-162
	_check_values(wv[&"root_duration"], [1.0, 1.25, 1.5, 1.75, 2.0])
	_check_values(wv[&"cooldown"], [16.0, 15.0, 14.0, 13.0, 12.0])
	_check_values(wv[&"mana"], [100.0, 110.0, 120.0, 130.0, 140.0])
	_check_values(wv[&"cast_range"], [800.0, 800.0, 800.0, 800.0, 800.0])
	_check_values(wv[&"radius"], [280.0, 280.0, 280.0, 280.0, 280.0])
	_check_values(wv[&"delay"], [0.8, 0.8, 0.8, 0.8, 0.8])
	var r: Dictionary = _values(Slot.R)
	_check_values(r[&"damage"], [250.0, 375.0, 500.0])
	_check_values(r[&"silence_duration"], [2.0, 2.5, 3.0])
	_check_values(r[&"cooldown"], [80.0, 70.0, 60.0])
	_check_values(r[&"mana"], [150.0, 200.0, 250.0])
	_check_values(r[&"cast_range"], [900.0, 900.0, 900.0])
	_check_values(r[&"radius"], [400.0, 400.0, 400.0])
	_check_values(r[&"delay"], [1.0, 1.0, 1.0])
	assert_near(_lib.heroes[&"myra"].stats.attack_range, 550.0, EPS)


## D-162: tối đa 15 tầng (trước 8).
func test_myra_innate_stacks_on_same_target_up_to_15() -> void:
	var w: World = _world()
	var m: Entity = _myra(w)
	var foe: Entity = _dummy(w, m.position + _lane_dir() * 400.0)
	var speed: float = m.stats.get_stat(StatId.Id.ATTACK_SPEED)
	w.submit(Command.attack(m.id, foe.id))
	var hits: int = 0
	var most: int = 0
	for i: int in range(30 * 25):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"attack_landed" and ev.source_id == m.id:
				hits += 1
				assert_eq(_stacks(m), mini(hits, 15), "mỗi đòn trúng thêm 1 tầng")
		most = maxi(most, _stacks(m))
	assert_true(hits > 16)
	assert_eq(most, 15, "tối đa 15 tầng")
	assert_near(m.stats.get_stat(StatId.Id.ATTACK_SPEED), speed + 15 * 0.05, EPS, "bậc 1: +5% mỗi tầng")


func test_myra_innate_changing_target_clears_stacks() -> void:
	var w: World = _world()
	var m: Entity = _myra(w)
	var a: Entity = _dummy(w, m.position + _lane_dir() * 400.0)
	var b: Entity = _dummy(w, m.position + _lane_dir().orthogonal() * 400.0)
	w.submit(Command.attack(m.id, a.id))
	while _stacks(m) < 3:
		w.step()
	while not w.projectiles.is_empty() or m.attack_phase == Entity.AttackPhase.WINDUP:
		w.step()
	assert_eq(_stacks(m), 3)
	w.submit(Command.attack(m.id, b.id))
	var changed: bool = false
	while m.attack_phase != Entity.AttackPhase.WINDUP or m.attack_target_id != b.id:
		w.step()
		changed = changed or w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"attack_target_changed" and ev.source_id == m.id and ev.target_id == b.id)
	assert_true(changed, "vung đòn vào mục tiêu khác thì phát attack_target_changed")
	assert_eq(_stacks(m), 0, "đổi mục tiêu thì mất hết tầng ngay lúc bắt đầu vung")
	while _stacks(m) == 0:
		w.step()
	assert_eq(_stacks(m), 1, "đòn trúng mục tiêu mới thì bắt đầu lại từ 1")


func test_myra_innate_stacks_expire_and_count_on_towers() -> void:
	var w: World = _world()
	var m: Entity = _myra(w)
	var tower: Entity = _dummy(w, m.position + _lane_dir() * 400.0, Entity.Kind.TOWER)
	w.submit(Command.attack(m.id, tower.id))
	while _stacks(m) < 2:
		w.step()
	assert_eq(_stacks(m), 2, "đánh trụ cũng cộng tầng")
	w.submit(Command.stop(m.id))
	_steps(w, 4 * 30 + 45)
	assert_eq(_stacks(m), 0, "4 s không đánh trúng thì hết")


func test_myra_q_first_enemy_damage_and_slow() -> void:
	var w: World = _world()
	var m: Entity = _myra(w, [3, 0, 0])
	var first: Entity = _dummy(w, m.position + _lane_dir() * 400.0)
	var behind: Entity = _dummy(w, m.position + _lane_dir() * 600.0)
	w.submit(Command.cast(m.id, Slot.Q, -1, Vector2.INF, _lane_dir()))
	_steps(w, 20)
	assert_near(first.health, 100000.0 - _lost(w, first, 190.0), EPS, "cấp 3: 190 phép")
	assert_near(behind.health, 100000.0, EPS, "dừng ở kẻ đầu tiên")
	assert_near(first.stats.get_stat(StatId.Id.MOVEMENT_SPEED), 300.0 * 0.7, 0.5, "chậm 30%")
	var slowed: EffectInstance = first.effects.filter(func(i: EffectInstance) -> bool: return i.def.id == &"myra_frost_slow")[0]
	assert_eq(slowed.end_tick - slowed.start_tick, 60, "cấp 3: chậm 2 s")


func test_myra_w_roots_after_delay() -> void:
	var w: World = _world()
	var m: Entity = _myra(w, [0, 2, 0])
	var spot: Vector2 = m.position + _lane_dir() * 600.0
	var inside: Entity = _dummy(w, spot + _lane_dir().orthogonal() * (280.0 + 20.0))
	var outside: Entity = _dummy(w, spot + _lane_dir().orthogonal() * -(280.0 + 30.0))
	w.submit(Command.cast(m.id, Slot.W, -1, spot))
	_steps(w, 24)
	assert_near(inside.health, 100000.0, EPS, "chưa tới 0.8 s")
	w.step()
	assert_near(inside.health, 100000.0 - _lost(w, inside, 80.0), EPS, "cấp 2: 80 phép (D-162)")
	assert_true(Rules.has_state(inside, UnitState.Id.ROOTED))
	assert_eq(_effect_ticks(inside, UnitState.Id.ROOTED), roundi(1.25 * 30))
	assert_near(outside.health, 100000.0, EPS)


func test_myra_r_silences_in_400_after_1s() -> void:
	var w: World = _world()
	var m: Entity = _myra(w, [0, 0, 2])
	var spot: Vector2 = m.position + _lane_dir() * 700.0
	var edge: Entity = _dummy(w, spot + _lane_dir().orthogonal() * (400.0 + 20.0))
	var out: Entity = _dummy(w, spot - _lane_dir().orthogonal() * (400.0 + 30.0))
	var creep: Entity = _dummy(w, spot, Entity.Kind.LANE_CREEP)
	var tower: Entity = _dummy(w, spot + _lane_dir() * 100.0, Entity.Kind.TOWER)
	w.submit(Command.cast(m.id, Slot.R, -1, spot))
	_steps(w, 30)
	assert_near(edge.health, 100000.0, EPS, "chưa tới 1 s")
	w.step()
	assert_near(edge.health, 100000.0 - _lost(w, edge, 375.0), EPS, "cấp 2: 375 phép")
	assert_eq(_effect_ticks(edge, UnitState.Id.SILENCED), roundi(2.5 * 30))
	assert_true(creep.health < 100000.0)
	assert_near(out.health + tower.health, 200000.0, EPS, "ngoài vùng và công trình không trúng")


func test_myra_q_ii_pierces() -> void:
	var w: World = _world()
	var m: Entity = _myra20(w)
	_choose(w, m, Slot.Q)
	var a: Entity = _dummy(w, m.position + _lane_dir() * 300.0)
	var b: Entity = _dummy(w, m.position + _lane_dir() * 700.0)
	w.submit(Command.cast(m.id, Slot.Q, -1, Vector2.INF, _lane_dir()))
	_steps(w, 25)
	assert_near(a.health, 100000.0 - _lost(w, a, 290.0), EPS)
	assert_near(b.health, 100000.0 - _lost(w, b, 290.0), EPS, "Tia Xuyên Băng: xuyên qua")


func test_myra_w_ii_faster_and_wider() -> void:
	var w: World = _world()
	var m: Entity = _myra20(w)
	_choose(w, m, Slot.W)
	var spot: Vector2 = m.position + _lane_dir() * 600.0
	var foe: Entity = _dummy(w, spot + _lane_dir().orthogonal() * (380.0 + 20.0))
	w.submit(Command.cast(m.id, Slot.W, -1, spot))
	_steps(w, 9)
	assert_near(foe.health, 100000.0, EPS)
	w.step()
	assert_true(Rules.has_state(foe, UnitState.Id.ROOTED), "Phong Ấn Tức Thì: 0.3 s, bán kính 380")


func test_myra_r_ii_leaves_burning_zone() -> void:
	var w: World = _world()
	var m: Entity = _myra20(w)
	_choose(w, m, Slot.R)
	var spot: Vector2 = m.position + _lane_dir() * 700.0
	var foe: Entity = _dummy(w, spot)
	w.submit(Command.cast(m.id, Slot.R, -1, spot))
	var hits: int = 0
	for i: int in range(7 * 30):
		w.step()
		for ev: GameEvent in w.events:
			hits += int(ev.type == &"damage_taken" and ev.target_id == foe.id)
	assert_eq(hits, 1 + 4, "sao băng rồi 4 lần cháy")
	assert_near(foe.health, 100000.0 - _lost(w, foe, 500.0 + 4 * 60.0), 0.05)
