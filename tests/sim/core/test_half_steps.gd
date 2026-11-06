extends TestCase
## D-273: chạy tick thành hai nửa (nửa đầu tới hết pha CONTROLLER) cho đúng trạng thái như step() — trận thật,
## bot, lính, quái rừng, 2 phút, so băm trạng thái mỗi tick (D-30).


func _world() -> World:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var map: MapLayout = load("res://data/maps/clashborn.tres") as MapLayout
	var w: World = World.new(7, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_jungle(w, lib)
	MatchSetup.add_lane_creeps(w, lib, true)
	MatchSetup.add_bot(w, UnitFactory.hero(w, lib.heroes[&"duy_anh"], 0, map.fountain_point(0)))
	MatchSetup.add_bot(w, UnitFactory.hero(w, lib.heroes[&"noctis"], 1, map.fountain_point(1)))
	return w


func test_D_273_two_halves_equal_full_step() -> void:
	var a: World = _world()
	var b: World = _world()
	var diff: int = -1
	for t: int in range(SimClock.seconds_to_ticks(120.0)):
		a.step()
		b.step_first_half()
		assert_true(b.mid_tick)
		b.step_second_half()
		if diff < 0 and a.state_hash() != b.state_hash():
			diff = a.tick
	assert_eq(diff, -1, "băm trạng thái khớp mọi tick")
	assert_eq(a.events.size(), b.events.size())


func test_D_273_step_finishes_pending_half_first() -> void:
	var a: World = _world()
	var b: World = _world()
	for t: int in range(40):
		a.step()
	for t: int in range(39):
		b.step()
	b.step_first_half()
	b.step()  # đang giữa tick: step() làm nốt nửa sau, không mở tick mới
	assert_eq(b.tick, a.tick)
	assert_eq(b.state_hash(), a.state_hash())
