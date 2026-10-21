class_name SimRunner
extends RefCounted
## Tầng APP: chạy World đúng 30 tick/giây theo thời gian thật, độc lập tốc độ khung hình.
## SIM không biết thời gian thật (D-30); chỉ chỗ này đọc delta khung hình.

## Khung hình quá dài (máy giật) không chạy bù quá chừng này tick; phần thừa bị bỏ.
const MAX_STEPS_PER_FRAME: int = 5
## Khi tăng tốc: một khung hình không chạy SIM quá chừng này mili giây (giữ hình mượt; máy
## yếu thì tốc độ thật thấp hơn số chọn). Tốc độ ×1 không bị giới hạn này.
const FAST_FRAME_BUDGET_MS: int = 25

signal before_step

var world: World
var paused: bool = false
## Tăng tốc trận để chơi thử (D-53): số giây trận chạy cho mỗi giây thật. Chỉ chạy nhiều
## tick hơn mỗi khung hình, không đổi SIM, nên phát lại vẫn khớp.
var speed: int = 1

var _accumulator: float = 0.0


## D-108: ms SIM mỗi tick (trung bình trượt).
var step_ms: float = 0.0


func _init(p_world: World) -> void:
	world = p_world


## Chạy số tick tương ứng `delta` giây; trả về số tick đã chạy.
func advance(delta: float) -> int:
	if paused:
		return 0
	_accumulator += maxf(0.0, delta) * speed
	var steps: int = 0
	var cap: int = MAX_STEPS_PER_FRAME * speed
	var start: int = Time.get_ticks_msec()
	var t0: int = Time.get_ticks_usec()
	while _accumulator + 0.000001 >= SimClock.TICK_SECONDS and steps < cap and world.winner < 0:
		_accumulator -= SimClock.TICK_SECONDS
		before_step.emit()
		world.step()
		steps += 1
		if speed > 1 and Time.get_ticks_msec() - start > FAST_FRAME_BUDGET_MS:
			_accumulator = 0.0
			break
	if steps > 0:  # D-108: thời gian SIM trung bình mỗi tick (hiện ở HUD để đo trên điện thoại)
		step_ms = lerpf(step_ms, (Time.get_ticks_usec() - t0) / 1000.0 / steps, 0.1)
	if steps == cap or world.winner >= 0:
		_accumulator = minf(_accumulator, SimClock.TICK_SECONDS * 0.999)
	return steps


## Phần đã trôi của tick kế tiếp (0..1), để VIEW nội suy vị trí.
func alpha() -> float:
	return clampf(_accumulator / SimClock.TICK_SECONDS, 0.0, 0.999)
