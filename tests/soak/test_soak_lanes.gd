extends TestCase
## Soak (chạy riêng: run_tests -Soak): lính đánh nhau nhiều phút, kiểm tra bất biến mỗi tick.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(with_structures: bool = true, waves: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if with_structures:
		MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_lane_creeps(w, _lib, waves)
	return w


func _creep(w: World, team: int, lane: String, kind: StringName, progress: float) -> Entity:
	var route: LaneRoute = LaneRoute.of(w, lane, team)
	return MatchSetup.spawn_creep(w, _lib, kind, team, lane, route.point_at(progress))


func _hero(w: World, team: int, at: Vector2, damage: float = 40.0) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, damage)
	return e


func _run(w: World, ticks: int) -> void:
	for t: int in range(ticks):
		w.step()


func _creeps(w: World) -> Array[Entity]:
	var out: Array[Entity] = []
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.LANE_CREEP:
			out.append(e)
	return out


func test_INV_01_03_two_minutes_of_waves() -> void:
	var w: World = _world(true, true)
	for t: int in range(SimClock.seconds_to_ticks(120.0)):
		w.step()
		for c: Entity in _creeps(w):
			if not w.navigation(c.radius).point_is_clear(c.position):
				fail("tick %d lính %d vào vật cản" % [w.tick, c.id])
				return
			var route: LaneRoute = LaneRoute.of(w, c.lane, c.team)
			if route.progress_of(c.position) > LaneRoute.limit(w, c) + w.balance.creep_front_margin + 1.0:
				fail("tick %d lính %d vượt mép trước (INV-03)" % [w.tick, c.id])
				return
	assert_true(_creeps(w).size() > 0)


func test_D_30_waves_replay_identically_40s() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world(true, true)
		for t: int in range(SimClock.seconds_to_ticks(40.0)):
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return
