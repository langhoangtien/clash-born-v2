class_name StateSystem
extends SimSystem
## Pha 3 (ARCHITECTURE mục 4): tính lại StatBlock của đơn vị có thay đổi. Phần StateSet
## (ST) thêm vào đây khi hiệu ứng được làm (M3).


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.stats != null and e.stats.dirty:
			e.stats.recompute()
