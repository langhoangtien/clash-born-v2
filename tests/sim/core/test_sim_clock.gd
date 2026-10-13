extends TestCase
## Thời gian trong SIM tính bằng tick (D-30): 30 tick/giây.

const EPS: float = 0.000001


func test_ticks_per_second_is_30() -> void:
	assert_eq(SimClock.TICKS_PER_SECOND, 30)
	assert_near(SimClock.TICK_SECONDS, 1.0 / 30.0, EPS)


func test_seconds_to_ticks_rounds_to_nearest() -> void:
	assert_eq(SimClock.seconds_to_ticks(1.0), 30)
	assert_eq(SimClock.seconds_to_ticks(2.3), 69)
	assert_eq(SimClock.seconds_to_ticks(0.05), 2, "1.5 tick làm tròn lên")
	assert_eq(SimClock.seconds_to_ticks(0.0), 0)


func test_positive_duration_lasts_at_least_one_tick() -> void:
	assert_eq(SimClock.seconds_to_ticks(0.001), 1)


func test_negative_duration_is_zero() -> void:
	assert_eq(SimClock.seconds_to_ticks(-1.0), 0)


func test_ticks_to_seconds() -> void:
	assert_near(SimClock.ticks_to_seconds(45), 1.5, EPS)
