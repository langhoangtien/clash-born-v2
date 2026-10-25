class_name SimRunner
extends RefCounted
## Tầng APP: chạy World đúng 30 tick/giây theo thời gian thật, độc lập tốc độ khung hình.
## SIM không biết thời gian thật (D-30); chỉ chỗ này đọc delta khung hình.
## D-152: `threaded` — các tick của khung được chạy trên luồng phụ trong lúc máy vẽ khung
## (start ở frame_pre_draw, finish ở frame_post_draw), nên SIM không cộng vào thời gian khung.
## VIEW chỉ đọc World ngoài khoảng đó. SIM không đổi: cùng chuỗi tick, cùng kết quả.

## Khung hình quá dài (máy giật) không chạy bù quá chừng này tick; phần thừa bị bỏ.
const MAX_STEPS_PER_FRAME: int = 5
## Khi tăng tốc: một khung hình không chạy SIM quá chừng này mili giây (giữ hình mượt; máy
## yếu thì tốc độ thật thấp hơn số chọn). Tốc độ ×1 không bị giới hạn này.
const FAST_FRAME_BUDGET_MS: int = 25

signal before_step
## Sau mỗi tick (VIEW đọc world.events của tick đó, vd âm thanh D-114).
signal stepped

var world: World
var paused: bool = false
## Tăng tốc trận để chơi thử (D-53): số giây trận chạy cho mỗi giây thật. Chỉ chạy nhiều
## tick hơn mỗi khung hình, không đổi SIM, nên phát lại vẫn khớp.
var speed: int = 1

var _accumulator: float = 0.0
## D-152: chạy tick trên luồng phụ; số tick chờ chạy và việc đang chạy (-1 = không có).
var threaded: bool = false
var _due: int = 0
var _task: int = -1


## D-108: ms SIM mỗi tick (trung bình trượt).
var step_ms: float = 0.0


func _init(p_world: World) -> void:
	world = p_world


## Chạy số tick tương ứng `delta` giây; trả về số tick đã chạy. Chế độ `threaded`: chỉ hẹn số tick
## cho tới khung sau (đoán khung sau dài bằng khung này), start() mới chạy; trả về 0.
func advance(delta: float) -> int:
	finish()
	if paused:
		return 0
	var add: float = maxf(0.0, delta) * speed
	_accumulator += add
	if threaded:
		_due = _due_steps(_accumulator + add)
		return 0
	return _run(_due_steps(_accumulator))


## D-152: bắt đầu chạy các tick đã hẹn trên luồng phụ (gọi khi máy bắt đầu vẽ khung).
func start() -> void:
	if _due > 0 and _task < 0:
		_task = WorkerThreadPool.add_task(_run.bind(_due), true, "SIM")
		_due = 0


## D-152: chờ luồng phụ chạy xong (trước khi VIEW / input đọc World).
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## D-152: bật chạy luồng phụ theo nhịp vẽ của máy; detach() khi rời màn trận.
func attach_to_render() -> void:
	threaded = true
	RenderingServer.frame_pre_draw.connect(start)
	RenderingServer.frame_post_draw.connect(finish)


func detach() -> void:
	finish()
	if RenderingServer.frame_pre_draw.is_connected(start):
		RenderingServer.frame_pre_draw.disconnect(start)
		RenderingServer.frame_post_draw.disconnect(finish)
	threaded = false


func _due_steps(time: float) -> int:
	return mini(floori((time + 0.000001) / SimClock.TICK_SECONDS), MAX_STEPS_PER_FRAME * speed) if world.winner < 0 else 0


func _run(count: int) -> int:
	var steps: int = 0
	var start_ms: int = Time.get_ticks_msec()
	var t0: int = Time.get_ticks_usec()
	while steps < count and world.winner < 0:
		_accumulator -= SimClock.TICK_SECONDS
		before_step.emit()
		world.step()
		stepped.emit()
		steps += 1
		if speed > 1 and Time.get_ticks_msec() - start_ms > FAST_FRAME_BUDGET_MS:
			_accumulator = 0.0
			break
	if steps > 0:  # D-108: thời gian SIM trung bình mỗi tick (hiện ở HUD để đo trên điện thoại)
		step_ms = lerpf(step_ms, (Time.get_ticks_usec() - t0) / 1000.0 / steps, 0.1)
	if steps == MAX_STEPS_PER_FRAME * speed or world.winner >= 0:
		_accumulator = minf(_accumulator, SimClock.TICK_SECONDS * 0.999)
	return steps


## Phần đã trôi của tick kế tiếp (0..1), để VIEW nội suy vị trí.
func alpha() -> float:
	return clampf(_accumulator / SimClock.TICK_SECONDS, 0.0, 0.999)
