extends SimSystem
## Hệ thống chỉ dùng trong test: ghi lại pha của mình khi được chạy.

var phase: int
var log: Array[int]


func _init(p: int, l: Array[int]) -> void:
	phase = p
	log = l


func run(_world: World) -> void:
	log.append(phase)
