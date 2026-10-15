extends TestCase
## M5.4: Noctis đúng bảng thiết kế (CONTENT.md), nội tại chí mạng, Q lướt, W tàng hình +
## phục kích, R dấu tử thần, ba talent.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot
const PHYS := DamageFormulas.DamageType.PHYSICAL

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(seed_value: int = 4) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(seed_value, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _noctis(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var n: Entity = UnitFactory.hero(w, _lib.heroes[&"noctis"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, n, Abilities.of(n, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	n.mana = 5000.0
	return n


func _noctis20(w: World, talent: int) -> Entity:
	var n: Entity = _noctis(w)
	Progression.add_xp(w, n, 100000.0)
	n.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(n, slot)
		Abilities.set_rank(w, n, a, a.def.expected_ranks())
	n.mana = 5000.0
	w.submit(Command.choose_talent(n.id, talent))
	w.step()
	return n


func _dummy(w: World, at: Vector2, hp: float = 100000.0, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = 1
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, hp)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.VISION_RANGE, 800)
	return w.add_entity(e)


func _values(slot: int) -> Dictionary:
	return (_lib.heroes[&"noctis"].abilities()[slot] as AbilityDef).values


func _check_values(v: PackedFloat32Array, expected: Array) -> void:
	assert_eq(v.size(), expected.size())
	for i: int in range(mini(v.size(), expected.size())):
		assert_near(v[i], expected[i], 0.0001)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _has(e: Entity, id: StringName) -> EffectInstance:
	for inst: EffectInstance in e.effects:
		if inst.def.id == id:
			return inst
	return null


func test_noctis_data_matches_design_tables() -> void:
	_world()
	var innate: Dictionary = _values(Slot.INNATE)
	_check_values(innate[&"crit_chance"], [0.10, 0.12, 0.14, 0.16, 0.18, 0.20])
	_check_values(innate[&"crit_multiplier"], [1.6, 1.8, 2.0, 2.2, 2.4, 2.6])
	var q: Dictionary = _values(Slot.Q)
	_check_values(q[&"damage"], [80.0, 120.0, 160.0, 200.0, 240.0])
	_check_values(q[&"cooldown"], [12.0, 11.0, 10.0, 9.0, 8.0])
	_check_values(q[&"mana"], [70.0, 75.0, 80.0, 85.0, 90.0])
	_check_values(q[&"cast_range"], [600.0, 600.0, 600.0, 600.0, 600.0])
	var wv: Dictionary = _values(Slot.W)
	_check_values(wv[&"duration"], [6.0, 7.0, 8.0, 9.0, 10.0])
	_check_values(wv[&"move_bonus"], [0.10, 0.15, 0.20, 0.25, 0.30])
	_check_values(wv[&"ambush_damage"], [60.0, 90.0, 120.0, 150.0, 180.0])
	_check_values(wv[&"disarm_duration"], [1.0, 1.2, 1.4, 1.6, 1.8])
	_check_values(wv[&"cooldown"], [20.0, 19.0, 18.0, 17.0, 16.0])
	_check_values(wv[&"mana"], [80.0, 80.0, 80.0, 80.0, 80.0])
	_check_values(wv[&"fade_in"], [0.6, 0.6, 0.6, 0.6, 0.6])
	var r: Dictionary = _values(Slot.R)
	_check_values(r[&"amplify"], [0.15, 0.22, 0.30])
	_check_values(r[&"duration"], [6.0, 6.0, 6.0])
	_check_values(r[&"cooldown"], [60.0, 50.0, 40.0])
	_check_values(r[&"mana"], [100.0, 125.0, 150.0])
	_check_values(r[&"cast_range"], [500.0, 500.0, 500.0])
	assert_near(_lib.heroes[&"noctis"].stats.attack_range, 150.0, EPS)


func test_noctis_innate_crit_rate_and_multiplier() -> void:
	var w: World = _world(11)
	var n: Entity = _noctis(w)
	Abilities.set_rank(w, n, Abilities.of(n, Slot.INNATE), 6)
	var foe: Entity = _dummy(w, n.position + _dir() * 90.0, 10000000.0)
	w.submit(Command.attack(n.id, foe.id))
	var hits: int = 0
	var crits: int = 0
	var plain: float = -1.0
	var big: float = -1.0
	for i: int in range(30 * 400):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"attack_landed" and ev.source_id == n.id:
				hits += 1
				if ev.reason == &"crit":
					crits += 1
					big = ev.amount
				else:
					plain = ev.amount
	assert_near(float(crits) / hits, 0.20, 0.04, "bậc 6: 20%% (%d/%d)" % [crits, hits])
	assert_near(big / plain, 2.6, 0.01, "hệ số 2.6×")


func test_noctis_q_dashes_and_hits_physical() -> void:
	var w: World = _world()
	var n: Entity = _noctis(w, [3, 0, 0])
	var foe: Entity = _dummy(w, n.position + _dir() * 500.0)
	w.step()
	w.submit(Command.cast(n.id, Slot.Q, foe.id))
	_steps(w, 2)
	assert_true(n.dash != null and Rules.has_state(n, UnitState.Id.UNTARGETABLE), "đang lướt: không thể bị nhắm")
	_steps(w, 12)
	assert_true(n.dash == null)
	assert_near(foe.health, 100000.0 - 160.0 * Rules.damage_factor(w, foe, PHYS), 0.05, "cấp 3: 160 vật lý")


func test_noctis_w_invisible_after_fade_then_ambush_once() -> void:
	var w: World = _world()
	var n: Entity = _noctis(w, [0, 2, 0])
	var foe: Entity = _dummy(w, n.position + _dir() * 400.0)
	var speed: float = n.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.step()
	w.submit(Command.cast(n.id, Slot.W))
	_steps(w, 2)
	assert_near(n.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed * 1.15, 0.5, "cấp 2: +15% tốc chạy")
	assert_true(Rules.is_visible(1, n), "đang hiện dần thì địch còn thấy")
	_steps(w, 18)
	assert_false(Rules.is_visible(1, n), "sau 0.6 s thì tàng hình")
	w.submit(Command.attack(n.id, foe.id))
	var landed: Array[float] = []
	for i: int in range(120):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"damage_taken" and ev.target_id == foe.id:
				landed.append(ev.amount)
		if i == 30:
			assert_true(Rules.is_visible(1, n), "đánh thì hiện hình")
			assert_true(Rules.has_state(foe, UnitState.Id.DISARMED), "trúng đòn phục kích: cấm đánh")
			var d: EffectInstance = _has(foe, &"disarm")
			assert_eq(d.end_tick - d.start_tick, 36, "cấp 2: 1.2 s")
	var ambush: float = 90.0 * Rules.damage_factor(w, foe, PHYS)
	assert_eq(landed.filter(func(a: float) -> bool: return absf(a - ambush) < 0.05).size(), 1, "phục kích chỉ một lần")
	assert_true(_has(n, &"ambush_ready") == null)


func test_noctis_w_casting_breaks_veil_and_ambush() -> void:
	var w: World = _world()
	var n: Entity = _noctis(w, [1, 1, 0])
	var foe: Entity = _dummy(w, n.position + _dir() * 500.0)
	w.step()
	w.submit(Command.cast(n.id, Slot.W))
	_steps(w, 25)
	w.submit(Command.cast(n.id, Slot.Q, foe.id))
	_steps(w, 3)
	assert_true(_has(n, &"shadow_veil") == null, "dùng chiêu thì hiện hình")
	assert_true(_has(n, &"ambush_ready") == null, "và mất đòn phục kích")


func test_noctis_r_reveals_anywhere_and_amplifies() -> void:
	var w: World = _world()
	var n: Entity = _noctis(w, [0, 0, 2])
	var foe: Entity = _dummy(w, n.position + _dir() * 400.0)
	w.step()
	w.submit(Command.cast(n.id, Slot.R, foe.id))
	_steps(w, 2)
	assert_near(foe.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.22, EPS, "cấp 2: nhận thêm 22%")
	Effects.apply(w, foe, _lib.effects[&"shadow_veil"], foe, {&"fade_in": 0.0, &"move_bonus": 0.0}, "10")
	foe.position = n.position + _dir() * 4000.0
	_steps(w, 2)
	assert_true(Rules.is_visible(0, foe), "lộ diện: thấy ở mọi nơi kể cả tàng hình")
	_steps(w, 6 * 30)
	assert_false(Rules.is_visible(0, foe), "hết 6 s")
	assert_near(foe.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.0, EPS)


func test_noctis_q_ii_kill_within_window_resets_q() -> void:
	for late: bool in [false, true]:
		var w: World = _world()
		var n: Entity = _noctis20(w, Slot.Q)
		var foe: Entity = _dummy(w, n.position + _dir() * 300.0, 2000.0)
		w.submit(Command.cast(n.id, Slot.Q, foe.id))
		_steps(w, 2)
		var q: AbilityInstance = Abilities.of(n, Slot.Q)
		assert_true(q.ready_tick > w.tick, "Q đang hồi")
		_steps(w, 50 if late else 8)
		var r: DamageRequest = DamageRequest.new()
		r.source_id = n.id
		r.target_id = foe.id
		r.raw = 5000.0
		r.damage_type = DamageFormulas.DamageType.PURE
		w.damage_requests.append(r)
		_steps(w, 2)
		assert_false(foe.alive)
		if late:
			assert_true(q.ready_tick > w.tick, "hạ sau 1.3 s: không hồi lại")
		else:
			assert_true(q.ready_tick <= w.tick, "hạ trong 1.3 s: Q sẵn sàng ngay")


func test_noctis_w_ii_no_fade_and_regen() -> void:
	var w: World = _world()
	var n: Entity = _noctis20(w, Slot.W)
	_dummy(w, n.position + _dir() * 400.0)
	var regen: float = n.stats.get_stat(StatId.Id.HP_REGEN)
	w.submit(Command.cast(n.id, Slot.W))
	_steps(w, 2)
	assert_false(Rules.is_visible(1, n), "fade in 0 s")
	assert_near(n.stats.get_stat(StatId.Id.HP_REGEN), regen + n.stats.get_stat(StatId.Id.MAX_HP) * 0.03, 0.05, "hồi 3% máu tối đa mỗi giây")


func test_noctis_r_ii_stronger_mark_and_silence() -> void:
	var w: World = _world()
	var n: Entity = _noctis20(w, Slot.R)
	var foe: Entity = _dummy(w, n.position + _dir() * 400.0)
	w.submit(Command.cast(n.id, Slot.R, foe.id))
	_steps(w, 2)
	assert_near(foe.stats.get_stat(StatId.Id.DAMAGE_TAKEN_MULTIPLIER), 1.40, EPS, "30% + 10%")
	assert_true(Rules.has_state(foe, UnitState.Id.SILENCED))
	var s: EffectInstance = _has(foe, &"silence")
	assert_eq(s.end_tick - s.start_tick, 45, "câm 1.5 s")
