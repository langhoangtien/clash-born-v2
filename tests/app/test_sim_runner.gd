extends TestCase
## M1.4: SimRunner chạy SIM 30 tick/giây độc lập tốc độ khung hình (D-30, DEF-03).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _runner() -> SimRunner:
	return SimRunner.new(World.new(1, Fixture.make()))


func test_one_second_is_thirty_ticks() -> void:
	var r: SimRunner = _runner()
	var steps: int = 0
	for i: int in range(60):
		steps += r.advance(1.0 / 60.0)
	assert_eq(steps, 30)
	assert_eq(r.world.tick, 30)


func test_uneven_frames_accumulate() -> void:
	var r: SimRunner = _runner()
	for d: float in [0.01, 0.05, 0.02, 0.0, 0.02]:
		r.advance(d)
	assert_eq(r.world.tick, 3, "0.1 s = 3 tick")
	assert_true(r.alpha() >= 0.0 and r.alpha() < 1.0)


func test_long_frame_is_capped() -> void:
	var r: SimRunner = _runner()
	assert_eq(r.advance(10.0), SimRunner.MAX_STEPS_PER_FRAME, "máy giật không chạy bù cả trăm tick một lúc")
	assert_eq(r.advance(0.0), 0, "phần thời gian thừa bị bỏ")


func test_paused_runner_does_not_step() -> void:
	var r: SimRunner = _runner()
	r.paused = true
	assert_eq(r.advance(1.0), 0)


func test_step_callback_runs_before_each_tick() -> void:
	var r: SimRunner = _runner()
	var seen: Array[int] = []
	r.before_step.connect(func() -> void: seen.append(r.world.tick))
	r.advance(0.1)
	assert_eq(seen, [0, 1, 2])


func test_D_53_speed_runs_more_ticks_per_real_second() -> void:
	var r: SimRunner = _runner()
	r.speed = 4
	for i: int in range(60):
		r.advance(1.0 / 60.0)
	assert_eq(r.world.tick, 120)


func test_STR_05_runner_stops_when_match_ended() -> void:
	var r: SimRunner = _runner()
	r.world.winner = 1
	assert_eq(r.advance(1.0), 0)


## D-273: trận thật chia mỗi tick thành hai nửa chạy trên hai khung liên tiếp.
func _split_runner() -> SimRunner:
	var r: SimRunner = SimRunner.new(World.new(1, Fixture.make()), true)
	return r


func test_D_273_tick_split_across_two_frames_at_60fps() -> void:
	var r: SimRunner = _split_runner()
	var completed: int = 0
	var mid_seen: int = 0
	for i: int in range(60):
		completed += r.advance(1.0 / 60.0)
		if r.world.mid_tick:
			mid_seen += 1
	assert_true(mid_seen >= 29, "khung có tick: chỉ chạy nửa đầu, nửa sau ở khung kế")
	assert_true(completed >= 29 and completed <= 30, "vẫn ~30 tick / giây")
	assert_true(r.world.tick - completed <= 1)


func test_D_273_falls_back_to_full_ticks_when_behind() -> void:
	var r: SimRunner = _split_runner()
	r.advance(0.1)  # trễ 3 tick: chạy bù tick đầy đủ, chỉ tick cuối chia đôi
	assert_true(r.world.tick >= 3)
	assert_true(r.world.tick - (3 if not r.world.mid_tick else 2) <= 1)


func test_D_273_stepped_signal_only_after_full_tick() -> void:
	var r: SimRunner = _split_runner()
	var done_ticks: Array[int] = []
	r.stepped.connect(func() -> void:
		assert_false(r.world.mid_tick, "VIEW chỉ đọc sự kiện khi tick đã xong cả hai nửa")
		done_ticks.append(r.world.tick))
	for i: int in range(12):
		r.advance(1.0 / 60.0)
	assert_eq(done_ticks, [1, 2, 3, 4, 5])
