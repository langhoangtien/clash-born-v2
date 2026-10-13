extends TestCase
## M1.2: CMD-01..05 — lệnh → kiểm tra → lệnh hiện tại (Order), nhật ký, phát lại (D-30).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const RandomWalk = preload("res://tests/sim/world/random_walk_system.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"

static var _map: MapLayout


func _world(seed_value: int = 7) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(seed_value, Fixture.make())
	w.map = _map
	return w


func _hero(w: World) -> Entity:
	var e: Entity = Entity.new()
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 500)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	return w.add_entity(e)


func test_CMD_01_new_unit_is_idle() -> void:
	var w: World = _world()
	assert_eq(_hero(w).order.type, Order.Type.IDLE)


func test_CMD_01_move_to_becomes_order_on_next_tick() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	w.submit(Command.move_to(h.id, Vector2(1000, 2000)))
	assert_eq(h.order.type, Order.Type.IDLE, "chưa áp trước khi chạy tick")
	w.step()
	assert_eq(h.order.type, Order.Type.MOVE)
	assert_eq(h.order.point, Vector2(1000, 2000))


func test_CMD_03_newer_command_replaces_order_stop_goes_idle() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	w.submit(Command.move_to(h.id, Vector2(1000, 2000)))
	w.step()
	w.submit(Command.stop(h.id))
	w.step()
	assert_eq(h.order.type, Order.Type.IDLE)


func test_CMD_01_same_tick_commands_apply_in_submission_order() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	w.submit(Command.move_to(h.id, Vector2(100, 100)))
	w.submit(Command.move_to(h.id, Vector2(300, 300)))
	w.step()
	assert_eq(h.order.point, Vector2(300, 300))


func test_CMD_02_unknown_unit_rejected() -> void:
	var w: World = _world()
	w.submit(Command.move_to(999, Vector2(100, 100)))
	w.step()
	assert_eq(w.rejected_commands.size(), 1)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.UNKNOWN_UNIT)


func test_CMD_02_point_outside_map_or_not_finite_rejected() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	w.submit(Command.move_to(h.id, Vector2(-10, 50)))
	w.submit(Command.move_to(h.id, Vector2(INF, 50)))
	w.step()
	assert_eq(h.order.type, Order.Type.IDLE)
	assert_eq(w.rejected_commands.size(), 2)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.POINT_OUTSIDE_MAP)


func test_CMD_02_rejections_cleared_each_tick() -> void:
	var w: World = _world()
	w.submit(Command.stop(999))
	w.step()
	w.step()
	assert_true(w.rejected_commands.is_empty())


func test_CMD_04_applied_commands_logged_with_tick() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	w.step()
	w.submit(Command.move_to(h.id, Vector2(500, 500)))
	w.submit(Command.stop(999))
	w.step()
	assert_eq(w.command_log.size(), 1, "lệnh bị từ chối không ghi")
	assert_eq(w.command_log[0].tick, 2)


func test_D_30_replay_from_command_log_matches_every_tick() -> void:
	var original: World = _world(99)
	var hero: Entity = _hero(original)
	original.add_system(RandomWalk.new(), World.Phase.MOVEMENT)
	var hashes: Array[PackedByteArray] = []
	for t: int in range(300):
		if t % 37 == 0:
			original.submit(Command.move_to(hero.id, Vector2(100 + t, 200 + 2 * t)))
		if t % 53 == 0:
			original.submit(Command.stop(hero.id))
		original.step()
		hashes.append(original.state_hash())
	var replay: World = _world(99)
	_hero(replay)
	replay.add_system(RandomWalk.new(), World.Phase.MOVEMENT)
	var player: CommandReplay = CommandReplay.new(original.command_log)
	for t: int in range(300):
		player.feed(replay)
		replay.step()
		if replay.state_hash() != hashes[t]:
			fail("phát lại lệch ở tick %d" % replay.tick)
			return
	assert_eq(replay.command_log.size(), original.command_log.size())


func test_D_30_order_is_part_of_state_hash() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	var before: PackedByteArray = w.state_hash()
	w.submit(Command.move_to(h.id, Vector2(10, 10)))
	w.step()
	var w2: World = _world()
	_hero(w2)
	w2.step()
	assert_ne(w.state_hash(), w2.state_hash())
	assert_ne(before, w.state_hash())
