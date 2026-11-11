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
## Sau mỗi tick (VIEW đọc world.events của tick đó, vd âm thanh D-114).
signal stepped

var world: World
var paused: bool = false
## Tăng tốc trận để chơi thử (D-53): số giây trận chạy cho mỗi giây thật. Chỉ chạy nhiều
## tick hơn mỗi khung hình, không đổi SIM, nên phát lại vẫn khớp.
var speed: int = 1

var _accumulator: float = 0.0
## D-273: trận thật — tick đến hạn cuối cùng của khung chỉ chạy nửa đầu, nửa sau ở khung kế (khung không gánh cả
## tick: tick SIM ~7 ms trên máy tính bảng làm khung có tick vượt 16,7 ms → lỡ nhịp thành 33 ms). Chỉ ở tốc độ ×1;
## trễ nhiều tick thì chạy bù tick đầy đủ. Test / công cụ để tắt.
var split_ticks: bool = false


## D-108: ms SIM mỗi tick (trung bình trượt).
var step_ms: float = 0.0
## M9.6 (D-344): trận online — tick chạy theo gói lệnh máy chủ (LockstepClient), không theo đồng hồ máy này; không tăng tốc.
var lockstep: LockstepClient
var _clock: float = 0.0


func _init(p_world: World, p_split: bool = false) -> void:
	world = p_world
	split_ticks = p_split


## Chạy số tick tương ứng `delta` giây; trả về số tick đã chạy.
func advance(delta: float) -> int:
	if lockstep != null:
		return _advance_online(delta)
	if paused:
		return 0
	_accumulator += maxf(0.0, delta) * speed
	var steps: int = 0
	var cap: int = MAX_STEPS_PER_FRAME * speed
	var start: int = Time.get_ticks_msec()
	var t0: int = Time.get_ticks_usec()
	if world.mid_tick:  # D-273: nửa sau của tick mở ở khung trước
		var h: int = Time.get_ticks_usec()
		world.step_second_half()
		FrameProfile.shared.add(&"sim_second", h)  # D-277: đo riêng từng nửa
		stepped.emit()
		steps += 1
	while _accumulator + 0.000001 >= SimClock.TICK_SECONDS and steps < cap and world.winner < 0:
		_accumulator -= SimClock.TICK_SECONDS
		before_step.emit()
		if split_ticks and speed == 1 and _accumulator + 0.000001 < SimClock.TICK_SECONDS:
			var h1: int = Time.get_ticks_usec()
			world.step_first_half()  # D-273: tick cuối của khung — nửa sau để khung kế
			FrameProfile.shared.add(&"sim_first", h1)
			break
		world.step()
		stepped.emit()
		steps += 1
		if speed > 1 and Time.get_ticks_msec() - start > FAST_FRAME_BUDGET_MS:
			_accumulator = 0.0
			break
	if steps > 0:  # D-108: thời gian SIM trung bình mỗi tick (hiện ở HUD để đo trên điện thoại)
		step_ms = lerpf(step_ms, (Time.get_ticks_usec() - t0) / 1000.0 / steps, 0.1)
	FrameProfile.shared.add(&"sim", t0)  # D-261 (cả khung chỉ chạy nửa tick)
	if steps == cap or world.winner >= 0:
		_accumulator = minf(_accumulator, SimClock.TICK_SECONDS * 0.999)
	return steps


## Phần đã trôi của tick kế tiếp (0..1), để VIEW nội suy vị trí.
func alpha() -> float:
	if lockstep != null:
		return lockstep.phase()
	return clampf(_accumulator / SimClock.TICK_SECONDS, 0.0, 0.999)


## M9.6: chỉ nhận tin (màn trận đang nạp) — gói lệnh xếp hàng, nạp xong chạy bù.
func receive(delta: float) -> void:
	_clock += maxf(0.0, delta)
	lockstep.pump(_clock)


## M9.6: nhận tin rồi chạy các tick đã có gói (NET-01).
func _advance_online(delta: float) -> int:
	receive(delta)
	if paused:
		return 0
	if lockstep.on_before.is_null():
		lockstep.on_before = before_step.emit
		lockstep.on_after = stepped.emit
	var t0: int = Time.get_ticks_usec()
	var steps: int = lockstep.advance(delta)
	if steps > 0:
		step_ms = lerpf(step_ms, (Time.get_ticks_usec() - t0) / 1000.0 / steps, 0.1)
	FrameProfile.shared.add(&"sim", t0)
	return steps
