extends SimSystem
## Hệ thống chỉ dùng trong test: lần chạy đầu thêm một Recorder ở pha CONTROLLER (D-390: thêm hệ thống giữa tick).

const Recorder = preload("res://tests/sim/world/recorder_system.gd")

var log: Array[int]
var done: bool = false


func _init(l: Array[int]) -> void:
	log = l


func run(world: World) -> void:
	if not done:
		done = true
		world.add_system(Recorder.new(World.Phase.CONTROLLER, log), World.Phase.CONTROLLER)
