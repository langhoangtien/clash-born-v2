class_name Corpses
extends RefCounted
## D-210: lính / quái chết bị DeathSystem gỡ khỏi World ngay trong tick đó; VIEW giữ hình lại phát hoạt ảnh
## chết, nằm LIE giây, lún xuống đất trong SINK giây rồi gỡ. Chỉ là hình — không ảnh hưởng trận.

const LIE: float = 1.0  ## giây nằm yên sau hoạt ảnh chết
const SINK: float = 0.6  ## giây lún xuống
const DEPTH: float = 0.6  ## đơn vị 3D lún xuống (đủ chìm hẳn đơn vị cao ~1)

var _items: Array[Array] = []  # [Actor3D, lúc bắt đầu lún]


## Bắt đầu chết lúc `now` (giây). Trả false nếu hình không có hoạt ảnh chết (ảnh đứng) — gỡ ngay như cũ.
func add(a: Actor3D, now: float) -> bool:
	if a._anim == null or not a._anim.has_animation(a._rig.get("death", "")):
		return false
	a._play(a._rig["death"], 1.0, true)
	a._anim.speed_scale = 1.0  # có thể đang khựng khung (D-159) đúng lúc chết
	_items.append([a, now + a._anim.get_animation(a._rig["death"]).length + LIE])
	return true


func update(now: float, delta: float) -> void:
	for i: int in range(_items.size() - 1, -1, -1):
		var a: Actor3D = _items[i][0]
		var sink_at: float = _items[i][1]
		if now < sink_at:
			continue
		a.position.y -= DEPTH * delta / SINK
		if now >= sink_at + SINK:
			a.queue_free()
			_items.remove_at(i)


func count() -> int:
	return _items.size()
