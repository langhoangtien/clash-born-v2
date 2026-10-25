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


## D-152: chạy trên luồng phụ — cùng số tick theo thời gian thật, tick chạy giữa start() và finish().
func test_D_152_threaded_runner_keeps_thirty_ticks_per_second() -> void:
	var r: SimRunner = _runner()
	r.threaded = true
	for i: int in range(60):
		assert_eq(r.advance(1.0 / 60.0), 0, "chế độ luồng phụ chỉ hẹn tick")
		r.start()
		r.finish()
	assert_eq(r.world.tick, 30)
	assert_true(r.alpha() >= 0.0 and r.alpha() < 1.0)


func test_D_152_threaded_runner_matches_direct_run() -> void:
	var a: SimRunner = _runner()
	var b: SimRunner = _runner()
	b.threaded = true
	for d: float in [0.016, 0.034, 0.016, 0.1, 0.0, 0.016, 0.05]:
		a.advance(d)
		b.advance(d)
		b.start()
	b.finish()
	b.advance(0.0)
	b.start()
	b.finish()
	assert_true(absi(a.world.tick - b.world.tick) <= 2, "lệch tối đa phần đoán trước một khung")
	assert_true(b.world.tick > 0)


func test_D_152_advance_waits_for_running_ticks() -> void:
	var r: SimRunner = _runner()
	r.threaded = true
	r.advance(0.1)
	r.start()
	r.advance(0.0)  # không gọi finish(): advance tự chờ trước khi hẹn tiếp
	assert_true(r.world.tick >= 3)
