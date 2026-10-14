extends TestCase
## M1.1: World — id tăng dần, thứ tự pha một tick (ARCHITECTURE mục 4), xác định (D-30).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const RandomWalk = preload("res://tests/sim/world/random_walk_system.gd")
const Recorder = preload("res://tests/sim/world/recorder_system.gd")


func _world(seed_value: int) -> World:
	return World.new(seed_value, Fixture.make())


func _unit(world: World, team: int) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.stats = StatBlock.new(world.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 500)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	return world.add_entity(e)


func test_ids_increase_and_entities_iterate_in_id_order() -> void:
	var w: World = _world(1)
	var a: Entity = _unit(w, 0)
	var b: Entity = _unit(w, 1)
	var c: Entity = _unit(w, 0)
	assert_true(a.id < b.id and b.id < c.id)
	w.remove_entity(b)
	assert_eq(w.entities.map(func(e: Entity) -> int: return e.id), [a.id, c.id])
	assert_eq(_unit(w, 1).id, c.id + 1, "id không dùng lại")


func test_new_entity_starts_full_hp() -> void:
	var w: World = _world(1)
	var a: Entity = _unit(w, 0)
	assert_near(a.health, 500.0, 0.0001)


func test_phases_run_in_architecture_order() -> void:
	var w: World = _world(1)
	var log: Array[int] = []
	var phases: Array = World.Phase.values()
	phases.reverse()  # đăng ký ngược để chắc World tự sắp theo pha
	for phase: int in phases:
		w.add_system(Recorder.new(phase, log), phase)
	w.step()
	var expected: Array[int] = []
	expected.assign(World.Phase.values())
	assert_eq(log, expected)
	assert_eq(w.tick, 1)


func test_phase_list_matches_architecture() -> void:
	assert_eq(World.Phase.keys(), ["COMMAND", "EFFECT", "STATE", "VISION", "CONTROLLER", "MOVEMENT",
		"ABILITY", "ATTACK", "DAMAGE", "TRIGGER", "DEATH", "SPAWN"])


func test_state_phase_recomputes_dirty_stats() -> void:
	var w: World = _world(1)
	var a: Entity = _unit(w, 0)
	a.stats.add_modifier(StatModifier.make(StatId.Id.MAX_HP, ModifierDef.Op.ADD, 100, 1))
	assert_true(a.stats.dirty)
	w.step()
	assert_false(a.stats.dirty)
	assert_near(a.stats.get_stat(StatId.Id.MAX_HP), 600.0, 0.0001)


func test_D_30_same_seed_same_state_every_tick() -> void:
	var w1: World = _world(42)
	var w2: World = _world(42)
	for w: World in [w1, w2]:
		for i: int in range(4):
			_unit(w, i % 2)
		w.add_system(RandomWalk.new(), World.Phase.MOVEMENT)
	for t: int in range(1000):
		w1.step()
		w2.step()
		if w1.state_hash() != w2.state_hash():
			fail("lệch ở tick %d" % w1.tick)
			return
	assert_eq(w1.tick, 1000)


func test_D_30_different_seed_diverges() -> void:
	var w1: World = _world(1)
	var w2: World = _world(2)
	for w: World in [w1, w2]:
		_unit(w, 0)
		w.add_system(RandomWalk.new(), World.Phase.MOVEMENT)
	for t: int in range(10):
		w1.step()
		w2.step()
	assert_ne(w1.state_hash(), w2.state_hash())


func test_state_hash_sees_stat_and_health_changes() -> void:
	var w: World = _world(1)
	var a: Entity = _unit(w, 0)
	var before: PackedByteArray = w.state_hash()
	a.health -= 1
	assert_ne(w.state_hash(), before)
