extends TestCase
## M2.1: CMB-01..06 — lệnh ATTACK, vung tay/thu tay, đạn bay, sát thương qua giáp, chết.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01

static var _map: MapLayout


func _world(seed_value: int = 1) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var bal: BalanceSettings = Fixture.make()
	bal.minimum_movement_speed = 0.0
	var w: World = World.new(seed_value, bal)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


## Đơn vị có chỉ số đánh rõ ràng: BAT 1.0 → 1 đòn/giây (30 tick), vung tay 0.3 s (9 tick).
func _fighter(w: World, team: int, at: Vector2, damage: float = 50.0, attack_range: float = 150.0, projectile_speed: float = 0.0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.projectile_speed = projectile_speed
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, damage)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, attack_range)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	return w.add_entity(e)


func _origin() -> Vector2:
	return _map.fountain_point(0) + Vector2(300, -300)


func _hits(w: World, ticks: int, target: Entity) -> Array[int]:
	var out: Array[int] = []
	var hp: float = target.health
	for t: int in range(ticks):
		w.step()
		if target.health < hp:
			out.append(w.tick)
			hp = target.health
	return out


func test_CMB_01_in_range_first_hit_after_attack_point() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	w.submit(Command.attack(a.id, b.id))
	var hits: Array[int] = _hits(w, 40, b)
	assert_eq(hits.size(), 2, "1 đòn/giây: trong 40 tick có 2 đòn")
	assert_eq(hits[0], 1 + 9, "tick 1 bắt đầu vung, 9 tick sau ra đòn")
	assert_eq(hits[1] - hits[0], 30, "hai đòn cách nhau BAT / tốc đánh = 30 tick")


func test_CMB_06_attack_speed_shortens_interval_and_windup() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	a.stats.add_modifier(StatModifier.make(StatId.Id.ATTACK_SPEED, ModifierDef.Op.ADD, 1.0, 1))
	w.submit(Command.attack(a.id, b.id))
	var hits: Array[int] = _hits(w, 40, b)
	assert_eq(hits[1] - hits[0], 15, "tốc đánh ×2 → 15 tick")
	assert_true(hits[0] - 1 <= 5, "vung tay cũng nhanh hơn (≈4–5 tick)")


func test_CMB_01_out_of_range_walks_in_then_attacks() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(600, 0))
	w.submit(Command.attack(a.id, b.id))
	var hits: Array[int] = _hits(w, 90, b)
	assert_true(hits.size() >= 1, "đi tới rồi đánh")
	assert_true(Rules.edge_distance(a, b) <= 150.0 + EPS, "đứng trong tầm")
	assert_true(Rules.edge_distance(a, b) > 100.0, "không đi sát hơn mức cần")


func test_CMB_06_moving_during_windup_cancels_without_cooldown() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	w.submit(Command.attack(a.id, b.id))
	for t: int in range(5):
		w.step()
	assert_eq(a.attack_phase, Entity.AttackPhase.WINDUP)
	w.submit(Command.move_dir(a.id, Vector2.LEFT))
	w.step()
	assert_eq(a.attack_phase, Entity.AttackPhase.NONE, "hủy vung tay")
	w.submit(Command.attack(a.id, b.id))
	var hits: Array[int] = _hits(w, 15, b)
	assert_eq(b.health, 1000.0 - 50.0, "đánh lại ngay, không phải chờ hồi đòn")
	assert_eq(hits.size(), 1)


func test_CMB_06_projectile_flight_time() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin(), 50.0, 600.0, 1000.0)
	var b: Entity = _fighter(w, 1, _origin() + Vector2(500, 0))
	w.submit(Command.attack(a.id, b.id))
	var hits: Array[int] = _hits(w, 40, b)
	# Ra đòn tick 10 từ tâm kẻ bắn; bay 500 − bán kính mục tiêu (24) = 476 với 1000/s ≈ 15 tick.
	assert_true(hits[0] >= 10 + 14 and hits[0] <= 10 + 16, "trúng ở tick %d" % hits[0])
	assert_eq(w.projectiles.size(), 1, "đòn thứ hai đang bay")


func test_CMB_06_projectile_vanishes_when_target_gone() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin(), 50.0, 600.0, 300.0)
	var b: Entity = _fighter(w, 1, _origin() + Vector2(500, 0))
	w.submit(Command.attack(a.id, b.id))
	for t: int in range(12):
		w.step()
	assert_eq(w.projectiles.size(), 1)
	w.remove_entity(b)
	w.step()
	assert_eq(w.projectiles.size(), 0)


func test_CMB_03_damage_through_armor_and_taken_multiplier() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin(), 100.0)
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	b.stats.set_base(StatId.Id.PHYSICAL_ARMOR, 10)
	b.stats.add_modifier(StatModifier.make(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, ModifierDef.Op.ADD, 0.2, 1))
	w.submit(Command.attack(a.id, b.id))
	_hits(w, 12, b)
	assert_near(b.health, 1000.0 - 62.5 * 1.2, EPS, "100 vào giáp 10 = 62.5, ×1.2")


func test_DTH_death_removes_unit_finishes_order_and_emits_events_in_order() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin(), 600.0)
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	w.submit(Command.attack(a.id, b.id))
	var seen: Array[StringName] = []
	for t: int in range(45):
		w.step()
		for ev: GameEvent in w.events:
			seen.append(ev.type)
	assert_eq(w.find_entity(b.id), null, "chết thì bị gỡ")
	assert_true(a.order.finished, "lệnh đánh xong khi mục tiêu chết")
	assert_eq(seen, [&"attack_started", &"attack_landed", &"damage_taken", &"attack_started", &"attack_landed", &"damage_taken", &"unit_died"])


func test_CMD_02_attack_needs_valid_enemy_target() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var ally: Entity = _fighter(w, 0, _origin() + Vector2(50, 0))
	w.submit(Command.attack(a.id, ally.id))
	w.submit(Command.attack(a.id, 999))
	w.step()
	assert_eq(w.rejected_commands.size(), 2)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.BAD_TARGET)


func test_DEF_01_edge_distance() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, Vector2(0, 0))
	var b: Entity = _fighter(w, 1, Vector2(100, 0))
	assert_near(Rules.edge_distance(a, b), 52.0, EPS)
	b.position = Vector2(10, 0)
	assert_near(Rules.edge_distance(a, b), 0.0, EPS)


func test_D_30_combat_replays_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world(4)
		var units: Array[Entity] = []
		for i: int in range(4):
			units.append(_fighter(w, i % 2, _origin() + Vector2(120 * i, 40 * (i % 2)), 80.0, 150.0 + 300.0 * (i % 2), 900.0 * (i % 2)))
		for e: Entity in units:
			var enemy: Entity = units[1] if e.team == 0 else units[0]
			w.submit(Command.attack(e.id, enemy.id))
		for t: int in range(200):
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return
