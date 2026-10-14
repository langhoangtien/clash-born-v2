extends TestCase
## M2.4: CTL-02..04 (chọn mục tiêu, khóa), D-46 (đánh gió), CMD-05 ATTACK_AUTO, CMD-02 UNIT_DEAD.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(structures: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if structures:
		MatchSetup.spawn_structures(w, _lib)
	return w


## Giữa sông, xa mọi trụ.
func _center() -> Vector2:
	return _map.world_size() * 0.5


func _unit(w: World, team: int, kind: Entity.Kind, at: Vector2, hp: float = 1000.0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, hp)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


## Đặt `e` cách mép `hero` đúng `edge` theo hướng `angle` (độ).
func _at_edge(hero: Entity, e: Entity, edge: float, angle: float = 0.0) -> void:
	e.position = hero.position + Vector2.from_angle(deg_to_rad(angle)) * (edge + hero.radius + e.radius)


func _pick(w: World, hero: Entity, mode: Rules.AttackMode = Rules.AttackMode.ALL) -> int:
	return Rules.pick_attack_target(w, hero, mode)


func test_CTL_02_enemy_hero_lowest_hp_before_creeps() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var creep: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 10)
	var full: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO, 1000)
	var hurt: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO, 1000)
	hurt.health = 400.0
	_at_edge(me, creep, 20)
	_at_edge(me, full, 50, 90)
	_at_edge(me, hurt, 220, 180)
	assert_eq(_pick(w, me), hurt.id, "hero máu thấp nhất trước, dù xa hơn và có lính gần")


func test_CTL_02_search_range_is_attack_range_plus_bonus() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var enemy: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO)
	var search: float = 150.0 + w.balance.attack_search_bonus
	_at_edge(me, enemy, search + 5.0)
	assert_eq(_pick(w, me), -1, "ngoài tầm tìm thì không chọn")
	_at_edge(me, enemy, search - 5.0)
	assert_eq(_pick(w, me), enemy.id)


func test_CTL_02_nearest_creep_or_neutral_when_no_hero() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var far_creep: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 10)
	var neutral: Entity = _unit(w, 2, Entity.Kind.NEUTRAL, Vector2.ZERO)
	var ally: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, Vector2.ZERO)
	_at_edge(me, far_creep, 200)
	_at_edge(me, neutral, 100, 90)
	_at_edge(me, ally, 10, 180)
	assert_eq(_pick(w, me), neutral.id, "gần nhất, bỏ qua phe mình")


func test_CTL_02_structure_last_and_only_when_unlocked() -> void:
	var w: World = _world(true)
	var t1: Entity = _structure(w, &"red_mid_t1")
	var t2: Entity = _structure(w, &"red_mid_t2")
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, Vector2.ZERO)
	_at_edge(t1, me, 200, 135)
	assert_eq(_pick(w, me), t1.id)
	var creep: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO)
	_at_edge(me, creep, 230, 45)
	assert_eq(_pick(w, me), creep.id, "lính trước công trình")
	me.position = t2.position + (me.position - t1.position)
	creep.position = Vector2.ZERO
	assert_eq(_pick(w, me), -1, "T2 còn khóa thì không chọn")


func test_CTL_03_creep_mode_lowest_hp_creep_ignores_heroes_and_lock() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var hero: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO, 10)
	var near_full: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 500)
	var far_low: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 500)
	far_low.health = 60.0
	_at_edge(me, hero, 10)
	_at_edge(me, near_full, 20, 90)
	_at_edge(me, far_low, 220, 180)
	me.lock_target_id = hero.id
	assert_eq(_pick(w, me, Rules.AttackMode.CREEP), far_low.id)



## D-52: lính đánh xa ít máu đứng sau (gần trụ) không kéo hero vượt lính cận chiến đang đánh.
func test_D_52_ranged_creep_behind_melee_not_picked() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var melee: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 450)
	var ranged: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO, 300)
	_at_edge(me, melee, 40)
	_at_edge(me, ranged, 330)
	for mode: Rules.AttackMode in [Rules.AttackMode.ALL, Rules.AttackMode.CREEP]:
		assert_eq(_pick(w, me, mode), melee.id)

func test_CTL_03_structure_mode_nearest_unlocked_structure() -> void:
	var w: World = _world(true)
	var t1: Entity = _structure(w, &"red_mid_t1")
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, Vector2.ZERO)
	_at_edge(t1, me, 220, 135)
	var creep: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO)
	_at_edge(me, creep, 10, 45)
	assert_eq(_pick(w, me, Rules.AttackMode.STRUCTURE), t1.id)


func test_CTL_04_lock_wins_until_out_of_lock_break_range_or_dead() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var locked: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO)
	var hero: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO, 10)
	_at_edge(me, hero, 10)
	_at_edge(me, locked, 1000, 90)
	w.submit(Command.attack(me.id, locked.id, true))
	w.step()
	assert_eq(me.lock_target_id, locked.id)
	assert_eq(_pick(w, me), locked.id, "khóa thắng cả hero trong tầm, dù ngoài tầm tìm")
	_at_edge(me, locked, w.balance.lock_break_range + 10.0, 90)
	assert_eq(_pick(w, me), hero.id, "ra khỏi lock_break_range thì bỏ khóa")
	w.submit(Command.attack_auto(me.id, Rules.AttackMode.ALL))
	w.step()
	assert_eq(me.lock_target_id, -1, "áp nút đánh thì xóa khóa đã hỏng")
	assert_eq(me.order.target_id, hero.id)


func test_CTL_04_plain_attack_does_not_lock() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var enemy: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, me.position + Vector2(100, 0))
	w.submit(Command.attack(me.id, enemy.id))
	w.step()
	assert_eq(me.lock_target_id, -1)


func test_CMD_05_attack_auto_resolves_when_applied() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	var enemy: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2.ZERO)
	_at_edge(me, enemy, 3000)
	w.submit(Command.attack_auto(me.id, Rules.AttackMode.ALL))
	_at_edge(me, enemy, 100)  # địch đi vào tầm trước khi lệnh được áp
	w.step()
	assert_eq(me.order.type, Order.Type.ATTACK)
	assert_eq(me.order.target_id, enemy.id)
	assert_eq(w.command_log[-1].type, Command.Type.ATTACK_AUTO)


func test_D_46_empty_swing_costs_attack_but_deals_nothing() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	w.submit(Command.attack_auto(me.id, Rules.AttackMode.ALL))
	var started: int = 0
	var landed: int = 0
	for t: int in range(12):
		w.step()
		for ev: GameEvent in w.events:
			started += int(ev.type == &"attack_started" and ev.source_id == me.id and ev.target_id == -1)
			landed += int(ev.type == &"attack_landed")
	assert_eq(me.order.type, Order.Type.SWING)
	assert_eq(started, 1, "vung một đòn")
	assert_eq(landed, 0)
	assert_true(me.order.finished, "đòn gió xong thì lệnh xong")
	assert_eq(me.next_attack_tick, 1 + 30, "tốn một nhịp đánh như đòn thường")
	assert_eq(me.position, _center(), "đứng tại chỗ")


func test_D_46_joystick_cancels_swing_without_cooldown() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	w.submit(Command.attack_auto(me.id, Rules.AttackMode.CREEP))
	for t: int in range(4):
		w.step()
	assert_eq(me.attack_phase, Entity.AttackPhase.WINDUP)
	w.submit(Command.move_dir(me.id, Vector2.LEFT))
	w.step()
	assert_eq(me.attack_phase, Entity.AttackPhase.NONE)
	assert_true(me.next_attack_tick <= w.tick, "hủy không tốn hồi đòn")


func test_CMD_02_dead_unit_commands_rejected() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
	me.alive = false
	w.submit(Command.move_dir(me.id, Vector2.LEFT))
	w.step()
	assert_eq(w.rejected_commands.size(), 1)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.UNIT_DEAD)


func test_D_30_attack_auto_replays_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world()
		var me: Entity = _unit(w, 0, Entity.Kind.HERO, _center())
		for i: int in range(3):
			_unit(w, 1, Entity.Kind.LANE_CREEP, _center() + Vector2(150 + 60 * i, 40 * i), 200 + 50 * i)
		for t: int in range(150):
			if t % 20 == 0:
				w.submit(Command.attack_auto(me.id, Rules.AttackMode.CREEP if t % 40 == 0 else Rules.AttackMode.ALL))
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return


func _structure(w: World, structure_id: StringName) -> Entity:
	for e: Entity in w.entities:
		if e.structure_id == structure_id:
			return e
	return null
