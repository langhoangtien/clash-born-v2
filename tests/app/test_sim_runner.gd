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
