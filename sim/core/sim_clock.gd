class_name SimClock
extends RefCounted
## Thời gian của SIM tính bằng tick số nguyên (D-30). Đổi giây ↔ tick chỉ qua đây.
## Bộ đếm theo thời gian khung hình (chạy, tạm dừng, tua nhanh) thuộc tầng APP.

const TICKS_PER_SECOND: int = 30
const TICK_SECONDS: float = 1.0 / TICKS_PER_SECOND


## Làm tròn tới tick gần nhất; thời lượng dương luôn kéo dài ít nhất 1 tick.
static func seconds_to_ticks(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return maxi(1, roundi(seconds * TICKS_PER_SECOND))


static func ticks_to_seconds(ticks: int) -> float:
	return ticks * TICK_SECONDS
