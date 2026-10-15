extends TestCase
## M2.6 soak (chạy riêng: run_tests -Soak): 10 phút trận đủ lính, trụ, quái rừng, 2 hero dùng nút đánh;
## kiểm tra bất biến INV-01..05 mỗi tick và INV-08 (chạy lại cùng lệnh ra cùng trạng thái).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const MINUTES: float = 10.0
## INV-05: đứng yên quá chừng này tick khi không có mục tiêu là lỗi.
const IDLE_LIMIT: int = 60
## INV-04: ra xa origin leash quá leash + chừng này là lỗi.
const LEASH_SLACK: float = 100.0

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(11, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_jungle(w, _lib)
	MatchSetup.add_lane_creeps(w, _lib, true)
	var mid: Vector2 = _map.world_size() * 0.5
	UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, w.navigation(32.0).nearest_clear(mid + Vector2(-600, 600)))
	UnitFactory.hero(w, _lib.heroes[&"vexa"], 1, w.navigation(32.0).nearest_clear(mid + Vector2(600, -600)))
	return w


## Hai hero bấm nút đánh đều đặn (lệnh giống hệt nhau ở cả hai lần chạy).
func _press_buttons(w: World) -> void:
	if w.tick % 20 != 0:
		return
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.HERO and e.alive:
			var mode: Rules.AttackMode = Rules.AttackMode.CREEP if (w.tick / 20 + e.team) % 3 == 0 else Rules.AttackMode.ALL
			w.submit(Command.attack_auto(e.id, mode))


func test_INV_01_05_and_08_ten_minutes() -> void:
	var ticks: int = SimClock.seconds_to_ticks(MINUTES * 60.0)
	var w: World = _world()
	var checkpoints: Array[PackedByteArray] = []
	var still: Dictionary[int, int] = {}
	var last_pos: Dictionary[int, Vector2] = {}
	var mover: MovementSystem = _movement(w)
	for t: int in range(ticks):
		_press_buttons(w)
		w.step()
		for ev: GameEvent in w.events:  # D-76: đợt lính đi qua không tự đụng trại rừng
			var src: Entity = w.find_entity(ev.source_id)
			var dst: Entity = w.find_entity(ev.target_id)
			if ev.type == &"damage_taken" and src != null and dst != null and src.kind == Entity.Kind.LANE_CREEP and dst.kind == Entity.Kind.NEUTRAL:
				fail("tick %d: lính đường đánh quái rừng khi không ai kéo" % w.tick)
				return
		var problem: String = _check(w, still, last_pos)
		if problem != "":
			fail("tick %d (%s): %s" % [w.tick, MatchHud.clock_text(w.tick), problem])
			return
		if t % 900 == 899:
			checkpoints.append(w.state_hash())
		if w.tick == SimClock.seconds_to_ticks(w.balance.jungle_first_spawn) + 1:
			assert_eq(w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.NEUTRAL).size(), 28, "12 trại đủ quái (JGL-05)")
	assert_eq(mover.blocked_steps, 0, "MOV-05: không bước nào bị chặn vì vật cản")
	var last_hits: int = 0
	for e: Entity in w.entities:
		last_hits += e.last_hits
	assert_true(last_hits > 0, "hero dùng nút đánh có kết liễu được lính")
	var again: World = _world()
	for t: int in range(ticks):
		_press_buttons(again)
		again.step()
		if t % 900 == 899 and again.state_hash() != checkpoints[t / 900]:
			fail("INV-08: lệch ở mốc %s" % MatchHud.clock_text(again.tick))
			return


func _movement(w: World) -> MovementSystem:
	for entry: Array in w._systems:
		if entry[2] is MovementSystem:
			return entry[2]
	return null


func _check(w: World, still: Dictionary[int, int], last_pos: Dictionary[int, Vector2]) -> String:
	for e: Entity in w.entities:
		if not e.alive or Rules.is_structure(e):
			continue
		if not w.navigation(e.radius).point_is_clear(e.position):
			return "INV-01: đơn vị %d (%s) chồng vật cản tại %s" % [e.id, Entity.Kind.keys()[e.kind], e.position]
		if e.order.type == Order.Type.ATTACK and not e.order.finished:
			var target: Entity = w.find_entity(e.order.target_id)
			if target != null and target.locked:
				return "INV-02: đơn vị %d nhắm công trình khóa %s" % [e.id, target.structure_id]
		if e.kind != Entity.Kind.LANE_CREEP:
			continue
		var route: LaneRoute = LaneRoute.of(w, e.lane, e.team)
		if route.progress_of(e.position) > LaneRoute.limit(w, e) + w.balance.creep_front_margin + 1.0:
			return "INV-03: lính %d vượt mép trước" % e.id
		if e.has_origin and e.position.distance_to(e.chase_origin) > w.balance.creep_chase_leash + LEASH_SLACK:
			return "INV-04: lính %d xa origin %.0f" % [e.id, e.position.distance_to(e.chase_origin)]
		var busy: bool = e.order.type == Order.Type.ATTACK and not e.order.finished
		var moved: bool = not last_pos.has(e.id) or last_pos[e.id].distance_to(e.position) > 0.01
		last_pos[e.id] = e.position
		still[e.id] = 0 if (busy or moved) else still.get(e.id, 0) + 1
		if still[e.id] > IDLE_LIMIT:
			return "INV-05: lính %d đứng yên không mục tiêu quá 2 s tại %s" % [e.id, e.position] + _debug(w, e)
	return ""


func _debug(w: World, e: Entity) -> String:
	var route: LaneRoute = LaneRoute.of(w, e.lane, e.team)
	var s: String = " team %d lane %s order %d fin %s ret %s prog %.0f limit %.0f" % [e.team, e.lane, e.order.type, e.order.finished, e.returning, route.progress_of(e.position), LaneRoute.limit(w, e)]
	for o: Entity in w.entities:
		if o != e and o.alive and o.position.distance_to(e.position) < 700:
			s += "\n  %d k%d t%d d%.0f order %d->%d fin %s" % [o.id, o.kind, o.team, Rules.edge_distance(e, o), o.order.type, o.order.target_id, o.order.finished]
	return s
