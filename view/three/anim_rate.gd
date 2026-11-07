class_name AnimRate
extends RefCounted
## D-277: lính / quái / trụ cập nhật xương hoạt ảnh 30 lần mỗi giây thay vì mỗi khung — đơn vị số chẵn ở khung
## chẵn, số lẻ ở khung lẻ (mỗi khung chỉ một nửa số đơn vị tính xương). Hero vẫn mỗi khung (người chơi nhìn kỹ).
## Đo trên máy tính bảng: phần "xương, biến đổi" ~2,6 ms / khung. Chỉ là hình.

var anim: AnimationPlayer
var _slot: int = 0
var _due: float = 0.0


## Chuyển `player` sang cập nhật tay; `id` chọn khung chẵn / lẻ.
static func attach(player: AnimationPlayer, id: int) -> AnimRate:
	var r: AnimRate = AnimRate.new()
	r.anim = player
	r._slot = id % 2
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return r


## Gọi mỗi khung; tới lượt thì chạy hoạt ảnh bù cả thời gian đã dồn. Trả true nếu đã cập nhật.
func tick(delta: float, frame: int) -> bool:
	_due += delta
	if frame % 2 != _slot:
		return false
	anim.advance(_due)
	_due = 0.0
	return true


## Trả về tự chạy mỗi khung (xác: không còn ai gọi tick).
func release() -> void:
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
