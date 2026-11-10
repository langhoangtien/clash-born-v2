extends TestCase
## M3.5: lên cấp, XP (ECO-03), điểm kỹ năng (ABL-04), nội tại tự lên (ABL-11), vàng hạ hero /
## mất vàng khi chết (ECO-05, ECO-07b), bỏ deny (D-60).

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
	var w: World = World.new(5, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-700, 700)


func _brakk(w: World, team: int, at: Vector2) -> Entity:
	var h: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))
	h.gold = 0  # đo vàng kiếm được, bỏ vàng khởi đầu (D-106)
	return h


func _kill(w: World, source_id: int, victim: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source_id
	r.target_id = victim.id
	r.raw = 1.0e9
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()


func _rejected(w: World, c: Command) -> Command.Reject:
	w.submit(c)
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


func test_ABL_04_xp_table_and_level_up() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	assert_eq(Progression.xp_to_next(w, 1), 120)
	assert_eq(Progression.xp_to_next(w, 19), 120 + 30 * 18)
	var total: int = 0
	for level: int in range(1, 20):
		total += Progression.xp_to_next(w, level)
	assert_eq(total, 7410, "tổng XP tới cấp 20")
	var hp: float = b.health
	var max_hp: float = b.stats.get_stat(StatId.Id.MAX_HP)
	Progression.add_xp(w, b, 130.0)
	assert_eq(b.stats.level(), 2)
	assert_near(b.xp, 10.0, EPS, "XP thừa giữ lại")
	assert_eq(b.skill_points, 2, "cấp 1 có sẵn 1 điểm + 1 khi lên cấp 2")
	var gained: float = b.stats.get_stat(StatId.Id.MAX_HP) - max_hp
	assert_true(gained > 0.0, "lên cấp tăng máu tối đa qua Sức mạnh")
	assert_near(b.health, hp + gained, EPS, "máu hiện tại cộng đúng phần tăng")
	Progression.add_xp(w, b, 100000.0)
	assert_eq(b.stats.level(), 20, "tối đa cấp 20")
	assert_near(b.xp, 0.0, EPS)


## D-301 (người chơi): nội tại nâng bằng điểm như Q/W — bậc n khi hero cấp 2n − 1, tối đa 5; chưa cộng thì chưa có
## tác dụng (trước: tự lên 6 bậc theo cấp hero).
func test_ABL_11_innate_leveled_with_points_no_level_requirement() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	var innate: AbilityInstance = Abilities.of(b, Slot.INNATE)
	assert_eq(innate.rank, 0, "mới vào trận: chưa học nội tại")
	assert_eq(b.effects.size(), 0, "chưa có bị động")
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.INNATE)), Command.Reject.NONE, "cấp 1: cộng bậc 1")
	assert_eq(innate.rank, 1)
	assert_near(b.effects[0].values[&"chance"], 0.17, EPS, "bậc 1 mới = bậc 2 cũ (bỏ bậc đầu)")
	b.skill_points = 10
	for i: int in 4:
		assert_eq(_rejected(w, Command.level_up(b.id, Slot.INNATE)), Command.Reject.NONE)
	assert_eq(innate.rank, 5)
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.INNATE)), Command.Reject.CANNOT_LEVEL, "tối đa bậc 5")
	assert_eq(b.stats.level(), 1, "D-318: hero cấp 1 vẫn nâng nội tại tới bậc 5 nếu có điểm")
	assert_near(b.effects[0].values[&"chance"], 0.25, EPS, "bậc 5 = bậc 6 cũ")
	assert_eq(b.effects.size(), 1, "không chồng hai bản bị động")


func test_ABL_04_skill_rank_rules() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.R)), Command.Reject.CANNOT_LEVEL, "R cần cấp 6")
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.Q)), Command.Reject.NONE)
	assert_eq(Abilities.of(b, Slot.Q).rank, 1)
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.Q)), Command.Reject.NO_SKILL_POINT)
	Progression.add_xp(w, b, Progression.xp_to_next(w, 1))
	assert_eq(_rejected(w, Command.level_up(b.id, Command.ATTRIBUTES)), Command.Reject.NONE)
	assert_eq(b.attribute_bonus_count, 1)
	assert_eq(b.skill_points, 0)


## D-318 (người chơi): Q / W / nội tại không cần cấp hero — có điểm là nâng; cấp 5 (5 điểm) max được một chiêu.
## R vẫn cần cấp 6 / 11 / 16.
func test_ABL_04_q_w_no_level_requirement_max_at_level_5() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	for i: int in 4:
		Progression.add_xp(w, b, Progression.xp_to_next(w, b.stats.level()))
	assert_eq(b.stats.level(), 5)
	assert_eq(b.skill_points, 5)
	for i: int in 5:
		assert_eq(_rejected(w, Command.level_up(b.id, Slot.Q)), Command.Reject.NONE, "Q bậc %d ở hero cấp 5" % (i + 1))
	assert_eq(Abilities.of(b, Slot.Q).rank, 5, "cấp 5 max Q")
	b.skill_points = 1
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.Q)), Command.Reject.CANNOT_LEVEL, "Q tối đa bậc 5")
	assert_eq(_rejected(w, Command.level_up(b.id, Slot.R)), Command.Reject.CANNOT_LEVEL, "R vẫn cần cấp 6")


func test_ABL_04_attribute_bonus_limit_and_effect() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 0, _center())
	var strength: float = b.stats.get_stat(StatId.Id.STRENGTH)
	b.skill_points = 10
	for i: int in range(3):
		w.submit(Command.level_up(b.id, Command.ATTRIBUTES))
	w.step()
	assert_eq(b.attribute_bonus_count, 2, "D-341: tối đa 2 lần")
	assert_eq(w.rejected_commands.size(), 1)
	assert_near(b.stats.get_stat(StatId.Id.STRENGTH), strength + 6.0, EPS, "mỗi lần +3 mọi thuộc tính")


func test_ECO_03_xp_from_enemy_deaths_nearby_split() -> void:
	var w: World = _world()
	var a: Entity = _brakk(w, 0, _center())
	var ally: Entity = _brakk(w, 0, _center() + Vector2(200, 0))
	var far: Entity = _brakk(w, 0, _center() + Vector2(-2000, 0))
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_ranged", 1, "MID", _center() + Vector2(100, -100))
	_kill(w, -1, creep)
	assert_near(a.xp, 69.0 / 2.0, EPS, "chia đều cho hero trong 1200, kể cả khi không kết liễu")
	assert_near(ally.xp, 69.0 / 2.0, EPS)
	assert_near(far.xp, 0.0, EPS)


func test_ECO_03_own_creeps_and_dead_heroes_give_nothing() -> void:
	var w: World = _world()
	var a: Entity = _brakk(w, 0, _center())
	var mine: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "MID", _center() + Vector2(100, -100))
	_kill(w, -1, mine)
	assert_near(a.xp, 0.0, EPS)
	_kill(w, -1, a)
	var enemy: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 1, "MID", a.position + Vector2(50, 0))
	_kill(w, -1, enemy)
	assert_near(a.xp, 0.0, EPS, "đang chết không nhận XP")


func test_ECO_hero_kill_gold_xp_and_death_loss() -> void:
	var w: World = _world()
	var a: Entity = _brakk(w, 0, _center())
	var b: Entity = _brakk(w, 1, _center() + Vector2(150, 0))
	Progression.add_xp(w, b, Progression.xp_to_next(w, 1) + Progression.xp_to_next(w, 2))
	assert_eq(b.stats.level(), 3)
	b.gold = 500
	var seen: Array[StringName] = []
	_kill(w, a.id, b)
	for ev: GameEvent in w.events:
		seen.append(ev.type)
	assert_true(seen.has(&"kill_credited"))
	assert_eq(a.gold, 200 + 10 * 3 + 150, "vàng hạ hero + Hạ gục đầu tiên (ECO-10)")  # D-125, D-340
	var gold: Array = w.recent_notes.filter(func(n: Array) -> bool: return n[0] == &"gold")
	assert_eq(gold.map(func(n: Array) -> Array: return [int(n[2]), n[4]]), [[380, a.id]], "D-241: chữ nổi +vàng cho kẻ hạ")
	assert_eq(a.stats.level(), 2, "XP hạ hero 60 + 30 × 3 = 150 → lên cấp 2")
	assert_near(a.xp, 150.0 - 120.0, EPS)
	assert_eq(b.gold, 500 - 25 * 3, "ECO-05")


func test_ECO_05_death_never_below_zero_gold() -> void:
	var w: World = _world()
	var b: Entity = _brakk(w, 1, _center())
	b.gold = 10
	_kill(w, -1, b)
	assert_eq(b.gold, 0)


func test_D_60_no_deny_own_creeps_not_attackable() -> void:
	var w: World = _world()
	var a: Entity = _brakk(w, 0, _center())
	var mine: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "MID", _center() + Vector2(100, -100))
	mine.health = 10.0
	assert_false(Rules.is_attackable(a, mine))
