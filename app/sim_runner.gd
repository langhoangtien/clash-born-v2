class_name SimRunner
extends RefCounted
## Tầng APP: chạy World đúng 30 tick/giây theo thời gian thật, độc lập tốc độ khung hình.
## SIM không biết thời gian thật (D-30); chỉ chỗ này đọc delta khung hình.

## Khung hình quá dài (máy giật) không chạy bù quá chừng này tick; phần thừa bị bỏ.
const MAX_STEPS_PER_FRAME: int = 5

signal before_step

var world: World
var paused: bool = false

var _accumulator: float = 0.0


func _init(p_world: World) -> void:
	world = p_world


## Chạy số tick tương ứng `delta` giây; trả về số tick đã chạy.
func advance(delta: float) -> int:
	if paused:
		return 0
	_accumulator += maxf(0.0, delta)
	var steps: int = 0
	while _accumulator + 0.000001 >= SimClock.TICK_SECONDS and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= SimClock.TICK_SECONDS
		before_step.emit()
		world.step()
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = minf(_accumulator, SimClock.TICK_SECONDS * 0.999)
	return steps


## Phần đã trôi của tick kế tiếp (0..1), để VIEW nội suy vị trí.
func alpha() -> float:
	return clampf(_accumulator / SimClock.TICK_SECONDS, 0.0, 0.999)
