extends TestCase
## M1.3: MOV-01..05, INV-01, D-30 với di chuyển thật trên map.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const HERO_R: float = 32.0
const EPS: float = 0.01

static var _map: MapLayout


func _world(seed_value: int = 3, with_movement: bool = true) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var bal: BalanceSettings = Fixture.make()
	bal.minimum_movement_speed = 0.0
	bal.separation_speed = 400.0
	bal.tower_body_radius = 52.0
	var w: World = World.new(seed_value, bal)
	w.map = _map
	if with_movement:
		w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _unit(w: World, at: Vector2, speed: float = 300.0, r: float = HERO_R) -> Entity:
	var e: Entity = Entity.new()
	e.radius = r
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 500)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.7)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, speed)
	return w.add_entity(e)


func _clear(w: World, e: Entity) -> bool:
	return w.navigation(e.radius).point_is_clear(e.position)


## Chạy tới khi mọi lệnh xong hoặc hết số tick; trả về số tick đã chạy.
func _run_until_idle(w: World, max_ticks: int) -> int:
	for t: int in range(max_ticks):
		w.step()
		var busy: bool = false
		for e: Entity in w.entities:
			busy = busy or (e.order.type == Order.Type.MOVE and not e.order.finished)
		if not busy:
			return t + 1
	return max_ticks


func test_MOV_01_moves_speed_per_second_on_open_ground() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start, 300.0)
	w.submit(Command.move_to(h.id, start + Vector2(400, 0)))
	w.step()  # tick 1: áp lệnh và đi bước đầu
	for t: int in range(29):
		w.step()
	assert_near(h.position.distance_to(start), 300.0, 1.0, "30 tick = 1 giây = 300")


func test_MOV_07_corner_within_body_radius_counts_as_reached() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start, 300.0)
	w.submit(Command.move_to(h.id, start + Vector2(0, -300)))
	w.step()
	h.path = PackedVector2Array([h.position, h.position + Vector2(15, 0), h.position + Vector2(0, -300)])
	h.path_index = 1
	var x0: float = h.position.x
	w.step()
	assert_eq(h.path_index, 2, "điểm rẽ cách tâm < bán kính thân: coi như đã tới")
	assert_near(h.position.x, x0, 0.5, "đi thẳng tới điểm sau, không vòng qua điểm rẽ")


func test_MOV_01_crosses_map_without_clipping_and_arrives() -> void:
	var w: World = _world()
	var h: Entity = _unit(w, _map.fountain_point(0))
	var target: Vector2 = w.navigation(HERO_R).nearest_clear(_map.world_size() * 0.5 + Vector2(900, -300))
	w.submit(Command.move_to(h.id, target))
	var previous: Vector2 = h.position
	for t: int in range(2400):
		w.step()
		assert_true(_clear(w, h), "tick %d vào vật cản tại %s" % [w.tick, h.position])
		assert_true(w.navigation(HERO_R).has_line_of_walk(previous, h.position), "tick %d đi xuyên vật cản" % w.tick)
		previous = h.position
		if h.order.finished:
			break
	assert_true(h.order.finished, "tới nơi")
	assert_near(h.position.distance_to(target), 0.0, EPS)


func test_MOV_02_destination_in_forest_goes_to_nearest_standable_point() -> void:
	var w: World = _world()
	var forest: Vector2 = Vector2.ZERO
	for shape: MapShape in _map.forest_shapes:
		var c: Vector2 = Vector2.ZERO
		for p: Vector2 in shape.outer:
			c += p
		c /= shape.outer.size()
		if _map.clearance_at(c) == 0.0 and Geometry2D.is_point_in_polygon(c, shape.outer) and c.distance_to(_map.fountain_point(0)) < 4000:
			forest = c
			break
	assert_ne(forest, Vector2.ZERO)
	var h: Entity = _unit(w, _map.fountain_point(0))
	w.submit(Command.move_to(h.id, forest))
	_run_until_idle(w, 2400)
	assert_true(h.order.finished)
	assert_true(_clear(w, h))
	assert_near(h.position.distance_to(w.navigation(HERO_R).nearest_clear(forest)), 0.0, EPS)


func test_MOV_03_stop_halts_and_new_command_repaths() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start)
	w.submit(Command.move_to(h.id, start + Vector2(600, 0)))
	for t: int in range(10):
		w.step()
	w.submit(Command.stop(h.id))
	w.step()
	var stopped_at: Vector2 = h.position
	for t: int in range(10):
		w.step()
	assert_eq(h.position, stopped_at)
	w.submit(Command.move_to(h.id, start + Vector2(0, -300)))
	_run_until_idle(w, 300)
	assert_near(h.position.distance_to(start + Vector2(0, -300)), 0.0, EPS)


func test_MOV_01_zero_speed_does_not_move() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start, 0.0)
	w.submit(Command.move_to(h.id, start + Vector2(300, 0)))
	for t: int in range(30):
		w.step()
	assert_eq(h.position, start)


func test_MOV_04_two_units_on_same_spot_separate() -> void:
	var w: World = _world()
	var p: Vector2 = _map.fountain_point(0) + Vector2(200, -200)
	var a: Entity = _unit(w, p)
	var b: Entity = _unit(w, p)
	for t: int in range(30):
		w.step()
	assert_true(a.position.distance_to(b.position) >= 2 * HERO_R - 0.5, "tách ra: %.1f" % a.position.distance_to(b.position))
	assert_true(_clear(w, a) and _clear(w, b))


func test_MOV_04_hero_walks_through_idle_crowd() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start)
	for i: int in range(5):
		_unit(w, start + Vector2(300, -80 + 40 * i), 300.0, 20.0)
	var target: Vector2 = start + Vector2(600, 0)
	w.submit(Command.move_to(h.id, target))
	_run_until_idle(w, 300)
	assert_true(h.order.finished, "len qua được")
	assert_true(h.position.distance_to(target) < 1.0)


func test_INV_01_thirty_random_walkers_never_enter_obstacles() -> void:
	var w: World = _world(11, false)
	var movement: MovementSystem = MovementSystem.new()
	w.add_system(movement, World.Phase.MOVEMENT)
	var arrivals: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var nav: MapNavigation = w.navigation(HERO_R)
	var center: Vector2 = Vector2(1488, 6832)  # vùng base xanh (cố định, không theo vị trí fountain)
	for i: int in range(30):
		_unit(w, nav.nearest_clear(center + Vector2(rng.randf_range(-600, 600), rng.randf_range(-600, 600))), rng.randf_range(250, 350))
	var worst_overlap: float = 0.0
	for t: int in range(1800):
		for e: Entity in w.entities:
			if e.order.type == Order.Type.IDLE or e.order.finished:
				arrivals += 1
				w.submit(Command.move_to(e.id, center + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))))
		w.step()
		for e: Entity in w.entities:
			if not _clear(w, e):
				fail("tick %d đơn vị %d vào vật cản pos %s" % [w.tick, e.id, e.position])
				return
		if t > 60 and t % 30 == 0:
			worst_overlap = maxf(worst_overlap, _worst_overlap(w))
	assert_true(worst_overlap < HERO_R, "chồng nhau tối đa %.1f (giới hạn %s)" % [worst_overlap, HERO_R])
	assert_eq(movement.blocked_steps, 0, "không bước nào phải chặn vì sắp vào vật cản")
	assert_true(arrivals > 60, "các đơn vị liên tục tới nơi (%d lần), không bị kẹt" % arrivals)


func _worst_overlap(w: World) -> float:
	var worst: float = 0.0
	for i: int in range(w.entities.size()):
		for j: int in range(i + 1, w.entities.size()):
			var a: Entity = w.entities[i]
			var b: Entity = w.entities[j]
			worst = maxf(worst, a.radius + b.radius - a.position.distance_to(b.position))
	return worst


func test_D_30_movement_replays_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world(5)
		var start: Vector2 = _map.fountain_point(0)
		for i: int in range(6):
			_unit(w, start + Vector2(60 * i, -40 * i))
		for t: int in range(400):
			if t % 50 == 0:
				for e: Entity in w.entities:
					w.submit(Command.move_to(e.id, start + Vector2(800 - 37 * e.id + t, -600 + 13 * e.id)))
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return


func test_MOV_06_move_dir_goes_straight_at_speed() -> void:
	var w: World = _world()
	var start: Vector2 = _map.fountain_point(0)
	var h: Entity = _unit(w, start, 300.0)
	w.submit(Command.move_dir(h.id, Vector2(1, -1)))
	for t: int in range(30):
		w.step()
	assert_near(h.position.distance_to(start), 300.0, 1.0)
	assert_near((h.position - start).normalized().dot(Vector2(1, -1).normalized()), 1.0, 0.001)
	assert_false(h.order.finished, "đi theo hướng không tự xong")


func test_MOV_06_slides_along_obstacle_never_enters() -> void:
	var w: World = _world()
	var nav: MapNavigation = w.navigation(HERO_R)
	var h: Entity = _unit(w, _map.fountain_point(0))
	# Đi chéo lên trái tới mép map/vách rồi giữ hướng: phải trượt chứ không kẹt cứng.
	w.submit(Command.move_dir(h.id, Vector2(-1, -0.3)))
	var positions: Array[Vector2] = []
	for t: int in range(240):
		w.step()
		assert_true(nav.point_is_clear(h.position), "tick %d vào vật cản" % w.tick)
		positions.append(h.position)
	var last_second: float = positions[-1].distance_to(positions[-31])
	assert_true(last_second > 20.0, "vẫn trượt dọc mép (%.1f trong 1 s cuối)" % last_second)


func test_MOV_06_stop_ends_direct_move() -> void:
	var w: World = _world()
	var h: Entity = _unit(w, _map.fountain_point(0))
	w.submit(Command.move_dir(h.id, Vector2.RIGHT))
	for t: int in range(5):
		w.step()
	w.submit(Command.stop(h.id))
	w.step()
	var at: Vector2 = h.position
	w.step()
	assert_eq(h.position, at)


func test_CMD_02_bad_direction_rejected() -> void:
	var w: World = _world()
	var h: Entity = _unit(w, _map.fountain_point(0))
	w.submit(Command.move_dir(h.id, Vector2.ZERO))
	w.submit(Command.move_dir(h.id, Vector2(NAN, 1)))
	w.step()
	assert_eq(w.rejected_commands.size(), 2)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.BAD_DIRECTION)


func test_D_30_direct_moves_replay_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world(8)
		var h: Entity = _unit(w, _map.fountain_point(0))
		for t: int in range(300):
			if t % 40 == 0:
				w.submit(Command.move_dir(h.id, Vector2.from_angle(t * 0.37)))
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return
