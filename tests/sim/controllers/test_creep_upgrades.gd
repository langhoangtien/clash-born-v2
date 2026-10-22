extends TestCase
## D-98: lính mạnh dần (CRP-11), lính siêu cấp theo lane và siêu lính (CRP-12).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	MatchSetup.spawn_structures(w, _lib)
	return w


func _creep(w: World, team: int, lane: String) -> Entity:
	var c: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", team, lane, _map.lane_spawn_point(team, lane))
	WaveSpawner.empower(w, c, WaveSpawner.creep_tier(w, team, lane))
	return c


func test_CRP_11_creeps_grow_every_five_minutes() -> void:
	var w: World = _world()
	var c0: Entity = _creep(w, 0, "MID")
	assert_near(c0.stats.get_stat(StatId.Id.MAX_HP), 450.0, 0.01)
	w.tick = SimClock.seconds_to_ticks(10.0 * 60.0) + 5
	var c10: Entity = _creep(w, 0, "MID")
	assert_near(c10.stats.get_stat(StatId.Id.MAX_HP), 450.0 * 1.16, 0.01, "phút 10: +16%")
	assert_near(c10.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), c0.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) * 1.16, 0.01)
	assert_near(c10.health, c10.stats.get_stat(StatId.Id.MAX_HP), 0.01, "đầy máu")
	assert_eq(c10.bounty_gold, c0.bounty_gold, "vàng không đổi")


func test_CRP_12_super_creeps_on_lane_with_fallen_t3_then_mega() -> void:
	var w: World = _world()
	w.destroyed_structures[&"red_mid_t3"] = true
	var mid: Entity = _creep(w, 0, "MID")
	var top: Entity = _creep(w, 0, "TOP")
	var red: Entity = _creep(w, 1, "MID")
	assert_eq(mid.creep_tier, 1, "lính xanh lane giữa thành siêu cấp")
	assert_near(mid.stats.get_stat(StatId.Id.MAX_HP), 450.0 * 1.5, 0.01)
	assert_eq(top.creep_tier, 0, "lane khác không đổi")
	assert_eq(red.creep_tier, 0, "lính đội mất trụ không đổi")
	w.destroyed_structures[&"red_top_t3"] = true
	w.destroyed_structures[&"red_bot_t3"] = true
	var mega: Entity = _creep(w, 0, "TOP")
	assert_eq(mega.creep_tier, 2, "đủ 3 trụ 3: siêu lính mọi lane")
	assert_near(mega.stats.get_stat(StatId.Id.MAX_HP), 450.0 * 2.2, 0.01)
	assert_eq(mega.bounty_gold, int(36 * 0.5), "siêu lính: nửa vàng")


func test_CRP_12_mega_wave_has_extra_melee() -> void:
	var w: World = _world()
	for lane: String in ["top", "mid", "bot"]:
		w.destroyed_structures[StringName("red_%s_t3" % lane)] = true
	w.add_system(WaveSpawner.new(_lib), World.Phase.SPAWN)
	while w.tick < SimClock.seconds_to_ticks(w.balance.first_wave_time):
		w.step()
	var blue: int = 0
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.LANE_CREEP and e.team == 0 and e.lane == "MID":
			blue += 1
	assert_eq(blue, w.balance.wave_melee + w.balance.wave_ranged + w.balance.mega_extra_melee)
	var h: PackedByteArray = w.state_hash()
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.LANE_CREEP:
			e.creep_tier = 0
			break
	assert_true(w.state_hash() != h, "D-30")


## Lỗi chơi thử 2026-10-22: sau D-103 trụ 4 / nhà chính nằm lệch khỏi route (490–1500 đơn vị
## từ cuối route) nên lính đứng ở cuối lane. CRP-03b: ở mép trước mà công trình kế tiếp ngoài
## tầm thì rời route đi thẳng tới đánh nó.
func test_CRP_03b_creeps_leave_lane_end_to_hit_t4_then_core() -> void:
	var w: World = _world()
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_lane_creeps(w, _lib, false)
	for e: Entity in w.entities.duplicate():
		if e.kind == Entity.Kind.TOWER and e.team == 1 and e.tier < 4:
			w.destroyed_structures[e.structure_id] = true
			w.remove_entity(e)
	Objectives.refresh_locks(w)
	var route: LaneRoute = LaneRoute.of(w, "BOT", 0)
	var c: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "BOT", route.point_at(route.length() - 50.0))
	var t4: Entity = Objectives.next_for_lane(w, 0, "BOT")
	assert_eq(t4.tier, 4)
	var hp: float = t4.health
	for i: int in range(30 * 20):
		w.step()
	assert_true(t4.health < hp, "lính tới đánh trụ 4 lệch khỏi route")
	for e: Entity in w.entities.duplicate():
		if e.kind == Entity.Kind.TOWER and e.team == 1:
			w.destroyed_structures[e.structure_id] = true
			w.remove_entity(e)
	Objectives.refresh_locks(w)
	var core: Entity = Objectives.next_for_lane(w, 0, "BOT")
	assert_eq(core.kind, Entity.Kind.CORE)
	var core_hp: float = core.health
	MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "BOT", route.point_at(route.length() - 50.0))
	for i: int in range(30 * 25):
		w.step()
	assert_true(core.health < core_hp, "hết trụ 4: lính đi tiếp đánh nhà chính (cách cuối route ~1500)")
