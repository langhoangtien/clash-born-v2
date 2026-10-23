extends TestCase
## D-135: Duy Anh · Hiệp Sĩ — Bất Khuất (EFF-16), Xung Phong, Hoành Kiếm (ABL-20),
## Quyết Đấu (ABL-08b, DUL-01..08, ST-19).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Slot := AbilityDef.Slot

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
	return _map.world_size() * 0.5 + Vector2(276, 276)  # vùng trống ±650 × ±260


func _knight(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var k: Entity = UnitFactory.hero(w, _lib.heroes[&"duy_anh"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, k, Abilities.of(k, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	k.mana = 5000.0
	return k


func _foe(w: World, at: Vector2, hp: float = 5000.0) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 1, w.navigation(32.0).nearest_clear(at))
	e.stats.set_base(StatId.Id.MAX_HP, hp)
	e.stats.recompute()
	e.health = e.stats.get_stat(StatId.Id.MAX_HP)
	return e


func _taken(w: World, e: Entity, n: int) -> float:
	var sum: float = 0.0
	for i: int in range(n):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"damage_taken" and ev.target_id == e.id:
				sum += ev.amount
	return sum


## Hiệp sĩ cấp R `rank` tung Quyết Đấu lên `foe` và chờ tới khi bắt đầu.
func _duel(w: World, k: Entity, foe: Entity) -> void:
	w.submit(Command.cast(k.id, Slot.R, foe.id))
	for i: int in range(60):
		w.step()
		if k.duel != null:
			return


func _event(w: World, type: StringName) -> GameEvent:
	for ev: GameEvent in w.events:
		if ev.type == type:
			return ev
	return null


func test_EFF_16_innate_armor_follows_missing_hp() -> void:
	var w: World = _world()
	var k: Entity = _knight(w)
	w.step()
	var armor: float = k.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	k.health = k.stats.get_stat(StatId.Id.MAX_HP) * 0.5
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_ARMOR) - armor, 5 * 0.6, 0.01, "mất 50%: 5 nấc × 0.6")
	k.health = k.stats.get_stat(StatId.Id.MAX_HP) * 0.01
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_ARMOR) - armor, 9 * 0.6, 0.01, "tối đa 9 nấc")
	k.health = k.stats.get_stat(StatId.Id.MAX_HP)
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor, 0.01, "hồi đầy: hết giáp thêm")


func test_EFF_16_innate_ranks_by_hero_level() -> void:
	var inn: AbilityDef = _lib.heroes[&"duy_anh"].innate if _lib != null else null
	if inn == null:
		_world()
		inn = _lib.heroes[&"duy_anh"].innate
	var want: Array[float] = [0.6, 0.8, 1.0, 1.2, 1.4, 1.6]
	for i: int in range(6):
		assert_near(inn.values[&"armor_step"][i], want[i], 0.0001, "bậc %d" % (i + 1))


func test_D_135_charge_boosts_move_speed_for_5s() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [5, 0, 0])
	w.step()
	var ms: float = k.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(k.id, Slot.Q))
	for i: int in range(3):
		w.step()
	assert_near(k.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 1.5, 0.5, "+50% ở cấp 5")
	for i: int in range(30 * 5):
		w.step()
	assert_near(k.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms, 0.5, "hết 5 s")


func test_ABL_20_cleave_hits_cone_in_front_only() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 1, 0])
	k.facing = Vector2.RIGHT
	var front: Entity = _foe(w, k.position + Vector2(250, 0))
	var side: Entity = _foe(w, k.position + Vector2(100, -200))  # ~63°: trong quạt 150°
	var behind: Entity = _foe(w, k.position + Vector2(-250, 0))
	var far: Entity = _foe(w, k.position + Vector2(600, 0))
	w.step()
	var hp: Array[float] = [front.health, side.health, behind.health, far.health]
	w.submit(Command.cast(k.id, Slot.W, -1, Vector2.INF, Vector2.RIGHT))
	for i: int in range(10):
		w.step()
	assert_true(front.health < hp[0], "trước mặt trúng")
	assert_true(side.health < hp[1], "chếch 63° vẫn trong quạt 150°")
	assert_near(behind.health, hp[2], 0.01, "sau lưng không trúng")
	assert_near(far.health, hp[3], 0.01, "ngoài 350 không trúng")


func test_D_135_cleave_damage_base_plus_80_percent_attack() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 5, 0])
	k.facing = Vector2.RIGHT
	var foe: Entity = _foe(w, k.position + Vector2(200, 0))
	w.step()
	var raw: float = 300.0 + 0.8 * k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	raw *= 1.0 + k.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION)  # CMB-13
	var mult: float = DamageFormulas.armor_multiplier(foe.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), w.balance.armor_coefficient)
	w.submit(Command.cast(k.id, Slot.W, -1, Vector2.INF, Vector2.RIGHT))
	assert_near(_taken(w, foe, 10), raw * mult, 1.0, "300 + 0.8 × sát thương đánh, trước giáp")


func test_ABL_08b_duel_dash_stays_targetable() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(450, 0))
	w.step()
	w.submit(Command.cast(k.id, Slot.R, foe.id))
	var seen: bool = false
	for i: int in range(20):
		w.step()
		if k.dash != null:
			seen = true
			assert_false(Rules.has_state(k, UnitState.Id.UNTARGETABLE), "lướt Quyết Đấu vẫn bị nhắm")
	assert_true(seen, "có lướt")


func test_DUL_02_duel_starts_both_dueling_with_strike_and_haste() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	var speed: float = k.stats.get_stat(StatId.Id.ATTACK_SPEED)
	var hp: float = foe.health
	_duel(w, k, foe)
	assert_true(k.duel != null and foe.duel == k.duel, "cùng một Quyết Đấu")
	assert_true(_event(w, &"duel_started") != null)
	w.step()
	assert_true(Rules.has_state(k, UnitState.Id.DUELING) and Rules.has_state(foe, UnitState.Id.DUELING))
	assert_near(k.stats.get_stat(StatId.Id.ATTACK_SPEED) - speed, 0.6, 0.001, "+60 tốc đánh ở cấp 1")
	assert_true(hp - foe.health >= 150.0 * 0.5, "cú bổ 150 vật lý")


func test_ST_19_dueling_rejects_orders_and_forces_attack() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	w.submit(Command.move_to(foe.id, foe.position + Vector2(800, 0)))
	w.submit(Command.cast(k.id, Slot.Q))
	w.step()
	assert_eq(w.rejected_commands.size(), 2)
	for c: Command in w.rejected_commands:
		assert_eq(c.reject_reason, Command.Reject.IN_DUEL)
	assert_eq(foe.order.type, Order.Type.ATTACK)
	assert_eq(foe.order.target_id, k.id, "đối thủ bị ép đánh hiệp sĩ")
	assert_eq(k.order.target_id, foe.id)


func test_DUL_04_reflects_pre_armor_attack_damage() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	w.step()
	foe.health = 4000.0
	var r: DamageRequest = DamageRequest.attack(foe, k.id)
	r.raw = 100.0
	w.damage_requests.append(r)
	DamageSystem.resolve(w)
	var mult: float = DamageFormulas.armor_multiplier(foe.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), w.balance.armor_coefficient)
	assert_near(4000.0 - foe.health, 20.0 * mult, 0.01, "cấp 1 phản 20% của 100 trước giáp, giáp đối thủ áp")


func test_DUL_04_skill_damage_not_reflected() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	w.step()
	foe.health = 4000.0
	var r: DamageRequest = DamageRequest.new()
	r.source_id = foe.id
	r.target_id = k.id
	r.raw = 100.0
	w.damage_requests.append(r)
	DamageSystem.resolve(w)
	assert_near(foe.health, 4000.0, 0.01, "sát thương không phải đòn đánh: không phản")


func test_DUL_05_knight_dies_first_loses_no_reflect() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	w.step()
	var gold: int = foe.gold
	foe.health = 4000.0
	k.health = 10.0
	var r: DamageRequest = DamageRequest.attack(foe, k.id)
	r.raw = 500.0
	w.damage_requests.append(r)
	DamageSystem.resolve(w)
	assert_false(k.alive)
	assert_near(foe.health, 4000.0, 0.01, "hiệp sĩ chết: không phản")
	assert_near(k.duel_damage, -10.0, 0.001, "thua: −10")
	assert_near(foe.duel_damage, 10.0, 0.001, "đối thủ thắng: +10")
	assert_eq(foe.gold - gold, 150, "đối thủ thắng cũng nhận vàng (người chơi chốt)")
	assert_true(k.duel == null and foe.duel == null)


func test_DUL_05_reflect_kill_wins_and_rewards_once() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	w.step()
	var gold: int = k.gold
	var dmg: float = k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	foe.health = 1.0
	var r: DamageRequest = DamageRequest.attack(foe, k.id)
	r.raw = 100.0
	w.damage_requests.append(r)
	DamageSystem.resolve(w)
	assert_false(foe.alive, "chết vì phản")
	assert_near(k.duel_damage, 10.0, 0.001)
	assert_true(k.gold - gold >= 150, "+150 vàng (ngoài vàng hạ gục)")
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - dmg, 10.0, 0.01, "+10 sát thương vĩnh viễn")
	assert_false(Rules.has_state(k, UnitState.Id.DUELING), "gỡ trạng thái ngay")


func test_DUL_02_timeout_no_rewards() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0), 100000.0)
	k.stats.set_base(StatId.Id.MAX_HP, 100000.0)
	k.stats.recompute()
	k.health = 100000.0
	w.step()
	var speed: float = k.stats.get_stat(StatId.Id.ATTACK_SPEED)
	_duel(w, k, foe)
	for i: int in range(30 * 3 + 5):
		w.step()
	assert_true(k.duel == null, "hết 3 s")
	assert_near(k.duel_damage, 0.0, 0.001)
	assert_near(foe.duel_damage, 0.0, 0.001)
	assert_false(Rules.has_state(foe, UnitState.Id.DUELING))
	assert_near(k.stats.get_stat(StatId.Id.ATTACK_SPEED), speed, 0.001, "gỡ tốc đánh thêm")


func test_DUL_01_no_second_duel_for_dueling_unit() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 1])
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.step()
	_duel(w, k, foe)
	var first: DuelState = k.duel
	var k2: Entity = UnitFactory.hero(w, _lib.heroes[&"duy_anh"], 0, w.navigation(32.0).nearest_clear(foe.position + Vector2(0, 150)))
	assert_false(Duels.start(w, k2, foe, first.values), "đối thủ đang đấu: không bắt đầu")
	assert_true(foe.duel == first)


func test_DUL_07_duel_damage_survives_death_and_can_go_negative() -> void:
	var w: World = _world()
	var k: Entity = _knight(w)
	w.step()
	var dmg: float = k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	Duels.add_permanent(k, -20.0)
	Effects.remove_on_death(w, k)
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - dmg, -20.0, 0.01)
	Duels.add_permanent(k, -100000.0)
	w.step()
	assert_near(k.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), 0.0, 0.01, "tối thiểu 0")


func test_D_135_talent_r_magic_immune_during_duel() -> void:
	var w: World = _world()
	var k: Entity = _knight(w, [0, 0, 3])
	Progression.add_xp(w, k, 100000.0)
	k.mana = 5000.0
	var foe: Entity = _foe(w, k.position + Vector2(400, 0))
	w.submit(Command.choose_talent(k.id, Slot.R))
	w.step()
	_duel(w, k, foe)
	w.step()
	assert_true(Rules.has_state(k, UnitState.Id.MAGIC_IMMUNE), "talent R: miễn phép khi Quyết Đấu")
