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
