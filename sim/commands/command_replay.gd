class_name CommandReplay
extends RefCounted
## Phát lại nhật ký lệnh (CMD-04, D-30): gọi feed() trước mỗi world.step().

var _log: Array[Command] = []
var _next: int = 0


func _init(log: Array[Command]) -> void:
	_log = log


func feed(world: World) -> void:
	var upcoming: int = world.tick + 1
	while _next < _log.size() and _log[_next].tick == upcoming:
		world.submit(_log[_next].copy())
		_next += 1
